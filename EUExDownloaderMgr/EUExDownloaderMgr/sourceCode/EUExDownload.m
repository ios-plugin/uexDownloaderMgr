//
//  EUExDownload.m
//  WebKitCorePlam
//
//  Created by AppCan on 11-10-31.
//  Copyright 2011 AppCan. All rights reserved.
//
#import "EUtility.h"
#import "EUExDownload.h"
#import "EUExDownloaderMgr.h"
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
    ASIHTTPRequest *asiRequest = [ASIHTTPRequest requestWithURL:url];
    [asiRequest setDelegate:self];
    [asiRequest setDownloadProgressDelegate:self];
    [asiRequest setTimeOutSeconds:120];
    [asiRequest setDownloadDestinationPath:DLSavePath];
    [asiRequest setTemporaryFileDownloadPath:tempPath];
    if (headerDict) {
        [asiRequest setRequestHeaders:headerDict];
    }
    if (mode==1) {
        [asiRequest setAllowResumeForFileDownloads:YES];
    }
    [asiRequest setUserInfo:[NSDictionary dictionaryWithObject:inDLUrl forKey:@"reqUrl"]];
    [dQueue addOperation:asiRequest];
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
    //	int percent = 0;
    //
    //	if (fileTotalLength!=0) {
    //		 percent= appendFileSize*100/(fileTotalLength);
    //	}else {
    //		 percent = 100;
    //	}
    //	[euexObj uexSuccessWithOpId:[self.opID intValue] fileSize:fileTotalLength percent:percent status:UEX_DOWNLOAD_DOWNLOADING];
}

-(void)setProgress:(float)newProgress{
	if (fileTotalLength>0) {
        [euexObj uexSuccessWithOpId:[self.opID intValue] fileSize:(NSInteger)fileTotalLength percent:newProgress*100 status:UEX_DOWNLOAD_DOWNLOADING];
	}
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
	[super dealloc];
}
@end
