//
//  EUExDownloaderMgr.m
//  webKitCorePalm
//
//  Created by AppCan on 11-11-1.
//  Copyright 2011 AppCan. All rights reserved.
//

#import "EUExDownloaderMgr.h"
#import "EUtility.h"
#import "EUExDownload.h"
#import "EUExBaseDefine.h"
#import "EUExBaseDefine.h"
#import "JSON.h"

@implementation EUExDownloaderMgr

@synthesize downObjDict;

-(id)initWithBrwView:(EBrowserView *) eInBrwView{
	if (self = [super initWithBrwView:eInBrwView]) {
		NSMutableDictionary * dict = [[NSMutableDictionary alloc] initWithCapacity:UEX_PLATFORM_CALL_ARGS];
		self.downObjDict = dict;
		[dict release];
	}
	return self;
}

-(void)dealloc{
	if (downObjDict) {
		for (EUExDownload *dObj in [downObjDict allValues]) {
			if (dObj) {
				[dObj release];
				dObj = nil;
			}
		}
		[downObjDict removeAllObjects];
		[downObjDict release];
		downObjDict = nil;
	}
	[super dealloc];
}

-(void)createDownloader:(NSMutableArray *)inArguments{
	NSString *inOpId = [inArguments objectAtIndex:0];
	if ([downObjDict objectForKey:inOpId]) {
		[self jsSuccessWithName:@"uexDownloaderMgr.cbCreateDownloader" opId:[inOpId intValue] dataType:UEX_CALLBACK_DATATYPE_INT intData:UEX_CFAILED];
	}else {
		//初始化对象，存在字典中
        EUExDownload *downloadObj = [[EUExDownload alloc] initWithUExObj:self];
		downloadObj.opID = [NSNumber numberWithInt:[inOpId intValue]];
		downloadObj.downFlag = YES;
        [downObjDict setObject:downloadObj forKey:inOpId];
        [downloadObj release];
        [self jsSuccessWithName:@"uexDownloaderMgr.cbCreateDownloader" opId:[inOpId intValue] dataType:UEX_CALLBACK_DATATYPE_INT intData:UEX_CSUCCESS];
	}
}
//设置头
-(void)setHeaders:(NSMutableArray *)inArguments{
    
    if ([inArguments isKindOfClass:[NSMutableArray class]] && [inArguments count]>=2) {
        NSString *inOpId = [inArguments objectAtIndex:0];
        NSString *inJsonHeaderStr = [inArguments objectAtIndex:1];
        
        EUExDownload *downloadObj = [downObjDict objectForKey:inOpId];
        if (downloadObj) {
            
            self.headerDict = [inJsonHeaderStr JSONValue];
            //NSLog(@"----2--%@",self.headerDict);
            
        }
    }
}

-(void)getInfo:(NSMutableArray *)inArguments{
	NSString *urlstr = [inArguments objectAtIndex:0];
	NSUserDefaults *udf = [NSUserDefaults standardUserDefaults];
	NSString *fileSizeStr = [udf valueForKey:[NSString stringWithFormat:@"%@_fileSize",urlstr]];
	NSString *currentSizeStr = [udf valueForKey:[NSString stringWithFormat:@"%@_currentSize",urlstr]];
	NSString *pathStr = [udf valueForKey:[NSString stringWithFormat:@"%@_savePath",urlstr]];
	NSString *timeStr = [udf valueForKey:[NSString stringWithFormat:@"%@_lastTime",urlstr]];
	if ([fileSizeStr length]>0||[currentSizeStr length]>0||[pathStr length]>0||[timeStr length]>0) {
		if (fileSizeStr==nil) {
			fileSizeStr = @"";
		}
		if (currentSizeStr == nil) {
			currentSizeStr = @"";
		}
		if (pathStr==nil) {
			pathStr = @"";
		}
		if (timeStr==nil) {
			timeStr = @"";
		}
		NSDictionary *dict = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:fileSizeStr,currentSizeStr,pathStr,timeStr,nil] forKeys:[NSArray arrayWithObjects:@"fileSize",@"currentSize",@"savePath",@"lastTime",nil]];
		NSString *jsonstr = [dict JSONFragment];
		if (jsonstr) {
			[self jsSuccessWithName:@"uexDownloaderMgr.cbGetInfo" opId:0 dataType:UEX_CALLBACK_DATATYPE_JSON strData:jsonstr];
		}
	}else {
		[self jsSuccessWithName:@"uexDownloaderMgr.cbGetInfo" opId:0 dataType:UEX_CALLBACK_DATATYPE_JSON strData:@""];
	}
}

