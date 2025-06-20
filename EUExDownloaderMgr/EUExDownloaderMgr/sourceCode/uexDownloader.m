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
#import <AppCanKit/ACEXTScope.h>
#import "WidgetOneDelegate.h"



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
        self.resumeCache = nil;
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
        NSURL *savePathURL = [NSURL uexDownloader_saveURLFromPath:self.savePath];
        // 如果文件已经存在，先删除
        [[NSFileManager defaultManager] removeItemAtURL:savePathURL error:nil];
        return savePathURL;
    };
    void (^handleCompletionBlock)(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) = nil;
    if (self.resumable && self.resumeCache) {
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

- (void)cancelDownload {//clean修改为cancelDownload，避免定位问题时被误导
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
    NSString *tmpFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:resumeDict[@"NSURLSessionResumeInfoTempFileName"]];
    if (![[NSFileManager defaultManager] fileExistsAtPath:tmpFilePath]) {
        self.resumeCache = nil;
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
        __weak typeof (self) weakSelf = self;
        [manager setSessionDidBecomeInvalidBlock:^(NSURLSession * _Nonnull session, NSError * _Nonnull error) {
            // @strongify(self);
            // 在主线程将downloader解除引用。
            // 因为downloader中包含一个JSFunc的对象引用，当自身被解除引用触发内存回收的时候，就会在当前线程触发dealloc，也可能会在当前线程中触发持有的JSFunc对象的dealloc。而我们的ACJSFunctionRef的dealloc中存在访问JS对象的操作，该操作不允许在非主线程中进行，故而必须做保护。（暂时也没找到更好的办法，隐约觉得可能是引擎的ACJSFunctionRef的dealloc可以改一下，但是又怕引发其他问题）。
            // 而，之所以注释掉@strongify(self)，是因为声明了strong之后，此变量会一直持有直到block执行结束，而我们必须要在主线程中将downloader对象（即self）的引用清零，所以这里不要用strong
            // note at 20190823 by yipeng
            if([NSThread isMainThread]){
                [weakSelf.delegate uexDownloader:weakSelf sessionDidInvalidatedWithError:error];
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [weakSelf.delegate uexDownloader:weakSelf sessionDidInvalidatedWithError:error];
                });
            }
        }];
        [manager setResponseSerializer:[AFHTTPResponseSerializer serializer]];
        [manager setTaskDidCompleteBlock:^(NSURLSession * _Nonnull session, NSURLSessionTask * _Nonnull task, NSError * _Nullable error) {
            @strongify(self);
            Lock();
            if (error) {
                self.status = uexDownloaderStatusFailed;
                ACLogDebug(@"download fail!url:%@,error:%@",self.serverPath,[error localizedDescription]);
            }else{
                self.status = uexDownloaderStatusCompleted;
                ACLogDebug(@"download success!url:%@",self.serverPath);
            }
            [self save];
            [self.delegate uexDownloader:self taskDidCompletedWithError:error];
            [self onStatusCallback];
            [self.sessionManager invalidateSessionCancelingTasks:YES resetSession:NO];
            Unlock();
        }];
        _sessionManager = manager;
    }
    return _sessionManager;
}


- (void)prepareToDownload{
    //resume cache
    uexDownloader *oldDownloader = [[uexDownloader alloc]initFromCacheWithServerPath:self.serverPath];
    if (oldDownloader && self.resumable) {
        self.resumeCache = oldDownloader.resumeCache;
        [self updateCachedRequestHeader];
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
    [self.euexObj callbackWithFunctionKeyPathByMainThread:@"uexDownloaderMgr.onStatus" arguments:ACArgsPack(self.identifier,@(self.fileSize),@(self.percent),@(self.status))];
    [self.euexObj jsCallbackExecuteByMainThread:self.cbFunc withArguments:ACArgsPack(@(self.fileSize),@(self.percent),@(self.status))];
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
    if (self.status == uexDownloaderStatusFailed && self.resumable) {
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

- (void)dealloc{
    ACLogVerbose(@"uexDownloader %@ dealloc", self);
}

@end


