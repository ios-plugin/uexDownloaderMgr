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
#import "JSON.h"
#import "EUtility.h"
#import "uexDownloader.h"
#import "EXTScope.h"
#import "uexDownloadInfo.h"
#import "uexDownloadBackgroundTaskManager.h"






@interface EUExDownloaderMgr()
@property (nonatomic,strong)NSMutableDictionary<NSNumber *,uexDownloader *> *downloaders;
@end
@implementation EUExDownloaderMgr

#pragma mark - Life Cycle
- (instancetype)initWithBrwView:(EBrowserView *)eInBrwView{
    self=[super initWithBrwView:eInBrwView];
    if(self){
        _downloaders = [NSMutableDictionary dictionary];
    }
    return self;
}
- (void)clean{
    for(uexDownloader *aDownloader in self.downloaders){
        [aDownloader clean];
    }
}
- (void)dealloc{
    [self clean];
}
#pragma mark - API
- (NSNumber *)createDownloader:(NSMutableArray *)inArguments{
    __block NSNumber *result = @1;
    __block NSInteger identifier = NSIntegerMin;

    @onExit{
        [self callbackWithFunction:@"cbCreateDownloader" arguments:UEX_ARGS_PACK(@(identifier),@2,result)];
    };
    if([inArguments count] < 1){
        return result;
    }
    identifier = [inArguments[0] integerValue];
    
    if ([self.downloaders.allKeys containsObject:@(identifier)]) {
        return result;
    }
    uexDownloader *downloader = [[uexDownloader alloc]initWithIdentifier:identifier euexObj:self];
    if (!downloader) {

        return result;
    }
    [self.downloaders setObject:downloader forKey:@(identifier)];
    result = @0;

    return result;
    
}

- (NSNumber *)download:(NSMutableArray *)inArguments{
    if([inArguments count] < 4){
        return UEX_FALSE;
    }
    NSNumber *identifier = @([inArguments[0] integerValue]);
    NSString *serverURL = UEX_STRING_VALUE_OR_NIL(inArguments[1]);
    NSString *savePath = UEX_STRING_VALUE_OR_NIL(inArguments[2]);
    BOOL resumable = [inArguments[3] boolValue];
    
    if (![self.downloaders.allKeys containsObject:identifier] ||
        !serverURL ||
        !savePath) {
        return UEX_FALSE;
    }
    uexDownloader *downloader = self.downloaders[identifier];
    uexDownloadInfo *info;
    if (resumable) {
        info = [uexDownloadInfo cachedInfoWithDownloadPath:serverURL];
        if (info) {
            info.savePath = savePath;
            info.downloadPath = serverURL;
        }
    }
    if (!info) {
        info = [[uexDownloadInfo alloc]initWithDownloadPath:serverURL savePath:savePath headers:downloader.headers];
    }
    info.resumable = resumable;
    [downloader getPreparedWithDownloadInfo:info];
    [downloader startDownload];
    return UEX_TRUE;
}


- (NSNumber *)cancelDownload:(NSMutableArray *)inArguments{
    if([inArguments count] < 1){
        return UEX_FALSE;
    }
    
    NSString *serverURL = UEX_STRING_VALUE_OR_NIL(inArguments[0]);
    uexDownloader *downloader = [self downloaderWithServerURL:serverURL];
    if (!downloader) {
        return UEX_FALSE;
    }
    uexDownloaderCancelOption option = uexDownloaderCancelOptionDefault;
    if (inArguments.count > 1 && [inArguments[1] boolValue]) {
        option |= uexDownloaderCancelOptionClearCache;
    }
    [downloader cancelDownloadWithOption:option];
    return UEX_TRUE;
}


- (NSNumber *)setHeaders:(NSMutableArray *)inArguments{
    if (inArguments.count < 2) {
        return UEX_FALSE;
    }
    NSNumber *identifier = @([inArguments[0] integerValue]);
    uexDownloader *downloader = self.downloaders[identifier];
    if (!downloader) {
        return UEX_FALSE;
    }
    id headers = [inArguments[1] JSONValue];
    if (!headers || ![headers isKindOfClass:[NSDictionary class]]) {
        return UEX_FALSE;
    }
    [downloader setHeaders:headers];
    return UEX_TRUE;
    
}

