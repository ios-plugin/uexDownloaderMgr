/**
 *
 *	@file   	: uexDownloadBackgroundTask.m  in EUExDownloaderMgr
 *
 *	@author 	: CeriNo 
 * 
 *	@date   	: Created on 16/4/18.
 *
 *	@copyright 	: 2016 The AppCan Open Source Project.
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU Lesser General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU Lesser General Public License for more details.
 *  You should have received a copy of the GNU Lesser General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

#import "uexDownloadBackgroundTask.h"
#import "uexDownloadBackgroundTaskManager.h"
#import "uexDownloadBackgroundTaskInfo.h"
#import "uexDownloadSessionManager.h"
#import "EXTScope.h"
#import "EUtility.h"
#import "JSON.h"
@interface uexDownloadBackgroundTask()<NSURLSessionDownloadDelegate>
@property (nonatomic,strong,readwrite)uexDownloadBackgroundTaskInfo *info;
@property (nonatomic,strong)NSURLSession *session;
@property (nonatomic,strong)NSURLSessionDownloadTask *sessionTask;
@property (nonatomic,assign)CGFloat progress;

@property (nonatomic,strong)dispatch_queue_t saveQueue;

@end
@implementation uexDownloadBackgroundTask

NSString * kEUExDownloaderBackgroundTaskPrefix = nil;
static dispatch_queue_t uexDownloadBackgroundTaskSaveQueue;
+ (void)load{
    if (!kEUExDownloaderBackgroundTaskPrefix) {
        NSString * bundleID = [[[NSBundle mainBundle]infoDictionary]objectForKey:@"CFBundleIdentifier"];
        kEUExDownloaderBackgroundTaskPrefix = [NSString stringWithFormat:@"%@_%@_",bundleID,@"uexDownloaderMgrBackgroundTask"];
    }
}


+ (instancetype)taskWithIdentifier:(NSString *)identifier resumeFromCache:(BOOL)isResumeFromCache{
    if (!uexDownloadBackgroundTaskSaveQueue) {
        uexDownloadBackgroundTaskSaveQueue = dispatch_queue_create("com.appcan.uexDownloadBackgroundTaskSaveQueue", DISPATCH_QUEUE_CONCURRENT);
    }
    uexDownloadBackgroundTask *task = [[self alloc]init];
    if (task) {
        task.identifier = identifier;
        NSURLSessionConfiguration *config;
        if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8.0) {
            config = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:identifier];
        }else{
            config = [NSURLSessionConfiguration backgroundSessionConfiguration:identifier];
        }
        if (!config) {
            return nil;
        }
        if (isResumeFromCache) {
            uexDownloadBackgroundTaskInfo *info = [uexDownloadBackgroundTaskInfo cachedInfoWithIdentifier:identifier];
            if (info.status == uexDownloadInfoStatusSuspended) {
                task.info = info;
            }
        }
        if (!task.info) {
            task.info = [[uexDownloadBackgroundTaskInfo alloc]initWithIdentifier:identifier];
        }
        task.session = [NSURLSession sessionWithConfiguration:config delegate:task delegateQueue:nil];


    }
    return task;
}

+ (instancetype)taskWithShortIdentifier:(NSString *)shortIdentifier resumeFromCache:(BOOL)isResumeFromCache{
    NSString *identifier = [kEUExDownloaderBackgroundTaskPrefix stringByAppendingString:shortIdentifier];
    return [self taskWithIdentifier:identifier resumeFromCache:isResumeFromCache];
}

- (BOOL)canDownload{
    if (!self.info) {
        return NO;
    }
    if (!self.info.downloadPath || !self.info.savePath) {
        return NO;
    }
    if (self.info.status != uexDownloadInfoStatusSuspended) {
        return NO;
    }
    return YES;
}

- (NSURLSessionDownloadTask *)sessionTask{
    if (!_sessionTask) {
        if(![self canDownload]) {
            return nil;
        }
        if (self.info.resumable && self.info.resumeCache) {
            [self.info updataRequestInResumeCache];
            _sessionTask = [self.session downloadTaskWithResumeData:self.info.resumeCache];
        }else{
            _sessionTask = [self.session downloadTaskWithRequest:[self.info downloadRequest]];
        }
    }
    return _sessionTask;
}




static const NSTimeInterval kMinimunCallbackInteval = 0.05;
static NSDate *lastCallbackTime = nil;
- (void)onStatusCallback{
    if (!self.webViewObserver) {
        return;
    }
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setValue:self.info.shortIdentifier  forKey:@"identifier"];
    CGFloat percent = self.info.fileSize ? (double)self.info.bytesWritten/(double)self.info.fileSize * 100 : 0;
    [dict setValue:@(percent) forKey:@"percent"];
    [dict setValue:@(self.info.status) forKey:@"status"];
    [dict setValue:@(self.info.fileSize) forKey:@"fileSize"];
    [dict setValue:self.info.downloadPath forKey:@"serverURL"];
    
    BOOL shouldCallback = YES;
    
    if(self.info.status == uexDownloadInfoStatusDownloading && percent != 0 && percent != 100){
        NSDate *currentTime = [NSDate date];
        if ([currentTime timeIntervalSinceDate:lastCallbackTime] < kMinimunCallbackInteval) {
            shouldCallback = NO;
        }else{
            lastCallbackTime = currentTime;
        }
    }
    if (shouldCallback) {
        if ([EUtility respondsToSelector:@selector(browserView:callbackWithFunctionKeyPath:arguments:completion:)]) {
            [EUtility browserView:self.webViewObserver callbackWithFunctionKeyPath:@"uexDownloaderMgr.onBackgroundTaskStatusChange" arguments:@[[dict JSONFragment]] completion:nil];
        }else{
            [EUtility uexPlugin:@"uexDownloaderMgr" callbackByName:@"onBackgroundTaskStatusChange" withObject:[dict JSONFragment] andType:uexPluginCallbackWithJsonString inTarget:self.webViewObserver];
        }
    }
    
    
}

- (void)startDownload{
    [self.sessionTask resume];
}

- (void)clean{
    [self cancelDownloadWithOption:uexDownloaderCancelOptionDefault];
    [self.session finishTasksAndInvalidate];
}

- (void)cancelDownloadWithOption:(uexDownloaderCancelOption)option{
    if (self.info.status == uexDownloadInfoStatusDownloading) {
        if(!(option & uexDownloaderCancelOptionClearCache) && self.info.resumable){
            @weakify(self);
            [self.sessionTask cancelByProducingResumeData:^(NSData * _Nullable resumeData) {
                @strongify(self);
                self.info.resumeCache = resumeData;
                [self.info cacheForResuming];
            }];
            return;
        }
        [self.sessionTask cancel];
    }else{
        [self.session invalidateAndCancel];
        
    }
    
    self.info.status = uexDownloadInfoStatusSuspended;
}





#pragma mark - NSURLSessionDelegate

- (void)URLSession:(NSURLSession *)session didBecomeInvalidWithError:(nullable NSError *)error{
    UEXLog(@"session invalid,id:%@",self.info.shortIdentifier);
    [UEX_BG_TASK_MGR notifyDownloadTaskFinish:self];
}


- (void)URLSession:(NSURLSession *)session
didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
 completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential * __nullable credential))completionHandler{
    NSURLCredential *credential = nil;
    NSURLSessionAuthChallengeDisposition disposition = [uexDownloadHelper authChallengeDispositionWithSession:session challenge:challenge credential:&credential];
    if (completionHandler) {
        completionHandler(disposition,credential);
    }
}


- (void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session{
    UEXLog(@"wait for saving info");
    dispatch_barrier_async(uexDownloadBackgroundTaskSaveQueue, ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            UEXLog(@"notify background session finish:%@",self.info.shortIdentifier)
            [UEX_BG_TASK_MGR notifyBackgroundSessionTaskFinish:self];
        });
    });
    
}


#pragma mark - NSURLSessionTaskDelegate


- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
 completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential * __nullable credential))completionHandler{
    UEXLog(@"receive challenge,id:%@",self.info.shortIdentifier);
    NSURLCredential *credential = nil;
    NSURLSessionAuthChallengeDisposition disposition = [uexDownloadHelper authChallengeDispositionWithSession:session challenge:challenge credential:&credential];
    if (completionHandler) {
        completionHandler(disposition,credential);
    }
}



/* Sent as the last message related to a specific task.  Error may be
 * nil, which implies that no error occurred and this task is complete.
 */
- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didCompleteWithError:(nullable NSError *)error{
    if (error) {
        if (self.info.status == uexDownloadInfoStatusDownloading) {
            self.info.status = uexDownloadInfoStatusFailed;
        }
        
        [self onStatusCallback];
        UEXLog(@"download fail!id:%@ error:%@",self.info.shortIdentifier,[error localizedDescription]);
        [self.session invalidateAndCancel];
    }else{
        if (self.info.status != uexDownloadInfoStatusFailed) {
            self.info.status = uexDownloadInfoStatusCompleted;
        }
        
        [self onStatusCallback];
        UEXLog(@"download success! id:%@",self.info.shortIdentifier);
        [self.session finishTasksAndInvalidate];
    }
    self.info.bytesWritten = task.countOfBytesReceived;
    self.info.fileSize = task.countOfBytesExpectedToReceive;
    [self.info cacheForResumingInQueue:uexDownloadBackgroundTaskSaveQueue completion:^{
        UEXLog(@"info saved");
    }];
}


#pragma mark - NSURLSessionDownloadDelegate


- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
didFinishDownloadingToURL:(NSURL *)location{
    NSError *error = nil;
    NSURL *saveURL = [NSURL uexDownloader_saveURLFromPath:self.info.savePath];
    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:self.info.savePath]) {
        [fm removeItemAtURL:saveURL error:&error];
        if (error) {
            self.info.status = uexDownloadInfoStatusFailed;
            UEXLog(@"id:%@,fs error:%@",self.info.shortIdentifier,[error localizedDescription]);
            return;
        }
    }

    [[NSFileManager defaultManager] moveItemAtURL:location toURL:saveURL error:&error];
    if (error) {
        self.info.status = uexDownloadInfoStatusFailed;
        UEXLog(@"id:%@,fs error:%@",self.info.shortIdentifier,[error localizedDescription]);
        return;
    }
}

