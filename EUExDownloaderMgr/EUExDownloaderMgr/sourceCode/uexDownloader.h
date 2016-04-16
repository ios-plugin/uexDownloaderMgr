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

typedef NS_OPTIONS(NSInteger, uexDownloaderCancelOption){
    uexDownloaderCancelOptionDefault = 0,
    uexDownloaderCancelOptionClearCache = 1 << 0,
};


@class EUExDownloaderMgr;
@class uexDownloadInfo;

@interface uexDownloader : NSObject

@property (nonatomic,strong)NSNumber *identifier;
@property (nonatomic,weak)EUExDownloaderMgr* euexObj;
@property (nonatomic,strong)NSDictionary<NSString *,NSString *> *headers;

- (instancetype)initWithIdentifier:(NSInteger)identifier euexObj:(EUExDownloaderMgr *)euexObj;
- (void)getPreparedWithDownloadInfo:(uexDownloadInfo *)info;
- (void)startDownload;


- (void)cancelDownloadWithOption:(uexDownloaderCancelOption)option;

- (void)clean;

@end
