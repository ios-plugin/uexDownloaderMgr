/**
 *
 *	@file   	: uexDownloadInfo.m  in EUExDownloaderMgr
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

#import "uexDownloadInfo.h"
#import <CommonCrypto/CommonCrypto.h>
@implementation uexDownloadInfo

- (instancetype)init{
    return [self initWithDoanloadPath:nil savePath:nil headers:nil];
}

- (instancetype)initWithDoanloadPath:(NSString *)downloadPath savePath:(NSString *)savePath headers:(NSDictionary<NSString *,NSString *> *)headers{
    self = [super init];
    if (self) {
        _downloadPath = downloadPath;
        _savePath = savePath;
        _headers = headers;
        
    }
    return self;
}

+ (instancetype)cachedInfoWithDownloadPath:(NSString *)downloadPath{
    return [NSKeyedUnarchiver unarchiveObjectWithFile:[self cachedInfoWithDownloadPath:downloadPath]];
}
- (NSMutableURLRequest *)mutableRequest{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[self downloadURL]];
    [self.headers enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSString * _Nonnull obj, BOOL * _Nonnull stop) {
        [request addValue:obj forHTTPHeaderField:key];
    }];
    return request;
}


- (NSURL *)downloadURL{
    NSURL *URL = [NSURL URLWithString:self.downloadPath];
    if (!URL) {
        URL = [NSURL URLWithString:[self.downloadPath stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    }
    return URL;
}

- (NSURLRequest *)downloadRequest{
    return [[self mutableRequest] copy];
}


- (NSDictionary *)infoDict{
    //@"fileSize",@"currentSize",@"savePath",@"lastTime"
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setValue:self.savePath forKey:@"savePath"];
    [dict setValue:@(self.bytesWritten) forKey:@"currentSize"];
    [dict setValue:@(self.totalBytesWritten) forKey:@"fileSize"];
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    [dict setValue:[dateFormatter stringFromDate:self.lastOperationTime] forKey:@"lastTime"];
    [dict setValue:@(self.resumable) forKey:@"resumable"];
    [dict setValue:self.headers forKey:@"header"];
    return [dict copy];
}

- (void)cacheForResuming{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *path = [self cacheSavePath];
        NSFileManager *fm = [NSFileManager defaultManager];
        if([fm fileExistsAtPath:path]){
            [fm removeItemAtPath:path error:nil];
        }
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self];
        [data writeToFile:path atomically:YES];
    });
    
}

- (void)updataRequestInResumeCache{
    if (!self.resumeCache || !self.resumable) {
        return;
    }
    NSString *error;
    NSPropertyListFormat format;
    NSMutableDictionary* resumeDict = [NSMutableDictionary dictionaryWithDictionary:[NSPropertyListSerialization propertyListFromData:self.resumeCache mutabilityOption:NSPropertyListImmutable format:&format errorDescription:&error]];
    if (error || !resumeDict) {
        return;
    }
    
    NSData *currentRequest = [resumeDict objectForKey:@"NSURLSessionResumeCurrentRequest"];
    NSURLRequest *oldRequest = [(NSURLRequest *)[NSKeyedUnarchiver unarchiveObjectWithData:currentRequest] copy];
    NSLog(@"Range : %@",[oldRequest valueForHTTPHeaderField:@"Range"]);
    
    NSMutableURLRequest *request = [self mutableRequest];
    [request addValue:[resumeDict objectForKey:@"NSURLSessionResumeEntityTag"] forHTTPHeaderField:@"If-Match"];
    [request addValue:[NSString stringWithFormat:@"bytes=%@-", [resumeDict objectForKey:@"NSURLSessionResumeBytesReceived"]] forHTTPHeaderField:@"Range"];

    NSData *newRequestData = [NSKeyedArchiver archivedDataWithRootObject:[request copy]];
    [resumeDict setValue:newRequestData forKey:@"NSURLSessionResumeCurrentRequest"];
    self.resumeCache = [NSPropertyListSerialization dataFromPropertyList:resumeDict format:NSPropertyListBinaryFormat_v1_0 errorDescription:&error];
}


+ (void)clearAllCachedInfo{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [[NSFileManager defaultManager]removeItemAtPath:[self infoCacheSaveFolderPath] error:nil];
    });
    
}

+ (void)clearCachedInfoWithDownloadPath:(NSString *)downloadPath{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [[NSFileManager defaultManager]removeItemAtPath:[self infoCacheSavePathWithDownloadPath:downloadPath] error:nil];
    });
}

#pragma mark - Info Cache Save Path
- (NSString *)cacheSavePath{
    return [self.class infoCacheSavePathWithDownloadPath:self.downloadPath];
}

+ (NSString *)infoCacheSavePathWithDownloadPath:(NSString *)downloadPath{
    return [[self infoCacheSaveFolderPath] stringByAppendingPathComponent:downloadPath.uexDownloader_MD5];
}

+ (NSString *)infoCacheSaveFolderPath{
    static NSString *folderPath = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        //cache目录
        NSString *cachePath = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject;
        folderPath = [cachePath stringByAppendingPathComponent:@"uexDownloaderMgr"];
        BOOL isFolder = NO;
        NSFileManager *fm = [NSFileManager defaultManager];
        if(![fm fileExistsAtPath:folderPath isDirectory:&isFolder] || !isFolder){
            //如果不存在,就新建一个
            [fm createDirectoryAtPath:folderPath withIntermediateDirectories:YES attributes:nil error:nil];
        }
    });
    return folderPath;
}

#pragma mark - NSSecureCoding

static NSString *const kDownloadPathCodingKey = @"downloadPath";
static NSString *const kSavePathCodingKey = @"savePath";
static NSString *const kLastOperationTimeCodingKey = @"lastOperationTime";
static NSString *const kBytesWrittenCodingKey = @"bytesWritten";
static NSString *const kTotalBytesWrittenCodingKey = @"totalBytesWritten";
static NSString *const kHeadersCodingKey = @"headers";
static NSString *const kResumeCacheCodingKey = @"resumeCache";
static NSString *const kResumableCodingKey = @"resumable";


+ (BOOL)supportsSecureCoding{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)aCoder{
    [aCoder encodeObject:self.downloadPath forKey:kDownloadPathCodingKey];
    [aCoder encodeObject:self.savePath forKey:kSavePathCodingKey];
    [aCoder encodeObject:self.lastOperationTime forKey:kLastOperationTimeCodingKey];
    [aCoder encodeObject:@(self.bytesWritten) forKey:kBytesWrittenCodingKey];
    [aCoder encodeObject:@(self.totalBytesWritten) forKey:kTotalBytesWrittenCodingKey];
    [aCoder encodeObject:self.resumeCache forKey:kResumeCacheCodingKey];
    [aCoder encodeObject:@(self.resumable) forKey:kResumableCodingKey];
}
- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [self initWithDoanloadPath:nil savePath:nil headers:nil];
    if (self) {
        _downloadPath = [aDecoder decodeObjectOfClass:[NSString class] forKey:kDownloadPathCodingKey];
        _savePath = [aDecoder decodeObjectOfClass:[NSString class] forKey:kSavePathCodingKey];
        _lastOperationTime = [aDecoder decodeObjectOfClass:[NSDate class] forKey:kLastOperationTimeCodingKey];
        _bytesWritten = [[aDecoder decodeObjectOfClass:[NSNumber class] forKey:kBytesWrittenCodingKey] longLongValue];
        _totalBytesWritten = [[aDecoder decodeObjectOfClass:[NSNumber class] forKey:kTotalBytesWrittenCodingKey] longLongValue];
        _resumeCache = [aDecoder decodeObjectOfClass:[NSData class] forKey:kResumeCacheCodingKey];
        _resumable = [[aDecoder decodeObjectOfClass:[NSNumber class] forKey:kResumableCodingKey] boolValue];
    }
    return self;
}
@end

@implementation NSString (uexDownloaderMgr)

- (instancetype)uexDownloader_MD5{
    const char *cStr = [self UTF8String];
    unsigned char result[16];
    CC_MD5(cStr, strlen(cStr), result); // This is the md5 call
    return [NSString stringWithFormat:
            @"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
            result[0], result[1], result[2], result[3],
            result[4], result[5], result[6], result[7],
            result[8], result[9], result[10], result[11],
            result[12], result[13], result[14], result[15]
            ];
}
@end

@implementation NSDate(uexDownloaderMgr)

- (NSString *)uexDownloader_timestamp{
    unsigned long long time = [self timeIntervalSince1970] * 1000;
    NSString * timestamp = [NSString stringWithFormat:@"%lld",time];
    return timestamp;
}

@end
