/**
 *
 *	@file   	: uexDownloadBackgroundTask.h  in EUExDownloaderMgr
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


#import <Foundation/Foundation.h>
#import "uexDownloadBackgroundTaskInfo.h"
@class EBrowserView;
@interface uexDownloadBackgroundTask : NSObject




@property (nonatomic,strong)NSString *identifier;
@property (nonatomic,weak)EBrowserView *webViewObserver;
@property (nonatomic,strong,readonly) uexDownloadBackgroundTaskInfo *info;

extern NSString * kEUExDownloaderBackgroundTaskPrefix;

+ (instancetype)taskWithIdentifier:(NSString *)identifier resumeFromCache:(BOOL)isResumeFromCache;
+ (instancetype)taskWithShortIdentifier:(NSString *)shortIdentifier resumeFromCache:(BOOL)isResumeFromCache;



- (BOOL)canDownload;
- (void)startDownload;
- (void)cancelDownloadWithOption:(uexDownloaderCancelOption)option;




@end