-(void)clearTask:(NSMutableArray *)inArguments{
	NSString *urlstr = [inArguments objectAtIndex:0];
    int clearMode = 0;
    if ([inArguments count]==2) {
        clearMode = [[inArguments objectAtIndex:1] intValue];
    }
	NSUserDefaults *udf = [NSUserDefaults standardUserDefaults];
	NSString *savePath = [udf valueForKey:[NSString stringWithFormat:@"%@_savePath",urlstr]];
    NSFileManager *manager =  [NSFileManager defaultManager];
	if (savePath) {
        if (clearMode==1) {
            if ([manager fileExistsAtPath:savePath]) {
                [manager removeItemAtPath:savePath error:nil];
            }
        }
		//初始化Documents路径
		NSString *path = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
		//初始化临时文件路径
		NSString *folderPath = [path stringByAppendingPathComponent:@"temp"];
		NSString *tempPath = [folderPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.temp",[savePath lastPathComponent]]];
		PluginLog(@"temppath = %@",tempPath);
		
		if ([manager fileExistsAtPath:tempPath]) {
			[manager removeItemAtPath:tempPath error:nil];
		}
	}
	//删除信息
	[udf removeObjectForKey:[NSString stringWithFormat:@"%@_fileSize",urlstr]];
	[udf removeObjectForKey:[NSString stringWithFormat:@"%@_currentSize",urlstr]];
	[udf removeObjectForKey:[NSString stringWithFormat:@"%@_savePath",urlstr]];
	[udf removeObjectForKey:[NSString stringWithFormat:@"%@_lastTime",urlstr]];
}

-(void)cancelDownload:(NSMutableArray *)inArguments{
    NSString *urlstr = [inArguments objectAtIndex:0];
    int clearMode = 0;
    if ([inArguments count]==2) {
        clearMode = [[inArguments objectAtIndex:1] intValue];
    }
    NSUserDefaults *udf = [NSUserDefaults standardUserDefaults];
    NSString *savePath = [udf valueForKey:[NSString stringWithFormat:@"%@_savePath",urlstr]];
    NSFileManager *manager =  [NSFileManager defaultManager];
    if (savePath) {
        if (clearMode==1) {
            if ([manager fileExistsAtPath:savePath]) {
                [manager removeItemAtPath:savePath error:nil];
            }
        }
        //初始化Documents路径
        NSString *path = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
        //初始化临时文件路径
        NSString *folderPath = [path stringByAppendingPathComponent:@"temp"];
        NSString *tempPath = [folderPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.temp",[savePath lastPathComponent]]];
        PluginLog(@"temppath = %@",tempPath);
        
        if ([manager fileExistsAtPath:tempPath]) {
            [manager removeItemAtPath:tempPath error:nil];
        }
    }
    //删除信息
    [udf removeObjectForKey:[NSString stringWithFormat:@"%@_fileSize",urlstr]];
    [udf removeObjectForKey:[NSString stringWithFormat:@"%@_currentSize",urlstr]];
    [udf removeObjectForKey:[NSString stringWithFormat:@"%@_savePath",urlstr]];
    [udf removeObjectForKey:[NSString stringWithFormat:@"%@_lastTime",urlstr]];
}

-(void)download:(NSMutableArray *)inArguments{
	NSString *inOpId = [inArguments objectAtIndex:0];
	NSString *inDLUrl = [inArguments objectAtIndex:1];
	NSString *inSavePath = [inArguments objectAtIndex:2];
	NSString *inMode = [inArguments objectAtIndex:3];
	
	if (inOpId!=nil&& inDLUrl!=nil &&inSavePath!=nil) {
		NSString *DLSavePath = [EUtility getAbsPath:self.meBrwView path:inSavePath];
        //NSNumber *opId = [NSNumber numberWithInt:[inOpId intValue]];
		EUExDownload *dloadObj = [downObjDict objectForKey:inOpId];
		if (dloadObj) {
			if (dloadObj.downFlag == YES) {
				dloadObj.downFlag = NO;
				//[dloadObj downloadWithDlUrl:inDLUrl savePath:DLSavePath mode:inMode];
               // NSLog(@"----1--%@",self.headerDict);
                [dloadObj downloadWithDlUrl:inDLUrl savePath:DLSavePath mode:inMode headerDict:self.headerDict];
			}else {
				return;
			}
		}else{
			[self jsFailedWithOpId:0 errorCode:1070201 errorDes:UEX_ERROR_DESCRIBE_ARGS];
		}
	}else{
		[self jsFailedWithOpId:0 errorCode:1070201 errorDes:UEX_ERROR_DESCRIBE_ARGS];
	}
}

-(void)closeDownloader:(NSMutableArray *)inArguments{
	NSString *inOpId = [inArguments objectAtIndex:0];
	if (inOpId) {
		//关闭操作
		EUExDownload *dloadObj = [downObjDict objectForKey:inOpId];
		if (dloadObj) {
            [dloadObj closeDownload];
            dloadObj = nil;
			[downObjDict removeObjectForKey:inOpId];
		}else{
			[self jsFailedWithOpId:0 errorCode:1070301 errorDes:UEX_ERROR_DESCRIBE_ARGS];
		}
	}else {
		[self jsFailedWithOpId:0 errorCode:1070301 errorDes:UEX_ERROR_DESCRIBE_ARGS];
	}
}

-(void)uexSuccessWithOpId:(int)inOpId fileSize:(int)inFileSize percent:(int)inPercent status:(int)inStatus{
	NSString *jsStr = [NSString stringWithFormat:@"if(uexDownloaderMgr.onStatus!=null){uexDownloaderMgr.onStatus(%d,%d,%d,%d)}",inOpId,inFileSize,inPercent,inStatus];
	[meBrwView stringByEvaluatingJavaScriptFromString:jsStr];
}

-(void)clean{
	if (downObjDict) {
		for (EUExDownload* dObj in [downObjDict allValues]) {
			[dObj closeDownload];
            dObj = nil;
		}
		[downObjDict removeAllObjects];
	}
//    if (meBrwView) {
//        meBrwView = nil;
//    }
}

@end
