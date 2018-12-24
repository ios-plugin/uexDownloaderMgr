/**
 *
 *	@file   	: uexDownloader.h  in EUExDownloaderMgr
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


#import <Foundation/Foundation.h>
#import <AFNetworking/AFNetworking.h>
@class uexDownloader;
@protocol uexDownloaderDelegate <NSObject>


- (void)uexDownloader:(__kindof uexDownloader *)downloader taskDidCompletedWithError:(NSError *)error;
- (void)uexDownloader:(__kindof uexDownloader *)downloader sessionDidInvalidatedWithError:(NSError *)error;
- (void)uexDownloaderDidFinishHandlingBackgroundSessionEvents:(__kindof uexDownloader *)downloader;
@end



typedef NS_OPTIONS(NSInteger, uexDownloaderCancelOption){
    uexDownloaderCancelOptionDefault = 0,
    uexDownloaderCancelOptionClearCache = 1 << 0,
};
typedef NS_ENUM(NSInteger,uexDownloaderStatus){
    uexDownloaderStatusDownloading = 0,
    uexDownloaderStatusCompleted,
    uexDownloaderStatusFailed,
};



@class EUExDownloaderMgr,EBrowserView;
@interface uexDownloader : NSObject

@property (nonatomic,strong)NSString *identifier;
@property (nonatomic,strong)NSString *serverPath;
@property (nonatomic,strong)NSString *savePath;
@property (nonatomic,weak)EUExDownloaderMgr* euexObj;
@property (nonatomic,weak)id<AppCanWebViewEngineObject> observer;
@property (nonatomic,strong)NSDictionary<NSString *,NSString *> *headers;
@property (nonatomic,assign)BOOL isGlobalDownloader;
@property (nonatomic,assign,getter=isResumable)BOOL resumable;
@property (nonatomic,assign)uexDownloaderStatus status;
@property (nonatomic,strong)ACJSFunctionRef *cbFunc;




- (instancetype)initWithIdentifier:(NSString *)identifier euexObj:(EUExDownloaderMgr *)euexObj;
- (instancetype)initFromCacheWithServerPath:(NSString *)serverPath;
- (void)startDownload;
- (void)cancelDownloadWithOption:(uexDownloaderCancelOption)option;
- (void)cancelDownload;
- (NSDictionary *)info;
@end



