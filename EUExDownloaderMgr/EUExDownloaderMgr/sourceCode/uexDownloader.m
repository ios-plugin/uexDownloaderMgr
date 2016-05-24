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
#import "EUExDownloaderMgr.h"
#import "ACEUtils.h"

#import "EUtility.h"

#import "WidgetOneDelegate.h"
#import "JSON.h"



#define Lock() dispatch_semaphore_wait(self.lock, DISPATCH_TIME_FOREVER)
#define Unlock() dispatch_semaphore_signal(self.lock)


@interface uexDownloader()
@property (nonatomic,strong)dispatch_semaphore_t lock;
@property (nonatomic,assign)int64_t bytesWritten;
@property (nonatomic,assign)int64_t fileSize;
@property (nonatomic,assign)NSInteger percent;
@property (nonatomic,strong)NSDate *lastOperationTime;
@property (nonatomic,strong)NSData *resumeCache;
@property (nonatomic,strong)__kindof AFURLSessionManager *sessionManager;
@property (nonatomic,strong)NSURLSessionDownloadTask *task;

/*
- (id<uexDownloaderDelegate>)delegate;
- (void)onStatusCallback;
- (void)save;
- (void)prepareToDownload NS_REQUIRES_SUPER;
 */
@end

@implementation uexDownloader

#pragma mark - public
- (instancetype)initWithIdentifier:(NSString *)identifier euexObj:(EUExDownloaderMgr *)euexObj
{
    self = [super init];
    if (self) {
        _identifier = identifier;
        _euexObj = euexObj;
    }
    return self;
}

- (dispatch_semaphore_t)lock{
    if (!_lock) {
        _lock = dispatch_semaphore_create(1);
    }
    return _lock;
}



- (instancetype)initFromCacheWithServerPath:(NSString *)serverPath{
     return [NSKeyedUnarchiver unarchiveObjectWithFile:[self.class infoCacheSavePathWithDownloadPath:serverPath]];
}

- (void)cancelDownloadWithOption:(uexDownloaderCancelOption)option{
    
    if (self.status == uexDownloaderStatusCompleted || self.status == uexDownloaderStatusFailed) {
        return;
    }
    if (!self.task) {
        return;
    }
    if (option & uexDownloaderCancelOptionClearCache) {
        [self.task cancel];
    }else{
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            Lock();
            @weakify(self);
            [self.task cancelByProducingResumeData:^(NSData * _Nullable resumeData) {
                @strongify(self);
                if (self.resumable) {
                    self.resumeCache = resumeData;
                }
                Unlock();
            }];
        });
    }
    

}

- (NSDictionary *)info{
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setValue:self.savePath forKey:@"savePath"];
    [dict setValue:@(self.bytesWritten) forKey:@"currentSize"];
    [dict setValue:@(self.fileSize) forKey:@"fileSize"];
    [dict setValue:self.serverPath forKey:@"serverURL"];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    [dict setValue:[dateFormatter stringFromDate:self.lastOperationTime] forKey:@"lastTime"];
    [dict setValue:@(self.resumable) forKey:@"resumable"];
    [dict setValue:self.headers forKey:@"header"];
    [dict setValue:@(self.status) forKey:@"status"];
    return [dict copy];

}

- (void)startDownload{
    [self prepareToDownload];
    void (^handleProgressBlock)(NSProgress * _Nonnull downloadProgress) = ^(NSProgress * _Nonnull downloadProgress){
        self.fileSize = downloadProgress.totalUnitCount;
        self.bytesWritten = downloadProgress.completedUnitCount;
        self.status = uexDownloaderStatusDownloading;
        
        NSInteger percent = (NSInteger)(downloadProgress.fractionCompleted * 100);
        if (percent == 0 || percent == 100 || percent != self.percent) {
            self.percent = percent;
            [self onStatusCallback];
        }
    };
    NSURL * (^handleDestinationBlock)(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) = ^NSURL *(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response){
        return [NSURL uexDownloader_saveURLFromPath:self.savePath];
    };
    void (^handleCompletionBlock)(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) = nil;
    if (self.resumable && self.resumeCache) {
        [self updateCachedRequestHeader];
        self.task = [self.sessionManager downloadTaskWithResumeData:self.resumeCache
                                                           progress:handleProgressBlock
                                                        destination:handleDestinationBlock
                                                  completionHandler:handleCompletionBlock];
        
    }else{
        self.task = [self.sessionManager downloadTaskWithRequest:[self downloadRequest]
                                                        progress:handleProgressBlock
                                                     destination:handleDestinationBlock
                                               completionHandler:handleCompletionBlock];
        
    }
    [self.task resume];
}

