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
@class EUExDownloaderMgr_old;
 
@interface EUExDownload : NSObject <ASIHTTPRequestDelegate,ASIProgressDelegate>{
	__unsafe_unretained EUExDownloaderMgr_old *euexObj;
	NSNumber *opID;
	BOOL downFlag;
	ASINetworkQueue *dQueue;
	long long fileTotalLength;
	long long appendFileSize;
    //ASIHTTPRequest *asiRequest;
}

@property(nonatomic,retain)ASIHTTPRequest *asiRequest;
@property(nonatomic,retain)ASINetworkQueue *dQueue;
@property(nonatomic,assign)EUExDownloaderMgr_old *euexObj;
@property(nonatomic,copy)NSNumber *opID;
@property(nonatomic) BOOL downFlag;
@property(nonatomic,copy) NSString *verifyWithAppId;

-(id)initWithUExObj:(EUExDownloaderMgr_old*)euexObj_;
//-(void)downloadWithDlUrl:(NSString *)inDLUrl savePath:(NSString *)DLSavePath mode:(NSString *)inMode;
-(void)downloadWithDlUrl:(NSString *)inDLUrl savePath:(NSString *)DLSavePath mode:(NSString *)inMode headerDict:(NSMutableDictionary *)headerDict;
-(BOOL)closeDownload;
@end
