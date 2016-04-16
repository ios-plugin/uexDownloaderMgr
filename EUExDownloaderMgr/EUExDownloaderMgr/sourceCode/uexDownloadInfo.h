/**
 *
 *	@file   	: uexDownloadInfo.h  in EUExDownloaderMgr
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

@interface uexDownloadInfo : NSObject<NSSecureCoding>
@property (nonatomic,strong)NSString *downloadPath;
@property (nonatomic,strong)NSString *savePath;
@property (nonatomic,strong)NSDate *lastOperationTime;
@property (nonatomic,assign)int64_t bytesWritten;
@property (nonatomic,assign)int64_t totalBytesWritten;

@property (nonatomic,strong)NSDictionary<NSString *,NSString *> *headers;
@property (nonatomic,strong)NSData *resumeCache;
@property (nonatomic,assign,getter=isResumable)BOOL resumable;




- (instancetype)initWithDoanloadPath:(NSString *)downloadPath savePath:(NSString *)savePath headers:(NSDictionary<NSString *,NSString *> *)headers NS_DESIGNATED_INITIALIZER ;

+ (instancetype)cachedInfoWithDownloadPath:(NSString *)downloadPath;


//下载的URL
- (NSURL *)downloadURL;
//下载的request
- (NSURLRequest *)downloadRequest;
//info的dictionary形式表述
- (NSDictionary *)infoDict;

//缓存info到本地
- (void)cacheForResuming;
//更新缓存data中的request的headers
- (void)updataRequestInResumeCache;

//清除指定下载地址对应的缓存info
+ (void)clearCachedInfoWithDownloadPath:(NSString *)downloadPath;
//清除所有缓存的info
+ (void)clearAllCachedInfo;




@end

@interface NSString (uexDownloaderMgr)
//获取MD5字符串
- (instancetype)uexDownloader_MD5;
@end

@interface NSDate (uexDownloaderMgr)
//NSDate的时间戳字符串
- (NSString *)uexDownloader_timestamp;

@end

