//
//  EUExDownload.h
//  WebKitCorePlam
//
//  Created by AppCan on 11-10-31.
//  Copyright 2011 AppCan. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ASIHTTPRequest.h"
#import "ASINetworkQueue.h"
@class EUExDownloaderMgr;
 
@interface EUExDownload : NSObject <ASIHTTPRequestDelegate,ASIProgressDelegate>{
	EUExDownloaderMgr *euexObj;
	NSNumber *opID;
	BOOL downFlag;
	ASINetworkQueue *dQueue;
	long long fileTotalLength;
	long long appendFileSize;
}
 
@property(nonatomic,retain)ASINetworkQueue *dQueue;
@property(nonatomic,assign)EUExDownloaderMgr *euexObj;
@property(nonatomic,copy)NSNumber *opID;
@property(nonatomic) BOOL downFlag;

-(id)initWithUExObj:(EUExDownloaderMgr*)euexObj_;
//-(void)downloadWithDlUrl:(NSString *)inDLUrl savePath:(NSString *)DLSavePath mode:(NSString *)inMode;
-(void)downloadWithDlUrl:(NSString *)inDLUrl savePath:(NSString *)DLSavePath mode:(NSString *)inMode headerDict:(NSMutableDictionary *)headerDict;
-(BOOL)closeDownload;
@end
