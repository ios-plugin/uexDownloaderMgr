/**
 *
 *	@file   	: uexDownloadBackgroundTaskInfo.h  in EUExDownloaderMgr
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
#import "uexDownloadInfo.h"
@interface uexDownloadBackgroundTaskInfo : uexDownloadInfo

@property (nonatomic,strong)NSString *identifier;
@property (nonatomic,strong,readonly)NSString * shortIdentifier;




- (instancetype)initWithIdentifier:(NSString *)identifier;

+ (instancetype)cachedInfoWithIdentifier:(NSString *)identifier;
+ (instancetype)cachedInfoWithShortIdentifier:(NSString *)identifier;
+ (void)clearCachedInfoWithIdentifier:(NSString *)identifier;
+ (void)clearCachedInfoWithShortIdentifier:(NSString *)identifier;

- (void)cacheForResumingInQueue:(dispatch_queue_t)queue completion:(void (^)(void))completion;
#pragma mark - Unavailable

- (instancetype)initWithDownloadPath:(NSString *)downloadPath savePath:(NSString *)savePath headers:(NSDictionary<NSString *,NSString *> *)headers NS_UNAVAILABLE;
+ (instancetype)cachedInfoWithDownloadPath:(NSString *)downloadPath NS_UNAVAILABLE;
+ (void)clearCachedInfoWithDownloadPath:(NSString *)downloadPath NS_UNAVAILABLE;

@end