- (NSString *)getInfo:(NSMutableArray *)inArguments{
    __block NSNumber *identifier = @(NSIntegerMin);
    __block uexDownloadInfo *info = nil;
    
    @onExit{
        [self callbackWithFunction:@"cbGetInfo" arguments:UEX_ARGS_PACK(identifier,@1,[info dictDescription])];
        NSString *jsStr = [NSString stringWithFormat:@"if(uexDownloaderMgr.cbGetInfo){uexDownloaderMgr.cbGetInfo(%@,%@,\"%@\")};",identifier,@(1),[[info dictDescription] JSONFragment]?:@""];
        [EUtility brwView:self.meBrwView evaluateScript:jsStr];
    };
     
    if (inArguments.count == 0) {
        return @"";
    }
    NSString *serverURL = UEX_STRING_VALUE_OR_NIL(inArguments[0]);
    uexDownloader *downloader = [self downloaderWithServerURL:serverURL];
    if (downloader) {
        identifier = downloader.identifier;
        info = downloader.info;
    }
    if (!info) {
        info = [uexDownloadInfo cachedInfoWithDownloadPath:serverURL];
    }
    if (!info) {
        return @"";
    }
    return [[info dictDescription] JSONFragment]?:@"";
    
    
}

- (NSNumber *)clearTask:(NSMutableArray *)inArguments{
    if([inArguments count] < 1){
        return UEX_FALSE;
    }
    NSString *serverURL = UEX_STRING_VALUE_OR_NIL(inArguments[0]);
    uexDownloadInfo *info;
    uexDownloader *downloader = [self downloaderWithServerURL:serverURL];
    if (downloader) {
        [downloader cancelDownloadWithOption:uexDownloaderCancelOptionClearCache];
        info = downloader.info;
    }
    if (!info) {
        info = [uexDownloadInfo cachedInfoWithDownloadPath:serverURL];
    }
    if (!info) {
        return UEX_FALSE;
    }
    BOOL deleteDownloadedFile = inArguments.count > 1 ? [inArguments[1] boolValue] : NO;
    if (deleteDownloadedFile) {
        [[NSFileManager defaultManager]removeItemAtPath:info.savePath error:nil];
    }
    [uexDownloadInfo clearCachedInfoWithDownloadPath:serverURL];
    return UEX_TRUE;
}

- (NSNumber *)closeDownloader:(NSMutableArray *)inArguments{
    if([inArguments count] < 1){
        return UEX_FALSE;
    }
    NSNumber *identifier = @([inArguments[0] integerValue]);
    uexDownloader *downloader = self.downloaders[identifier];
    if (!downloader) {
        return UEX_FALSE;
    }
    [downloader clean];
    [self.downloaders removeObjectForKey:downloader.identifier];
    return UEX_TRUE;
}

- (void)clearCache:(NSMutableArray *)inArguments{
    if([inArguments count] < 1){
        return;
    }
    id info = [inArguments[0] JSONValue];
    if(!info || ![info isKindOfClass:[NSDictionary class]]){
        return;
    }
    if (info[@"downloaderServerURLs"] && [info[@"downloaderServerURLs"] isKindOfClass:[NSArray class]]) {
        NSArray *urls = info[@"downloaderServerURLs"];
        if (urls.count == 0) {
            UEXLog(@"clear all downloaders");
            [uexDownloadInfo clearAllCachedInfo];
        }else{
            for (NSString *URL in urls) {
                UEXLog(@"clear downloader with URL:%@",URL);
                [uexDownloadInfo clearCachedInfoWithDownloadPath:URL];
            }
        }
    }
    if (info[@"bachgroundTaskIdentifiers"] && [info[@"bachgroundTaskIdentifiers"] isKindOfClass:[NSArray class]]) {
        NSArray *identifiers = info[@"bachgroundTaskIdentifiers"];
        if (identifiers.count == 0) {
            UEXLog(@"clear all background task");
            [uexDownloadBackgroundTaskInfo clearAllCachedInfo];
            
        }else{
            for (NSString *shortIdentifier in identifiers) {
                UEXLog(@"clear background task with identifier:%@",shortIdentifier);
                [uexDownloadBackgroundTaskInfo clearCachedInfoWithShortIdentifier:shortIdentifier];
            }
        }
    }
    
}

