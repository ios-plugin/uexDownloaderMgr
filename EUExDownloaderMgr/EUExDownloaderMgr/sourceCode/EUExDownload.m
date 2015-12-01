//
//  EUExDownload.m
//  WebKitCorePlam
//
//  Created by AppCan on 11-10-31.
//  Copyright 2011 AppCan. All rights reserved.
//
#import <CommonCrypto/CommonCrypto.h>
#import "EUtility.h"
#import "EUExDownload.h"
#import "EUExDownloaderMgr.h"
#import "BUtility.h"
#import "EBrowserView.h"
#import "WWidget.h"
#import "WidgetOneDelegate.h"
#import "ACEBaseViewController.h"
#import "EBrowserController.h"
#import "WWidgetMgr.h"

@implementation EUExDownload
@synthesize euexObj;
@synthesize opID,downFlag;
@synthesize dQueue;
 
#pragma mark -
#pragma mark - init

-(id)initWithUExObj:(EUExDownloaderMgr*)euexObj_ {
	if (self = [super init]) {
        euexObj = euexObj_;
		if (!dQueue) {
            dQueue = [[ASINetworkQueue alloc] init];
            dQueue.showAccurateProgress = YES;
            dQueue.shouldCancelAllRequestsOnFailure = NO;
            [dQueue go];
		}
	}
	return self;
}

