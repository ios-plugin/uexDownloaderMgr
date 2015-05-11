//
//  EUExDownloaderMgr.h
//  webKitCorePalm
//
//  Created by AppCan on 11-11-1.
//  Copyright 2011 AppCan. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "EUExBase.h"

#define UEX_DOWNLOAD_DOWNLOADING	0
#define UEX_DOWNLOAD_FINISH			1
#define UEX_DOWNLOAD_FAIL			2

@interface EUExDownloaderMgr:EUExBase{
	NSMutableDictionary *downObjDict;
}

@property(nonatomic,retain)NSMutableDictionary *downObjDict;
@property(nonatomic,retain) NSMutableDictionary *headerDict;
-(void)uexSuccessWithOpId:(int)inOpId fileSize:(int)inFileSize percent:(int)inPercent status:(int)inStatus;
@end