- (void)clean{
    [self cancelDownloadWithOption:uexDownloaderCancelOptionDefault];
}



#pragma mark - Util

- (void)updateCachedRequestHeader{
    NSString *error;
    NSPropertyListFormat format;
    NSMutableDictionary* resumeDict = [NSMutableDictionary dictionaryWithDictionary:[NSPropertyListSerialization propertyListFromData:self.resumeCache mutabilityOption:NSPropertyListImmutable format:&format errorDescription:&error]];
    if (error || !resumeDict) {
        return;
    }
    NSURLRequest *request = [self downloadRequest];
    NSData *newRequestData = [NSKeyedArchiver archivedDataWithRootObject:[request copy]];
    [resumeDict setValue:newRequestData forKey:@"NSURLSessionResumeCurrentRequest"];
    self.resumeCache = [NSPropertyListSerialization dataFromPropertyList:resumeDict format:NSPropertyListBinaryFormat_v1_0 errorDescription:&error];
}

- (NSURLRequest *)downloadRequest{
    NSURL *URL = [NSURL URLWithString:self.serverPath];
    if (!URL) {
        URL = [NSURL URLWithString:[self.serverPath stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    }
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
    [self.headers enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSString * _Nonnull obj, BOOL * _Nonnull stop) {
        [request addValue:obj forHTTPHeaderField:key];
    }];
    return [request copy];
}



- (id<uexDownloaderDelegate>)delegate{
    if (!self.isGlobalDownloader) {
        return self.euexObj;
    }else{
        return nil;
    }
}


- (__kindof AFURLSessionManager *)sessionManager{
    if(!_sessionManager){
        AFURLSessionManager *manager = [[AFURLSessionManager alloc]initWithSessionConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
        @weakify(self);
        [manager setSessionDidBecomeInvalidBlock:^(NSURLSession * _Nonnull session, NSError * _Nonnull error) {
            @strongify(self);
            [self.delegate uexDownloader:self sessionDidInvalidatedWithError:error];
        }];
        [manager setResponseSerializer:[AFHTTPResponseSerializer serializer]];
        [manager setTaskDidCompleteBlock:^(NSURLSession * _Nonnull session, NSURLSessionTask * _Nonnull task, NSError * _Nullable error) {
            @strongify(self);
            Lock();
            if (error) {
                self.status = uexDownloaderStatusFailed;
                UEXLog(@"download fail!url:%@,error:%@",self.serverPath,[error localizedDescription]);
            }else{
                self.status = uexDownloaderStatusCompleted;
                UEXLog(@"download success!url:%@",self.serverPath);
            }
            [self save];
            [self.delegate uexDownloader:self taskDidCompletedWithError:error];
            [self onStatusCallback];
            [self.sessionManager invalidateSessionCancelingTasks:YES];
            Unlock();
        }];
        _sessionManager = manager;
    }
    return _sessionManager;
}


- (void)prepareToDownload{
    //resume cache
    uexDownloader *oldDownloader = [[uexDownloader alloc]initFromCacheWithServerPath:self.serverPath];
    if (oldDownloader) {
        self.resumeCache = oldDownloader.resumeCache;
    }
    
    //add appcan header;
    NSMutableDictionary *headers = [self.headers?:@{} mutableCopy];
    [headers addEntriesFromDictionary:[uexDownloadHelper AppCanHTTPHeadersWithEUExObj:self.euexObj]];
    self.headers = [headers copy];
    
    
    if(theApp.useCertificateControl && [self.serverPath hasPrefix:@"https://"]){
        //setupSSLPolicy
        [self.sessionManager setSessionDidReceiveAuthenticationChallengeBlock:^NSURLSessionAuthChallengeDisposition(NSURLSession * _Nonnull session, NSURLAuthenticationChallenge * _Nonnull challenge, NSURLCredential *__autoreleasing  _Nullable * _Nullable credential) {
            return [uexDownloadHelper authChallengeDispositionWithChallenge:challenge credential:credential];
        }];
        [self.sessionManager setTaskDidReceiveAuthenticationChallengeBlock:^NSURLSessionAuthChallengeDisposition(NSURLSession * _Nonnull session, NSURLSessionTask * _Nonnull task, NSURLAuthenticationChallenge * _Nonnull challenge, NSURLCredential *__autoreleasing  _Nullable * _Nullable credential) {
            return [uexDownloadHelper authChallengeDispositionWithChallenge:challenge credential:credential];
        }];
    }else{
        self.sessionManager.securityPolicy.allowInvalidCertificates = YES;
        self.sessionManager.securityPolicy.validatesDomainName = NO;
    }
    

}

static const NSTimeInterval kMinimumSaveInteval = 5;

- (void)onStatusCallback{
    NSDate *currentTime = [NSDate date];
    if (self.status == uexDownloaderStatusDownloading && [currentTime timeIntervalSinceDate:self.lastOperationTime] > kMinimumSaveInteval) {
        [self save];
    }
    EBrowserView *cbTarget = self.observer;
    if (!cbTarget) {
        cbTarget = self.euexObj.meBrwView;
    }
    if (ACE_Available()) {
        [EUtility browserView:cbTarget
  callbackWithFunctionKeyPath:@"uexDownloaderMgr.onStatus"
                    arguments:ACE_ArgsPack(self.identifier,@(self.fileSize),@(self.percent),@(self.status))
                   completion:nil];
    }else{
        NSString *jsStr = [NSString stringWithFormat:@"if(uexDownloaderMgr.onStatus){uexDownloaderMgr.onStatus(%@,%@,%@,%@);}",self.identifier.JSONFragment,@(self.fileSize),@(self.percent),@(self.status)];
        [EUtility brwView:cbTarget evaluateScript:jsStr];
    }
}

#pragma mark - Cache & Save

- (void)save{
    self.lastOperationTime = [NSDate date];
    NSString *path = [self cacheSavePath];
    NSFileManager *fm = [NSFileManager defaultManager];
    if([fm fileExistsAtPath:path]){
        [fm removeItemAtPath:path error:nil];
    }
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self];
    [data writeToFile:path atomically:YES];
}



#pragma mark - Info Cache Save Path


- (NSString *)cacheSavePath{
    return [self.class infoCacheSavePathWithDownloadPath:self.serverPath];
}

+ (NSString *)infoCacheSavePathWithDownloadPath:(NSString *)downloadPath{
    return [[self infoCacheSaveFolderPath] stringByAppendingPathComponent:downloadPath.uexDownloader_MD5];
}

+ (NSString *)infoCacheSaveFolderPath{
    static NSString *folderPath = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        //cache目录
        NSString *cachePath = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject;
        folderPath = [cachePath stringByAppendingPathComponent:@"uexDownloaderMgr"];
        BOOL isFolder = NO;
        NSFileManager *fm = [NSFileManager defaultManager];
        if(![fm fileExistsAtPath:folderPath isDirectory:&isFolder] || !isFolder){
            //如果不存在,就新建一个
            [fm createDirectoryAtPath:folderPath withIntermediateDirectories:YES attributes:nil error:nil];
        }
    });
    return folderPath;
}