- (void)setDebugMode:(NSMutableArray *)inArguments{
    if([inArguments count] < 1){
        return;
    }
    [uexDownloadHelper setDebugMode:[inArguments[0] boolValue]];
}

#pragma mark - Background



static NSString *const kIdentifierKey = @"identifier";


+ (void)application:(UIApplication *)application handleEventsForBackgroundURLSession:(NSString *)identifier completionHandler:(void (^)())completionHandler{

    [UEX_BG_TASK_MGR handleEventsForBackgroundURLSession:identifier completionHandler:completionHandler];
}



- (NSString *)createBackgroundTask:(NSMutableArray *)inArguments{
    BOOL result = NO;
    uexDownloadBackgroundTask *task = nil;

    if([inArguments count] < 1){
        return [self returnValueOfCreatingBackgroundTaskWithResult:result task:task];
    }
    id info = [inArguments[0] JSONValue];
    if(!info || ![info isKindOfClass:[NSDictionary class]]){
        return [self returnValueOfCreatingBackgroundTaskWithResult:result task:task];
    }
    NSString *identifier = info[kIdentifierKey];
    BOOL resumeFromCache = [info[@"resumeFromCache"] boolValue];
    
    result = [UEX_BG_TASK_MGR createTaskWithShortIdentifier:identifier resumeFromCache:resumeFromCache];
    
    if (result) {
        task = [UEX_BG_TASK_MGR taskWithShortIdentifier:identifier];
    }
    return [self returnValueOfCreatingBackgroundTaskWithResult:result task:task];
}

- (NSString *)returnValueOfCreatingBackgroundTaskWithResult:(BOOL)result task:(uexDownloadBackgroundTask *)task{
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    uexDownloadBackgroundTaskInfo *info = task.info;
    if (result && info) {
        [dict setValue:info.downloadPath forKey:@"serverURL"];
        [dict setValue:info.headers forKey:@"headers"];
        [dict setValue:info.savePath forKey:@"savePath"];
        [dict setValue:@(info.resumable) forKey:@"canResume"];
    }
    [dict setValue:@(result) forKey:@"result"];
    return [dict JSONFragment];
}


- (NSNumber *)startBackgroundTask:(NSMutableArray *)inArguments{
    if([inArguments count] < 1){
        return UEX_FALSE;
    }
    id info = [inArguments[0] JSONValue];
    if(!info || ![info isKindOfClass:[NSDictionary class]]){
        return UEX_FALSE;
    }
    
    NSString *identifier = info[kIdentifierKey];
    uexDownloadBackgroundTask *task = [UEX_BG_TASK_MGR taskWithShortIdentifier:identifier];
    if(!task){
        return UEX_FALSE;
    }
    if (info[@"serverURL"] && [info[@"serverURL"] isKindOfClass:[NSString class]]) {
        task.info.downloadPath = info[@"serverURL"];
    }
    if (info[@"savePath"] && [info[@"savePath"] isKindOfClass:[NSString class]]) {
        task.info.savePath = [self absPath:info[@"savePath"]];
    }
    if (info[@"headers"] && [info[@"headers"] isKindOfClass:[NSDictionary class]]) {
        task.info.headers = info[@"headers"];
    }
    if (info[@"canResume"]) {
        task.info.resumable = [info[@"canResume"] boolValue];
    }
    return @([UEX_BG_TASK_MGR startTaskWithShortIdentifier:identifier]);
}

- (NSNumber *)cancelBackgroundTask:(NSMutableArray *)inArguments{
    if([inArguments count] < 1){
        return UEX_FALSE;
    }
    id info = [inArguments[0] JSONValue];
    if(!info || ![info isKindOfClass:[NSDictionary class]]){
        return UEX_FALSE;
    }
    
    NSString *identifier = info[kIdentifierKey];
    uexDownloadBackgroundTask *task = [UEX_BG_TASK_MGR taskWithShortIdentifier:identifier];
    if(!task){
        return UEX_FALSE;
    }
    
    uexDownloaderCancelOption option = 0;
    if(info[@"option"]){
        option = [info[@"option"] integerValue];
    }
    [task cancelDownloadWithOption:option];
    return UEX_TRUE;
    
    
}


