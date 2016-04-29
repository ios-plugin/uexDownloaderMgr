/**
 *
 *	@file   	: uexDownloadHelper.m  in EUExDownloaderMgr
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

#import "uexDownloadHelper.h"
#import <CommonCrypto/CommonCrypto.h>
#import "WidgetOneDelegate.h"
#import "WWidgetMgr.h"
#import "WWidget.h"
#import "EUExDownloaderMgr.h"
#import "EBrowserView.h"
#import "EUtility.h"
#import "BUtility.h"

static BOOL debugEnabled;


@implementation uexDownloadHelper

void uexDownloadLog(NSString *format,...){
    va_list list;
    va_start(list,format);
    if (debugEnabled || XCODE_DEBUG_MODE ) {
        NSLogv(format,list);
    }
    va_end(list);

}

+ (void)setDebugMode:(BOOL)mode{
    debugEnabled = mode;
}

+ (WWidget *)mainWidget{
    return theApp.mwWgtMgr.mainWidget;
}

+ (NSDictionary<NSString *,NSString *> *)AppCanHTTPHeadersWithEUExObj:(EUExDownloaderMgr *)euexObj{
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    WWidget *widget = euexObj.meBrwView.mwWgt;
    if (!widget) {
        widget = [self mainWidget];
    }
    NSString *time= [NSDate date].uexDownloader_timestamp;
    NSString *appId = @"";
    NSString *appKey = @"";
    
    NSString *pluginStr = @"widget/plugin";
    if ([widget.indexUrl rangeOfString:pluginStr].length == [pluginStr length]) {
        WWidget *mainWgt = [self mainWidget];
        appId = mainWgt.appId;
        appKey = mainWgt.widgetOneId;
        
        
    } else {
        if (widget.appKey) {
            appKey = [NSString stringWithFormat:@"%@",widget.appKey];
        }else{
            appKey = [NSString stringWithFormat:@"%@",widget.widgetOneId];
        }
        appId = widget.appId;
    }

    NSString *verifyStr = [NSString stringWithFormat:@"%@:%@:%@",appId,appKey,time].uexDownloader_MD5;
    verifyStr = [NSString stringWithFormat:@"md5=%@;ts=%@;",verifyStr,time];
    [dict setValue:appId forKey:@"x-mas-app-id"];
    [dict setValue:verifyStr forKey:@"appverify"];
    return [dict copy];
}

+ (NSURLSessionAuthChallengeDisposition)authChallengeDispositionWithSession:(NSURLSession *)session challenge:(NSURLAuthenticationChallenge *)challenge credential:(NSURLCredential *__autoreleasing *)credential{
    if(challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust) {
        //服务器认证
        /* 可以在这里添加服务器域名验证
         NSArray *trustHosts = @[@"www.baidu.com"];
         if (![trustHosts containsObject:challenge.protectionSpace.host]) {
         return NSURLSessionAuthChallengeCancelAuthenticationChallenge;
         }
         */
        //目前没有提供服务器的SSL证书认证功能,直接信任
        *credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
        return NSURLSessionAuthChallengeUseCredential;
    }
    
    if(challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodClientCertificate){
        //客户端认证
        SecIdentityRef identity=NULL;
        
        NSData *PKCS12Data=[NSData dataWithContentsOfFile:[BUtility clientCertficatePath]];
        if (![self extractPKCS12Data:PKCS12Data toIdentity:&identity]) {
            return NSURLSessionAuthChallengeCancelAuthenticationChallenge;
        }
        SecCertificateRef certificate = NULL;
        SecIdentityCopyCertificate (identity, &certificate);
        const void *certs[] = {certificate};
        CFArrayRef certArray = CFArrayCreate(kCFAllocatorDefault, certs, 1, NULL);
        *credential = [NSURLCredential credentialWithIdentity:identity certificates:(__bridge NSArray*)certArray persistence:NSURLCredentialPersistencePermanent];
        return NSURLSessionAuthChallengeUseCredential;
    }
    
    return NSURLSessionAuthChallengePerformDefaultHandling;
}

+ (OSStatus)extractPKCS12Data:(NSData *)PKCS12Data toIdentity:(SecIdentityRef *)identity {
    if (!PKCS12Data || PKCS12Data.length == 0) {
        return errSecSuccess;
    }
    OSStatus result = errSecSuccess;
    CFDataRef inPKCS12Data = (CFDataRef)CFBridgingRetain(PKCS12Data);
    CFStringRef password = (__bridge CFStringRef)theApp.useCertificatePassWord;
    const void *keys[] = {kSecImportExportPassphrase};
    const void *values[] = {password};
    CFDictionaryRef options = CFDictionaryCreate(NULL, keys, values, 1, NULL, NULL);
    CFArrayRef items = CFArrayCreate(NULL, 0, 0, NULL);
    result = SecPKCS12Import(inPKCS12Data, options, &items);
    if (result == 0) {
        CFDictionaryRef ident = CFArrayGetValueAtIndex(items,0);
        const void *tempIdentity = NULL;
        tempIdentity = CFDictionaryGetValue(ident, kSecImportItemIdentity);
        *identity = (SecIdentityRef)tempIdentity;
    }
    if(inPKCS12Data){
        CFRelease(inPKCS12Data);
    }
    if (options) {
        CFRelease(options);
    }
    return result;
}





@end
@implementation NSString (uexDownloaderMgr)

- (instancetype)uexDownloader_MD5{
    const char *cStr = [self UTF8String];
    unsigned char result[16];
    CC_MD5(cStr, strlen(cStr), result);
    return [NSString stringWithFormat:
            @"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
            result[0], result[1], result[2], result[3],
            result[4], result[5], result[6], result[7],
            result[8], result[9], result[10], result[11],
            result[12], result[13], result[14], result[15]
            ];
}
@end

@implementation NSDate(uexDownloaderMgr)

- (NSString *)uexDownloader_timestamp{
    unsigned long long time = [self timeIntervalSince1970] * 1000;
    NSString * timestamp = [NSString stringWithFormat:@"%lld",time];
    return timestamp;
}
@end

@implementation NSURL (uexDownloaderMgr)

+ (instancetype)uexDownloader_saveURLFromPath:(NSString *)savePath{
    NSURL *URL;
    if ([savePath.lowercaseString hasPrefix:@"file://"]) {
        URL = [NSURL URLWithString:savePath];
    }else{
        URL = [NSURL fileURLWithPath:savePath];
    }
    
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *folderPath = [savePath stringByDeletingLastPathComponent];
    BOOL isFolder = NO;
    if (![fm fileExistsAtPath:folderPath isDirectory:&isFolder] || !isFolder) {
        [fm createDirectoryAtPath:folderPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return URL;
}

@end