-(void)downloadWithDlUrl:(NSString *)inDLUrl savePath:(NSString *)DLSavePath mode:(NSString *)inMode headerDict:(NSMutableDictionary *)headerDict{
    appendFileSize = 0;
    fileTotalLength = 0;
    NSString *headerStr = nil;
    //初始化Documents路径
    NSString *path = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
    //初始化临时文件路径
    NSString *folderPath = [path stringByAppendingPathComponent:@"temp"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL fileExists = [fileManager fileExistsAtPath:folderPath];
    if (!fileExists) {//如果不存在说创建,因为下载时,不会自动创建文件夹
        [fileManager createDirectoryAtPath:folderPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    NSRange range = [DLSavePath rangeOfString:[DLSavePath lastPathComponent]];
    NSString *dirName = [DLSavePath substringToIndex:range.location];
    PluginLog(@"dirName=%@",dirName);
    if (![fileManager fileExistsAtPath:dirName]) {
        [fileManager createDirectoryAtPath:dirName withIntermediateDirectories:YES attributes:nil error:nil];
    }
    NSString *tempPath = [folderPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.temp",[DLSavePath lastPathComponent]]];
    PluginLog(@"savapath = %@ and temppath = %@",DLSavePath,tempPath);
    //保存下载路径
    NSUserDefaults *udf = [NSUserDefaults standardUserDefaults];
    NSString *dPathKey = [NSString stringWithFormat:@"%@_savePath",inDLUrl];
    [udf setValue:DLSavePath forKey:dPathKey];
    [udf synchronize];
    int mode = [inMode intValue];
    NSRange range_ = [inDLUrl rangeOfString:@" "];
    if (NSNotFound != range_.location) {
        inDLUrl = [inDLUrl stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    }
    NSURL *url = [NSURL URLWithString:inDLUrl];
    self.asiRequest = [ASIHTTPRequest requestWithURL:url];
    NSRange ranges=[inDLUrl rangeOfString:@"https://"];
    if (NSNotFound !=ranges.location) {
        SecIdentityRef identity=NULL;
        SecTrustRef trust=NULL;
        SecCertificateRef certifica=NULL;
        NSData *PKCS12Data=[NSData dataWithContentsOfFile:[BUtility clientCertficatePath]];
        [BUtility extractIdentity:theApp.useCertificatePassWord andIdentity:&identity andTrust:&trust andCertChain:&certifica fromPKCS12Data:PKCS12Data];
        if (theApp.useCertificateControl) {
            [_asiRequest setValidatesSecureCertificate:YES];
            [_asiRequest setClientCertificateIdentity:identity];
        }else{
            [_asiRequest setValidatesSecureCertificate:NO];
            [_asiRequest setClientCertificateIdentity:nil];
        }
    }
    
    [_asiRequest setDelegate:self];
    [_asiRequest setDownloadProgressDelegate:self];
    [_asiRequest setTimeOutSeconds:120];
    [_asiRequest setDownloadDestinationPath:DLSavePath];
    [_asiRequest setTemporaryFileDownloadPath:tempPath];
    
    
    if (headerDict) {
        headerStr = [self requestIsVerify];
        [headerDict setObject:headerStr forKeyedSubscript:@"appverify"];
        if (self.verifyWithAppId) {
            [headerDict setObject:self.verifyWithAppId forKey:@"x-mas-app-id"];
        }
        [_asiRequest setRequestHeaders:headerDict];
        
    }else{
        headerStr = [self requestIsVerify];
        NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:_asiRequest.requestHeaders];
        [dict setObject: headerStr forKeyedSubscript:@"appverify"];
        if (self.verifyWithAppId) {
        [dict setObject:self.verifyWithAppId forKey:@"x-mas-app-id"];
        }
        [_asiRequest setRequestHeaders:dict];
    }
    if (mode==1) {
        [_asiRequest setAllowResumeForFileDownloads:YES];
    }
    [_asiRequest setUserInfo:[NSDictionary dictionaryWithObject:inDLUrl forKey:@"reqUrl"]];
    [dQueue addOperation:_asiRequest];
}

/**
 *  设置请求头的验证
 *
 *  @param inName nil
 */
-(NSString*)requestIsVerify{
    WWidget *curWgt = euexObj.meBrwView.mwWgt;
    NSString *time= [self getCurrentTS];
    NSString *appId = @"";
    NSString *appKey = @"";
   
    NSString *pluginStr = @"widget/plugin";
    if ([curWgt.indexUrl rangeOfString:pluginStr].length == [pluginStr length]) {
        WWidgetMgr *wgtMgr = euexObj.meBrwView.meBrwCtrler.mwWgtMgr;
        WWidget *mainWgt = [wgtMgr mainWidget];
        
        appId = mainWgt.appId;
        appKey = mainWgt.widgetOneId;
        
        
    } else {
        if (curWgt.appKey) {
            appKey = [NSString stringWithFormat:@"%@",curWgt.appKey];
        }else{
            appKey = [NSString stringWithFormat:@"%@",curWgt.widgetOneId];
        }
        appId = curWgt.appId;
    }
    self.verifyWithAppId = appId;
    NSString *str = [NSString stringWithFormat:@"%@:%@:%@",appId,appKey,time];
    str = [self md5:str];
    str = [NSString stringWithFormat:@"md5=%@;ts=%@;",str,time];
     return str;
}


#pragma mark -
#pragma mark - request delegate

-(void)request:(ASIHTTPRequest *)request didReceiveResponseHeaders:(NSDictionary *)responseHeaders{
	fileTotalLength = request.contentLength;
    if (fileTotalLength == 0) {
		fileTotalLength = -1;
	}else {
		NSString *urlStr = [request.userInfo objectForKey:@"reqUrl"];
		NSUserDefaults *udf = [NSUserDefaults standardUserDefaults];
		NSString *fsKey = [NSString stringWithFormat:@"%@_fileSize",urlStr];
        //update 7.17
        if (![udf objectForKey:fsKey]) {
            [udf setValue:[NSString stringWithFormat:@"%lld",fileTotalLength] forKey:fsKey];
            [udf synchronize];
        }
	}
}

-(void)request:(ASIHTTPRequest *)request didReceiveBytes:(long long)bytes{
 	appendFileSize+=bytes;
    	int percent = 0;
     percent= appendFileSize*100/(fileTotalLength);
    	if (percent > 100) {
            percent = 100;
        }
    [euexObj uexSuccessWithOpId:[self.opID intValue] fileSize:fileTotalLength percent:percent status:UEX_DOWNLOAD_DOWNLOADING];
}

-(void)setProgress:(float)newProgress{
//	if (fileTotalLength>0) {
//        [euexObj uexSuccessWithOpId:[self.opID intValue] fileSize:(NSInteger)fileTotalLength percent:newProgress*100 status:UEX_DOWNLOAD_DOWNLOADING];
//	}
}

-(void)requestFailed:(ASIHTTPRequest *)request{
    //保存现场
    NSUserDefaults *udf = [NSUserDefaults standardUserDefaults];
	NSString *urlstr = [request.userInfo objectForKey:@"reqUrl"];
	NSString *curKey = [NSString stringWithFormat:@"%@_currentSize",urlstr];
	[udf setValue:[NSString stringWithFormat:@"%lld",appendFileSize] forKey:curKey];
	NSDateFormatter *df = [[NSDateFormatter alloc] init];
	[df setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
	NSString *dateString = [df stringFromDate:[NSDate date]];
	[df release];
	[udf setValue:dateString forKey:[NSString stringWithFormat:@"%@_lastTime",urlstr]];
 	[euexObj uexSuccessWithOpId:[self.opID intValue] fileSize:0 percent:0 status:UEX_DOWNLOAD_FAIL];
	[self removeRequestFromQueue:urlstr];
	[euexObj.downObjDict removeObjectForKey:self.opID];
}

-(void)requestFinished:(ASIHTTPRequest *)request{
 	[euexObj uexSuccessWithOpId:[self.opID intValue] fileSize:(NSInteger)fileTotalLength percent:100 status:UEX_DOWNLOAD_FINISH];
	[self removeRequestFromQueue:[[request userInfo] objectForKey:@"reqUrl"]];
	[euexObj.downObjDict removeObjectForKey:self.opID];
}

#pragma mark -
#pragma mark - close dealloc

-(void)removeRequestFromQueue:(NSString *)reqUrl{
    for (ASIHTTPRequest *r in [dQueue operations]) {
        NSString *url = [r.userInfo objectForKey:@"reqUrl"];
        if ([url isEqualToString:reqUrl]) {
            [r clearDelegatesAndCancel];
        }
    }
}

-(BOOL)closeDownload{
    for (ASIHTTPRequest *request in [dQueue operations]) {
		//保存现场
		NSUserDefaults *udf = [NSUserDefaults standardUserDefaults];
		NSString *urlstr = [request.userInfo objectForKey:@"reqUrl"];
		NSString *curKey = [NSString stringWithFormat:@"%@_currentSize",urlstr];
		[udf setValue:[NSString stringWithFormat:@"%lld",appendFileSize] forKey:curKey];
		NSDateFormatter *df = [[NSDateFormatter alloc] init];
		[df setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
		NSString *dateString = [df stringFromDate:[NSDate date]];
		[df release];
		[udf setValue:dateString forKey:[NSString stringWithFormat:@"%@_lastTime",urlstr]];
		[request clearDelegatesAndCancel];
    }
	return YES;
}

#pragma mark -
#pragma mark - md5

- (NSString *)md5:(NSString *)appKeyAndAppId {
    const char *cStr = [appKeyAndAppId UTF8String];
    unsigned char result[16];
    CC_MD5(cStr, strlen(cStr), result); // This is the md5 call
    return [NSString stringWithFormat:
            @"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
            result[0], result[1], result[2], result[3],
            result[4], result[5], result[6], result[7],
            result[8], result[9], result[10], result[11],
            result[12], result[13], result[14], result[15]
            ];
}

#pragma mark -
#pragma mark - 获得当前时间戳

-(NSString *)getCurrentTS{
    unsigned long long time = [[NSDate  date] timeIntervalSince1970] * 1000;
    
    NSString * timeSp = [NSString stringWithFormat:@"%lld",time];
    return timeSp;
    //    NSDate* dat = [NSDate dateWithTimeIntervalSinceNow:0];
    //    NSTimeInterval a = [dat timeIntervalSince1970]*1000;
    //    NSString *timeString = [NSString stringWithFormat:@"%d",a];//转为字符型
    //    return timeString;
}


-(void)dealloc{
	if (dQueue) {
        [self closeDownload];
		[dQueue release];
		dQueue = nil;
	}
    if (opID) {
        [opID release];
        opID = nil;
    }
    if (_asiRequest) {
        [_asiRequest setDelegate:nil];
        [_asiRequest release];
        _asiRequest = nil;
    }
	[super dealloc];
}
@end
