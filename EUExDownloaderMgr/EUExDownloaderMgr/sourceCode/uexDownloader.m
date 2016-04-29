/**
 *
 *	@file   	: uexDownloader.m  in EUExDownloaderMgr
 *
 *	@author 	: CeriNo 
 * 
 *	@date   	: Created on 16/4/15.
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

#import "uexDownloader.h"
#import "uexDownloadInfo.h"
#import "EUExDownloaderMgr.h"
#import <AFNetworking/AFNetworking.h>
#import "EXTScope.h"
#import "EUtility.h"
#import "uexDownloadSessionManager.h"
#import <libkern/OSAtomic.h>

@interface uexDownloader()
@property (nonatomic,assign)CGFloat progress;
@property (nonatomic,strong)NSURLSessionDownloadTask *task;
@property (nonatomic,weak)uexDownloadSessionManager *manager;

@property (nonatomic,assign)BOOL taskCancelledByUser;


@end

@implementation uexDownloader

- (instancetype)initWithIdentifier:(NSInteger)identifier euexObj:(EUExDownloaderMgr *)euexObj
{
    self = [super init];
    if (self) {
        _identifier = @(identifier);
        _euexObj = euexObj;
        _manager = [uexDownloadSessionManager defaultManager];
        _progress = 0;
        _headers = [uexDownloadHelper AppCanHTTPHeadersWithEUExObj:self.euexObj];
    }
    return self;
}

- (void)setHeaders:(NSDictionary<NSString *,NSString *> *)headers{
    
    __block NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:[uexDownloadHelper AppCanHTTPHeadersWithEUExObj:self.euexObj]];
    [headers enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSString * _Nonnull obj, BOOL * _Nonnull stop) {
        [dict setValue:obj forKey:key];
    }];
    _headers = [dict copy];
    if (self.info) {
        self.info.headers = headers;
    }
}
- (void)setProgress:(CGFloat)progress{
    _progress = progress;

    if (_progress < 0) {
        _progress = 0;
    }
    if (_progress > 1) {
        _progress = 1;
    }
}


- (void)getPreparedWithDownloadInfo:(uexDownloadInfo *)info{
    self.info = info;
    self.info.headers = self.headers;
    if (info.resumable && info.resumeCache) {

        [info updataRequestInResumeCache];
        [self setupResumeTask];
    }else{
        [self setupNewTask];
    }

}

- (void)setupNewTask{
    self.task = [self.manager downloadTaskWithRequest:[self.info downloadRequest]
                                             progress:^(NSProgress * _Nonnull downloadProgress) {
                                                 [self updateInfo:downloadProgress];
                                             }
                                          destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
                                              return [self saveURL];
                                          }
                                    completionHandler:^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {

                                        [self handleDownloaderResult:error];
                                    }];
}

- (void)setupResumeTask{
    self.task = [self.manager downloadTaskWithResumeData:self.info.resumeCache
                                                progress:^(NSProgress * _Nonnull downloadProgress) {
                                                    [self updateInfo:downloadProgress];
                                                }
                                             destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
                                                    return [self saveURL];
                                                }
                                       completionHandler:^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
                                                    [self handleDownloaderResult:error];
                                                }];
}

- (void)handleDownloaderResult:(NSError *)error{
    if (error) {
        if (self.info.status == uexDownloadInfoStatusDownloading) {
            self.info.status = uexDownloadInfoStatusFailed;
        }
        [self.info cacheForResuming];
        [self onStatusCallback];
        UEXLog(@"download fail!url:%@,error:%@",self.info.downloadPath,[error localizedDescription]);
    }else{
        self.info.status = uexDownloadInfoStatusCompleted;
        [self.info cacheForResuming];
        [self onStatusCallback];
        UEXLog(@"download success!url:%@",self.info.downloadPath);
    }
}



- (void)startDownload{
    [self.task resume];
}

- (void)clean{
    [self cancelDownloadWithOption:uexDownloaderCancelOptionDefault];
}

- (void)cancelDownloadWithOption:(uexDownloaderCancelOption)option{

    self.info.status = uexDownloadInfoStatusSuspended;
    if(!(option & uexDownloaderCancelOptionClearCache) && self.info.resumable){
        @weakify(self);
        [self.task cancelByProducingResumeData:^(NSData * _Nullable resumeData) {
            @strongify(self);
            self.info.resumeCache = resumeData;
            [self.info cacheForResuming];
        }];
        return;
    }
    [self.task cancel];
}

- (void)updateInfo:(NSProgress *)downloadProgress{
    
    self.info.fileSize = downloadProgress.totalUnitCount;
    self.info.bytesWritten = downloadProgress.completedUnitCount;
    self.info.status = uexDownloadInfoStatusDownloading;
    static NSTimeInterval kInfoMinimumAutoSaveInterval = 5.0;
    NSDate *currentDate = [NSDate date];
    BOOL shouldSave = [currentDate timeIntervalSinceDate:self.info.lastOperationTime] > kInfoMinimumAutoSaveInterval ;
    
    self.progress = downloadProgress.fractionCompleted;
    [self onStatusCallback];
    if(shouldSave){
        [self.info cacheForResuming];
    }
}
- (NSURL *)saveURL{
    return  [NSURL uexDownloader_saveURLFromPath:[self.euexObj absPath:self.info.savePath]];

}

static const NSTimeInterval kMinimumCallbackInteval = 0.05;

- (void)onStatusCallback{
    static NSDate *lastCallbackTime = nil;
    
    
    BOOL shouldCallback = YES;

        NSDate *currentTime = [NSDate date];
        if (self.info.status == uexDownloadInfoStatusDownloading && [currentTime timeIntervalSinceDate:lastCallbackTime] < kMinimumCallbackInteval && self.progress != 0 && self.progress != 1) {
            //避免回调过于频繁占用资源
           shouldCallback = NO;
        }else{
            lastCallbackTime = currentTime;
        }
    if (shouldCallback) {
        static NSInteger count = 0;
        count++;
        [self.euexObj callbackWithFunction:@"onStatus" arguments:UEX_ARGS_PACK(self.identifier,@(self.info.fileSize),@(self.progress * 100),@(self.info.status))];
    }

}

@end