- (NSNumber *)observeBackgroundTask:(NSMutableArray *)inArguments{
    if([inArguments count] < 1){
        return UEX_FALSE;
    }
    id info = [inArguments[0] JSONValue];
    if(!info || ![info isKindOfClass:[NSDictionary class]]){
        return UEX_FALSE;
    }
    NSString *identifier = info[kIdentifierKey];
    if (!identifier || identifier.length == 0) {
        return UEX_FALSE;
    }
    return @([UEX_BG_TASK_MGR setObserver:self.meBrwView forTaskWithShortIdentifier:identifier]);
}

- (NSString *)getBackgroundTaskInfo:(NSMutableArray *)inArguments{
    if([inArguments count] < 1){
        return nil;
    }
    id info = [inArguments[0] JSONValue];
    if(!info || ![info isKindOfClass:[NSDictionary class]]){
        return nil;
    }
    NSString *identifier = info[kIdentifierKey];
    if (!identifier || identifier.length == 0) {
        return nil;
    }
    uexDownloadBackgroundTask *task = [UEX_BG_TASK_MGR taskWithShortIdentifier:identifier];
    if (task) {
        return [[task.info dictDescription]JSONFragment];
    }
    return [[[uexDownloadBackgroundTaskInfo cachedInfoWithShortIdentifier:identifier] dictDescription]JSONFragment];
}

#pragma mark - Test

#ifdef DEBUG

- (void)test:(NSMutableArray *)inArguments{
    UEXLog(@"%@%@%@",@1,@2,@3);
}
#endif


#pragma mark - Private 

static NSString *const kPluginName = @"uexDownloaderMgr";

- (uexDownloader *)downloaderWithServerURL:(NSString *)serverURL{
    uexDownloader *downloader = nil;
    for (uexDownloader *aDownloader in self.downloaders.allValues) {
        if ([aDownloader.info.downloadPath isEqual:serverURL]) {
            downloader = aDownloader;
            break;
        }
    }
    return downloader;
}

- (void)callbackWithFunction:(NSString *)funcName arguments:(NSArray *)args{
    if([EUtility respondsToSelector:@selector(browserView:callbackWithFunctionKeyPath:arguments:completion:)]){
        [EUtility browserView:self.meBrwView
  callbackWithFunctionKeyPath:[NSString stringWithFormat:@"%@.%@",kPluginName,funcName]
                    arguments:args
                   completion:^(JSValue *returnValue) {
                       if (returnValue) {
                           
                       }
                   }];
    }else{
        [EUtility brwView:self.meBrwView evaluateScript:[self JSScriptByFunction:funcName arguments:args]];
        
    }
}

- (NSString *)JSScriptByFunction:(NSString *)funcName arguments:(NSArray *)args{
    NSString * (^trans)(id) =  ^(id obj){
        if ([obj isKindOfClass:[NSNull class]]) {
            return @"(undefined)";
        }
        if ([obj isKindOfClass:[NSString class]]||[obj isKindOfClass:[NSDictionary class]] || [obj isKindOfClass:[NSArray class]]) {
            return [obj JSONFragment];
        }
        return [NSString stringWithFormat:@"%@",obj];
    };
    NSUInteger count = args.count;
    if (!args || count == 0) {
        return [NSString stringWithFormat:@"if(%@.%@){%@.%@();}",kPluginName,funcName,kPluginName,funcName];
    }
    NSMutableString *argsFormat = [trans(args[0]) mutableCopy];
    for (NSInteger i = 1; i < count; i++) {
        [argsFormat appendString:@","];
        [argsFormat appendString:trans(args[i])];
    }
    return [NSString stringWithFormat:@"if(%@.%@){%@.%@(%@);}",kPluginName,funcName,kPluginName,funcName,argsFormat];
}

@end
