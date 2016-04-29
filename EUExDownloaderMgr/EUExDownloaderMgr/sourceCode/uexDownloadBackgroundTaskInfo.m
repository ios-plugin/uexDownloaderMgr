/**
 *
 *	@file   	: uexDownloadBackgroundTaskInfo.m  in EUExDownloaderMgr
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

#import "uexDownloadBackgroundTaskInfo.h"
#import "uexDownloadBackgroundTask.h"
@implementation uexDownloadBackgroundTaskInfo


- (instancetype)initWithIdentifier:(NSString *)identifier{
    self = [super init];
    if (self) {
        _identifier = identifier;
    }
    return self;
}

+ (instancetype)cachedInfoWithShortIdentifier:(NSString *)identifier{
    return [self cachedInfoWithIdentifier:[kEUExDownloaderBackgroundTaskPrefix stringByAppendingString:identifier]];
}

+ (instancetype)cachedInfoWithIdentifier:(NSString *)identifier{
    if(!identifier){
        return nil;
    }
    return [NSKeyedUnarchiver unarchiveObjectWithFile:[self infoCacheSavePathWithIdentifier:identifier]];
}

- (NSString *)shortIdentifier{
    if (_identifier && [_identifier hasPrefix:kEUExDownloaderBackgroundTaskPrefix]) {
        return [self.identifier substringFromIndex:[kEUExDownloaderBackgroundTaskPrefix length]];
    }
    return nil;
}


- (NSDictionary *)dictDescription{
    NSMutableDictionary *dict = [[super dictDescription]mutableCopy];
    [dict setValue:self.shortIdentifier forKey:@"identifier"];
    return [dict copy];
}

+ (void)clearCachedInfoWithIdentifier:(NSString *)identifier{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [[NSFileManager defaultManager]removeItemAtPath:[self infoCacheSavePathWithIdentifier:identifier] error:nil];
    });
}

+ (void)clearCachedInfoWithShortIdentifier:(NSString *)identifier{
    return [self clearCachedInfoWithIdentifier:[kEUExDownloaderBackgroundTaskPrefix stringByAppendingString:identifier]];
}

- (NSURLRequest *)downloadRequest{
    __block NSMutableURLRequest *request = [[super downloadRequest]mutableCopy];
    [[uexDownloadHelper AppCanHTTPHeadersWithEUExObj:nil] enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSString * _Nonnull obj, BOOL * _Nonnull stop) {
        [request setValue:obj forHTTPHeaderField:key];
    }];
    return [request mutableCopy];
}



- (void)cacheForResumingInQueue:(dispatch_queue_t)queue completion:(void (^)(void))completion{
    dispatch_queue_t saveQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    if (queue) {
        saveQueue = queue;
    }
    dispatch_async(saveQueue, ^{
        self.lastOperationTime = [NSDate date];
        NSString *path = [self cacheSavePath];
        NSFileManager *fm = [NSFileManager defaultManager];
        if([fm fileExistsAtPath:path]){
            [fm removeItemAtPath:path error:nil];
        }
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self];
        [data writeToFile:path atomically:YES];
        if (completion){
            completion();
        }
    });
}

- (void)cacheForResuming{
    [self cacheForResumingInQueue:nil completion:nil];
}

#pragma mark - Info Cache Save Path

+ (NSString *)cacheFolderSubpath{
    return @"uexDownloaderMgr/backgroundTask";
}
- (NSString *)cacheSavePath{
    return [self.class infoCacheSavePathWithIdentifier:self.identifier];
}
+ (NSString *)infoCacheSaveFolderPath{
    static NSString *folderPath = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        //cache目录
        NSString *cachePath = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject;
        folderPath = [cachePath stringByAppendingPathComponent:[self cacheFolderSubpath]];
        BOOL isFolder = NO;
        NSFileManager *fm = [NSFileManager defaultManager];
        if(![fm fileExistsAtPath:folderPath isDirectory:&isFolder] || !isFolder){
            //如果不存在,就新建一个
            [fm createDirectoryAtPath:folderPath withIntermediateDirectories:YES attributes:nil error:nil];
        }
    });
    return folderPath;
}
+ (NSString *)infoCacheSavePathWithIdentifier:(NSString *)identifier{
    return [[self infoCacheSaveFolderPath] stringByAppendingPathComponent:identifier.uexDownloader_MD5];
}

#pragma mark - NSSecureCoding

static NSString *const kIdentifierCodingKey = @"identifier";

+ (BOOL)supportsSecureCoding{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)aCoder{
    [super encodeWithCoder:aCoder];
    [aCoder encodeObject:self.identifier forKey:kIdentifierCodingKey];
    
}
- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        _identifier = [aDecoder decodeObjectOfClass:[NSString class] forKey:kIdentifierCodingKey];
    }
    return self;
}
@end