/* Sent periodically to notify the delegate of download progress. */
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
      didWriteData:(int64_t)bytesWritten
 totalBytesWritten:(int64_t)totalBytesWritten
totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite{
    UEXLog(@"id-->%@,receive data-->%@",self.info.shortIdentifier,@(bytesWritten));
    self.info.bytesWritten = totalBytesWritten;
    self.info.fileSize = totalBytesExpectedToWrite;
    self.info.status = uexDownloadInfoStatusDownloading;
    static NSTimeInterval kInfoMinimumAutoSaveInterval = 5.0;
    NSDate *currentDate = [NSDate date];
    BOOL shouldSave = [currentDate timeIntervalSinceDate:self.info.lastOperationTime] > kInfoMinimumAutoSaveInterval ;
    
    self.progress = (double)bytesWritten / (double)totalBytesWritten;
    [self onStatusCallback];
    if(shouldSave){
        UEXLog(@"save info:id-->%@,total received-->%@,expected-->%@",self.info.shortIdentifier,@(totalBytesWritten),@(totalBytesExpectedToWrite));
        [self.info cacheForResuming];
    }
}
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
 didResumeAtOffset:(int64_t)fileOffset
expectedTotalBytes:(int64_t)expectedTotalBytes{
    UEXLog(@"id: resume download with data offset:%@",self.info.shortIdentifier,@(fileOffset));
}

- (void)dealloc{
    UEXLog(@"background task dealloc,id:%@",self.info.shortIdentifier);
}

@end
