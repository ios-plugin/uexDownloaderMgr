/**
 *
 *	@file   	: EUExDownloaderMgr.m  in EUExDownloaderMgr
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

#import "EUExDownloaderMgr.h"
#import <AppCanKit/ACEXTScope.h>






@interface EUExDownloaderMgr()
@property (nonatomic,strong)NSMutableDictionary<NSString *,uexDownloader *> *downloaders;
@end
@implementation EUExDownloaderMgr

#pragma mark - Life Cycle
- (instancetype)initWithWebViewEngine:(id<AppCanWebViewEngineObject>)engine{
    self=[super initWithWebViewEngine:engine];
    if(self){
        _downloaders = [NSMutableDictionary dictionary];
    }
    return self;
}
- (void)clean {
    for(uexDownloader *aDownloader in self.downloaders.allValues) {
        if ([aDownloader respondsToSelector:@selector(cancelDownload)]) {
            [aDownloader cancelDownload];
        }
    }
    [self.downloaders removeAllObjects];
}
- (void)dealloc{
    [self clean];
}
#pragma mark - API

- (NSString *)create:(NSMutableArray *)inArguments{
    ACArgsUnpack(NSDictionary *info) = inArguments;
    NSString *identifier = stringArg(info[@"id"]) ?: [NSUUID UUID].UUIDString;
    if (!identifier || identifier.length == 0 || [self.downloaders.allKeys containsObject:identifier]) {
        return nil;
    }
    uexDownloader *downloader = [[uexDownloader alloc]initWithIdentifier:identifier euexObj:self];
    if (!downloader) {
        return nil;
    }
    [self.downloaders setObject:downloader forKey:identifier];
    return identifier;
}


- (NSNumber *)createDownloader:(NSMutableArray *)inArguments{
    __block BOOL isSuccess = NO;
    ACArgsUnpack(NSString *identifier) = inArguments;

    @onExit{
        NSNumber *ret = isSuccess ? @0 : @1;
        [self callbackWithFunctionKeyPathByMainThread:@"uexDownloaderMgr.cbCreateDownloader" arguments:ACArgsPack(identifier,@2,ret)];

    };
    if (!identifier || identifier.length == 0 || [self.downloaders.allKeys containsObject:identifier]) {
        return UEX_FALSE;
    }
    uexDownloader *downloader = [[uexDownloader alloc]initWithIdentifier:identifier euexObj:self];
    if (!downloader) {
        return UEX_FALSE;
    }
    [self.downloaders setObject:downloader forKey:identifier];
    isSuccess = YES;
    return UEX_TRUE;
    
}

- (void)download:(NSMutableArray *)inArguments{

    ACArgsUnpack(NSString *identifier,NSString *serverURL,NSString *savePath,NSNumber *resumableNum,ACJSFunctionRef *cb) = inArguments;
    BOOL resumable = [resumableNum boolValue];
    
    if (![self.downloaders.allKeys containsObject:identifier] ||
        !serverURL ||
        !savePath) {
        return;
    }
    uexDownloader *downloader = self.downloaders[identifier];
    downloader.serverPath = serverURL;
    downloader.savePath = [self absPath:savePath];
    downloader.resumable = resumable;
    downloader.cbFunc = cb;
    [downloader startDownload];

}


- (NSNumber *)cancelDownload:(NSMutableArray *)inArguments{

    ACArgsUnpack(NSString *serverURL,NSNumber *optionNum) = inArguments;
    if(!serverURL){
        return UEX_FALSE;
    }
    uexDownloader *downloader = [self downloaderWithServerURL:serverURL];
    if (!downloader) {
        return UEX_FALSE;
    }
    uexDownloaderCancelOption option = uexDownloaderCancelOptionDefault;
    if ([optionNum boolValue]) {
        option |= uexDownloaderCancelOptionClearCache;
    }
    [downloader cancelDownloadWithOption:option];
    return UEX_TRUE;
}


- (NSNumber *)setHeaders:(NSMutableArray *)inArguments{
    ACArgsUnpack(NSString *identifier,NSDictionary *headers) = inArguments;
    uexDownloader *downloader = self.downloaders[identifier];
    if (!downloader || !headers) {
        return UEX_FALSE;
    }
    [downloader setHeaders:headers];
    return UEX_TRUE;
    
}

- (NSDictionary *)getInfo:(NSMutableArray *)inArguments{
    __block NSString *identifier = nil;
    __block NSDictionary *info = nil;
    
    @onExit{
        [self callbackWithFunctionKeyPathByMainThread:@"uexDownloaderMgr.cbGetInfo" arguments:ACArgsPack(identifier,@1,info.ac_JSONFragment)];

    };
     

    ACArgsUnpack(NSString *serverURL) = inArguments;

    uexDownloader *downloader = [self downloaderWithServerURL:serverURL];
    if (!downloader) {
        downloader = [[uexDownloader alloc]initFromCacheWithServerPath:serverURL];
    }

    identifier = downloader.identifier;
    info = downloader.info;
    
    return info;
    
    
}


- (NSNumber *)closeDownloader:(NSMutableArray *)inArguments{
    if([inArguments count] < 1){
        return UEX_FALSE;
    }
    ACArgsUnpack(NSString *identifier) = inArguments;
    uexDownloader *downloader = self.downloaders[identifier];
    if (!downloader) {
        return UEX_FALSE;
    }
    [downloader cancelDownload];
    [self.downloaders removeObjectForKey:downloader.identifier];
    return UEX_TRUE;
}



- (void)setDebugMode:(NSMutableArray *)inArguments{
    if([inArguments count] < 1){
        return;
    }
    if([inArguments[0] boolValue]){
        ACLogSetGlobalLogMode(ACLogModeDebug);
    }else{
        ACLogSetGlobalLogMode(ACLogModeInfo);
    }
}

#pragma mark - Callback Common

/**
 保证在主线程中完成JS回调操作

 @param jsFunc 回调JS方法
 @param args 参数
 */
