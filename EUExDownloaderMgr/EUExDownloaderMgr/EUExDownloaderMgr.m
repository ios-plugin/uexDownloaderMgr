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
#import "ACEUtils.h"


#define UEX_FALSE @(NO)
#define UEX_TRUE @(YES)




@interface EUExDownloaderMgr()
@property (nonatomic,strong)NSMutableDictionary<NSString *,uexDownloader *> *downloaders;
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
    for(uexDownloader *aDownloader in self.downloaders.allValues){
        [aDownloader clean];
    }
    [self.downloaders removeAllObjects];
}
- (void)dealloc{
    [self clean];
}
#pragma mark - API
- (NSNumber *)createDownloader:(NSMutableArray *)inArguments{
    __block NSNumber *result = @1;
    __block NSString *identifier = nil;

    @onExit{
        if (ACE_Available()) {
            [EUtility browserView:self.meBrwView
      callbackWithFunctionKeyPath:@"uexDownloaderMgr.cbCreateDownloader"
                        arguments:ACE_ArgsPack(identifier,@2,result)
                       completion:nil];
        }else{
            NSString *jsStr = [NSString stringWithFormat:@"if(uexDownloaderMgr.cbCreateDownloader){uexDownloaderMgr.cbCreateDownloader(%@,%@,%@);}",identifier.JSONFragment,@2,result];
            [EUtility brwView:self.meBrwView evaluateScript:jsStr];
        }
    };
    if([inArguments count] < 1){
        return result;
    }
    identifier = getString(inArguments[0]);
    if ([self.downloaders.allKeys containsObject:identifier]) {
        return result;
    }
    uexDownloader *downloader = [[uexDownloader alloc]initWithIdentifier:identifier euexObj:self];
    if (!downloader) {
        return result;
    }
    [self.downloaders setObject:downloader forKey:identifier];
    result = @0;
    return result;
    
}

- (NSNumber *)download:(NSMutableArray *)inArguments{
    if([inArguments count] < 4){
        return UEX_FALSE;
    }
    NSString *identifier = getString(inArguments[0]);
    NSString *serverURL = getString(inArguments[1]);
    NSString *savePath = getString(inArguments[2]);
    BOOL resumable = [inArguments[3] boolValue];
    
    if (![self.downloaders.allKeys containsObject:identifier] ||
        !serverURL ||
        !savePath) {
        return UEX_FALSE;
    }
    uexDownloader *downloader = self.downloaders[identifier];
    downloader.serverPath = serverURL;
    downloader.savePath = [self absPath:savePath];
    downloader.resumable = resumable;
    [downloader startDownload];
    return UEX_TRUE;
}


- (NSNumber *)cancelDownload:(NSMutableArray *)inArguments{
    if([inArguments count] < 1){
        return UEX_FALSE;
    }
    NSString *serverURL = getString(inArguments[0]);
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
    NSString *identifier = getString(inArguments[0]);
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
    __block NSString *identifier = nil;
    __block NSDictionary *info = nil;
    
    @onExit{
        if (ACE_Available()) {
            [EUtility browserView:self.meBrwView
      callbackWithFunctionKeyPath:@"uexDownloaderMgr.cbGetInfo"
                        arguments:ACE_ArgsPack(identifier,@1,info.JSONFragment)
                       completion:nil];
        }else{
            NSString *jsStr = [NSString stringWithFormat:@"if(uexDownloaderMgr.cbGetInfo){uexDownloaderMgr.cbGetInfo(%@,%@,%@)};",identifier.JSONFragment,@1,info.JSONFragment.JSONFragment];
            [EUtility brwView:self.meBrwView evaluateScript:jsStr];
        }
    };
     
    if (inArguments.count == 0) {
        return @"";
    }
    NSString *serverURL = getString(inArguments[0]);
    uexDownloader *downloader = [self downloaderWithServerURL:serverURL];
    if (!downloader) {
        downloader = [[uexDownloader alloc]initFromCacheWithServerPath:serverURL];
    }

    identifier = downloader.identifier;
    info = downloader.info;
    
    return [info JSONFragment];
    
    
}


- (NSNumber *)closeDownloader:(NSMutableArray *)inArguments{
    if([inArguments count] < 1){
        return UEX_FALSE;
    }
    NSString *identifier = getString(inArguments[0]);
    uexDownloader *downloader = self.downloaders[identifier];
    if (!downloader) {
        return UEX_FALSE;
    }
    [downloader clean];
    [self.downloaders removeObjectForKey:downloader.identifier];
    return UEX_TRUE;
}



- (void)setDebugMode:(NSMutableArray *)inArguments{
    if([inArguments count] < 1){
        return;
    }
    [uexDownloadHelper setDebugMode:[inArguments[0] boolValue]];
}


#pragma mark - Test

#ifdef DEBUG

- (void)test:(NSMutableArray *)inArguments{
    UEXLog(@"%@%@%@",@1,@2,@3);
}
#endif


#pragma mark - Private 

static NSString * getString(id obj){
    NSString *str = nil;
    if ([obj isKindOfClass:[NSString class]]) {
        str = obj;
    }
    if ([obj isKindOfClass:[NSNumber class]]) {
        str = [obj stringValue];
    }
    return str;
}

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
#pragma mark - uexDownloaderDelegate

- (void)uexDownloader:(__kindof uexDownloader *)downloader taskDidCompletedWithError:(NSError *)error{
    
}
- (void)uexDownloader:(__kindof uexDownloader *)downloader sessionDidInvalidatedWithError:(NSError *)error{
    [self.downloaders removeObjectForKey:downloader.identifier];
}
- (void)uexDownloaderDidFinishHandlingBackgroundSessionEvents:(__kindof uexDownloader *)downloader{
    
}

@end
