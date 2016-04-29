/**
 *
 *	@file   	: uexDownloadBackgroundTaskManager.h  in EUExDownloaderMgr
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
#import "uexDownloadBackgroundTask.h"
@class EBrowserView;

#define UEX_BG_TASK_MGR [uexDownloadBackgroundTaskManager sharedManager]

@interface uexDownloadBackgroundTaskManager : NSObject



+ (instancetype)sharedManager;

- (BOOL)createTaskWithShortIdentifier:(NSString *)shortIdentifier resumeFromCache:(BOOL)isResumeFromCache;
- (uexDownloadBackgroundTask *)taskWithShortIdentifier:(NSString *)shortIdentifier;
- (BOOL)setObserver:(EBrowserView *)webViewObserver forTaskWithShortIdentifier:(NSString *)shortIdentifier;
- (BOOL)startTaskWithShortIdentifier:(NSString *)shortIdentifier;
- (BOOL)cancelTaskWithShortIdentifier:(NSString *)shortIdentifier option:(uexDownloaderCancelOption)option;



#pragma mark - private
- (BOOL)isIdentifierValid:(NSString *)identifier;
- (void)notifyDownloadTaskFinish:(uexDownloadBackgroundTask *)task;
- (void)notifyBackgroundSessionTaskFinish:(uexDownloadBackgroundTask *)task;
- (void)handleEventsForBackgroundURLSession:(NSString *)identifier completionHandler:(void (^)())completionHandler;

@end
