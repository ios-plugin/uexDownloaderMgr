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
#import "EUtility.h"
#import "uexDownloadSessionManager.h"
typedef NS_ENUM(NSInteger,uexDownloaderStatus) {
    uexDownloaderStatusInitialized = -1,
    uexDownloaderStatusDownloading = 0,
    uexDownloaderStatusSuccess,
    uexDownloaderStatusFailed,
    uexDownloaderStatusCancelled
};


@interface uexDownloader()
@property (nonatomic,assign)CGFloat progress;
@property (nonatomic,assign)uexDownloaderStatus status;
@property (nonatomic,strong)uexDownloadInfo *info;
@property (nonatomic,strong)NSURLSessionDownloadTask *task;
@property (nonatomic,weak)uexDownloadSessionManager *manager;
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
        _status = uexDownloaderStatusInitialized;
    }
    return self;
}

- (void)setHeaders:(NSDictionary<NSString *,NSString *> *)headers{
    _headers = headers;
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
    BOOL shouldUpdateRequest = NO;
    if(self.headers){
        self.info.headers = self.headers;
        shouldUpdateRequest = YES;
    }
    if (info.resumable && info.resumeCache) {
        if(shouldUpdateRequest){
            [info updataRequestInResumeCache];
        }
        [self setupResumeTask];
    }
    [self.manager setDownloadTaskDidResumeBlock:^(NSURLSession * _Nonnull session, NSURLSessionDownloadTask * _Nonnull downloadTask, int64_t fileOffset, int64_t expectedTotalBytes) {
        <#code#>
    }];
}

- (void)setupResumeTask{
    self.task = [self.manager downloadTaskWithResumeData:self.info.resumeCache
                                                progress:^(NSProgress * _Nonnull downloadProgress) {
                                                    [self updateInfo:downloadProgress];
                                                    
                                                } destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
                                                    return [self saveURL];
                                                } completionHandler:^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
                                                    if (error && error.userInfo[]) {
                                                        
                                                    }
                                                }];
}

- (void)updateInfo:(NSProgress *)downloadProgress{
    
    self.info.totalBytesWritten = downloadProgress.totalUnitCount;
    self.info.bytesWritten = downloadProgress.completedUnitCount;
    static NSTimeInterval kInfoMinimumAutoSaveInterval = 5.0;
    NSDate *currentDate = [NSDate date];
    BOOL shouldSave = [currentDate timeIntervalSinceDate:self.info.lastOperationTime] > kInfoMinimumAutoSaveInterval ;
    self.info.lastOperationTime = currentDate;
    self.status = uexDownloaderStatusDownloading;
    self.progress = downloadProgress.fractionCompleted;
    [self onStatusCallback];
    if(shouldSave){
        [self.info cacheForResuming];
    }
}
- (NSURL *)saveURL{
    NSString *savePath = [self.euexObj absPath:self.info.savePath];
    NSURL *URL = [NSURL URLWithString:savePath];
    if (!URL) {
        URL = [NSURL fileURLWithPath:savePath];
    }
    return URL;
}


- (void)onStatusCallback{
    NSString *jsStr = [NSString stringWithFormat:@"if(uexDownloaderMgr.onStatus){uexDownloaderMgr.onStatus(%@,%@,%@,%@)}",self.identifier,@(self.info.totalBytesWritten),@(self.progress),@(self.status)];
    [EUtility brwView:self.euexObj.meBrwView evaluateScript:jsStr];
}

@end