- (void)jsCallbackExecuteByMainThread:(ACJSFunctionRef *)jsFunc withArguments:(NSArray *)args {
    if([NSThread isMainThread]){
        [jsFunc executeWithArguments:args];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [jsFunc executeWithArguments:args];
        });
    }
}

/**
 保证在主线程中完成JS回调操作
 
 @param jsString 回调需要执行的JS字符串
 */
- (void)callbackWithFunctionKeyPathByMainThread:(NSString *)JSKeyPath arguments:(nullable NSArray *)arguments {
    if([NSThread isMainThread]){
        [self.webViewEngine callbackWithFunctionKeyPath:JSKeyPath arguments:arguments];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.webViewEngine callbackWithFunctionKeyPath:JSKeyPath arguments:arguments];
        });
    }
}

#pragma mark - Test

#ifdef DEBUG

- (void)test:(NSMutableArray *)inArguments{

}
#endif


#pragma mark - Private 


- (uexDownloader *)downloaderWithServerURL:(NSString *)serverURL{
    uexDownloader *downloader = nil;
    for (uexDownloader *aDownloader in self.downloaders.allValues) {
        if ([aDownloader.serverPath isEqual:serverURL]) {
            downloader = aDownloader;
            break;
        }
    }
    return downloader;
}

/**
 在主线程将downloader解除引用。
 因为downloader中包含一个JSFunc的对象引用，当自身被解除引用触发内存回收的时候，就会在当前线程触发dealloc，也可能会在当前线程中触发持有的JSFunc对象的dealloc。而我们的ACJSFunctionRef的dealloc中存在访问JS对象的操作，该操作不允许在非主线程中进行，故而必须做保护。（暂时也没找到更好的办法，隐约觉得可能是引擎的ACJSFunctionRef的dealloc可以改一下，但是又怕引发其他问题）。 note at 20190823 by yipeng

 */
- (void)setDownloaderSessionBecomeInvalidByMainThread:(__kindof uexDownloader *)downloader {
    if([NSThread isMainThread]){
        [self.downloaders removeObjectForKey:downloader.identifier];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.downloaders removeObjectForKey:downloader.identifier];
        });
    }
}

#pragma mark - uexDownloaderDelegate

- (void)uexDownloader:(__kindof uexDownloader *)downloader taskDidCompletedWithError:(NSError *)error{
    
}
- (void)uexDownloader:(__kindof uexDownloader *)downloader sessionDidInvalidatedWithError:(NSError *)error{
    // 解除uexDownloader对象的引用，触发内存回收
    [self setDownloaderSessionBecomeInvalidByMainThread:downloader];
}
- (void)uexDownloaderDidFinishHandlingBackgroundSessionEvents:(__kindof uexDownloader *)downloader{
    
}

@end