#pragma mark - NSSecurityCoding

+ (BOOL)supportsSecureCoding{
    return YES;
}


#define UEXEncodeObjectProperty(property) [aCoder encodeObject:self.property forKey:@metamacro_stringify(property)]
#define UEXEncodeNumberProperty(property) [aCoder encodeObject:@(self.property) forKey:@metamacro_stringify(property)]


#define UEXDecodeObjectProperty(property,cls) self.property = [aDecoder decodeObjectOfClass:[cls class] forKey:@metamacro_stringify(property)]
#define UEXDecodeNumberProperty(property,sel) self.property = [[aDecoder decodeObjectOfClass:[NSNumber class] forKey:@metamacro_stringify(property)] sel]

- (void)encodeWithCoder:(NSCoder *)aCoder{
    UEXEncodeObjectProperty(serverPath);
    UEXEncodeObjectProperty(savePath);
    UEXEncodeObjectProperty(lastOperationTime);
    UEXEncodeObjectProperty(headers);
    UEXEncodeNumberProperty(bytesWritten);
    UEXEncodeNumberProperty(fileSize);
    UEXEncodeNumberProperty(resumable);
    UEXEncodeNumberProperty(status);
    UEXEncodeNumberProperty(isGlobalDownloader);
    if (self.status == uexDownloaderStatusFailed) {
        UEXEncodeObjectProperty(resumeCache);
    }
}
- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [self init];
    if (self) {
        UEXDecodeObjectProperty(serverPath, NSString);
        UEXDecodeObjectProperty(savePath, NSString);
        UEXDecodeObjectProperty(lastOperationTime, NSDate);
        UEXDecodeObjectProperty(headers, NSDictionary);
        UEXDecodeObjectProperty(resumeCache, NSData);
        UEXDecodeNumberProperty(bytesWritten,longLongValue);
        UEXDecodeNumberProperty(fileSize, longLongValue);
        UEXDecodeNumberProperty(resumable, boolValue);
        UEXDecodeNumberProperty(status, integerValue);
        UEXDecodeNumberProperty(isGlobalDownloader, boolValue);
    }
    return self;
}


@end


/*
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
 */
