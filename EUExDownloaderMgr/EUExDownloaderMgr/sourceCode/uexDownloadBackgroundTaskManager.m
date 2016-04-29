/**
 *
 *	@file   	: uexDownloadBackgroundTaskManager.m  in EUExDownloaderMgr
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

#import "uexDownloadBackgroundTaskManager.h"
#import <libkern/OSAtomic.h>
NSString *const kUexDownloadBackgroundTaskManagerUserDefaultsKey = @"kUexDownloadBackgroundTaskManagerUserDefaults";
NSString *const kUexDownloadBackgroundTaskManagerUDIdentifierKey = @"kUexDownloadBackgroundTaskManagerUDIdentifier";

@interface uexDownloadBackgroundTaskManager ()
@property (nonatomic,strong) void (^backgroundSessionCompletionHandler)();
@property (nonatomic,strong) NSString *handledIdentifier;
@property (nonatomic,strong) NSMutableDictionary <NSString *,uexDownloadBackgroundTask *>* tasks;
@property (nonatomic,strong) NSMutableDictionary <NSString *,uexDownloadBackgroundTask *>* autoCreateTasks;
@property (nonatomic,assign) OSSpinLock lock;
@end


@implementation uexDownloadBackgroundTaskManager



+ (instancetype)sharedManager{
    static uexDownloadBackgroundTaskManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[self alloc]init];
    });
    return manager;
}


- (instancetype)init{
    self = [super init];
    if (self) {
        _tasks = [NSMutableDictionary dictionary];
        _autoCreateTasks = [NSMutableDictionary dictionary];
        _lock = OS_SPINLOCK_INIT;
        for (NSString *identifier in [self storedIdentifiers]) {
            [self.autoCreateTasks setValue:[uexDownloadBackgroundTask taskWithIdentifier:identifier resumeFromCache:YES] forKey:identifier];
        }
    }
    return self;
}

- (uexDownloadBackgroundTask *)taskWithShortIdentifier:(NSString *)shortIdentifier{
    if (!shortIdentifier || shortIdentifier.length == 0) {
        return nil;
    }
    return [self.tasks objectForKey:[kEUExDownloaderBackgroundTaskPrefix stringByAppendingString:shortIdentifier]];
}

- (BOOL)createTaskWithShortIdentifier:(NSString *)shortIdentifier resumeFromCache:(BOOL)isResumeFromCache{
    if (!shortIdentifier || shortIdentifier.length == 0) {
        return NO;
    }
    NSString *identifier = [kEUExDownloaderBackgroundTaskPrefix stringByAppendingString:shortIdentifier];
    if ([self.tasks objectForKey:identifier]) {
        return NO;
    }
    uexDownloadBackgroundTask *task = [self.autoCreateTasks objectForKey:identifier];
    if (task) {
        [self.autoCreateTasks removeObjectForKey:identifier];
        [self.tasks setObject:task forKey:identifier];
        return YES;
    }
    if (![self isIdentifierValid:identifier]) {
        return NO;
    }
    task = [uexDownloadBackgroundTask taskWithShortIdentifier:shortIdentifier resumeFromCache:isResumeFromCache];
    if (!task) {
        return NO;
    }
    [self.tasks setValue:task forKey:identifier];
    [self addIdentifierAndSave:identifier];
    return YES;
}

- (BOOL)setObserver:(EBrowserView *)webViewObserver forTaskWithShortIdentifier:(NSString *)shortIdentifier{
    uexDownloadBackgroundTask *task = [self taskWithShortIdentifier:shortIdentifier];
    if (!task) {
        return NO;
    }
    task.webViewObserver = webViewObserver;
    return YES;
}

- (BOOL)cancelTaskWithShortIdentifier:(NSString *)shortIdentifier option:(uexDownloaderCancelOption)option{
    uexDownloadBackgroundTask *task = [self taskWithShortIdentifier:shortIdentifier];
    if (!task) {
        return NO;
    }
    [task cancelDownloadWithOption:option];
    return YES;

}

- (BOOL)startTaskWithShortIdentifier:(NSString *)shortIdentifier{
    uexDownloadBackgroundTask *task = [self taskWithShortIdentifier:shortIdentifier];
    if (!task || ![task canDownload]) {
        return NO;
    }
    [task startDownload];
    return YES;
}





- (void)handleEventsForBackgroundURLSession:(NSString *)identifier completionHandler:(void (^)())completionHandler{
    if (![identifier hasPrefix:kEUExDownloaderBackgroundTaskPrefix]) {
        return;
    }
    UEXLog(@"handle background download task with id:%@",identifier);
    self.backgroundSessionCompletionHandler = completionHandler;
    self.handledIdentifier = identifier;
    
}



- (void)notifyDownloadTaskFinish:(uexDownloadBackgroundTask *)task{
    
    
    [self.tasks removeObjectForKey:task.identifier];
    [self.autoCreateTasks removeObjectForKey:task.identifier];
    [self removeIdentifierAndSave:task.identifier];
    
}


- (void)notifyBackgroundSessionTaskFinish:(uexDownloadBackgroundTask *)task{
    if ([task.identifier isEqual:self.handledIdentifier] && self.backgroundSessionCompletionHandler) {
        void (^backgroundSessionCompletionHandler)() = self.backgroundSessionCompletionHandler;
        self.backgroundSessionCompletionHandler = nil;
        self.handledIdentifier = nil;
        backgroundSessionCompletionHandler();
        //NSLog(@"nnnnn");
    }
}

#pragma mark - NSUserDefaults


- (BOOL)isIdentifierValid:(NSString *)identifier{
    return identifier && [identifier hasPrefix:kEUExDownloaderBackgroundTaskPrefix] && ![[self storedIdentifiers]containsObject:identifier];
}

- (NSArray<NSString *> *)storedIdentifiers{
    NSArray *ids = [[self userDefaultsDictinary]objectForKey:kUexDownloadBackgroundTaskManagerUDIdentifierKey];
    if (!ids) {
        ids = @[];
    }
    return ids;
}



- (void)addIdentifierAndSave:(NSString *)identifier{
    if(![self isIdentifierValid:identifier]){
        return;
    }
    [self editIdentifierArrayAndSave:^NSArray *(NSMutableArray *ids) {
        [ids addObject:identifier];
        return ids;
    }];
}

- (void)removeIdentifierAndSave:(NSString *)identifier{
    if(!identifier || ![[self storedIdentifiers] containsObject:identifier]){
        return;
    }
    [self editIdentifierArrayAndSave:^NSArray *(NSMutableArray *ids) {
        [ids removeObject:identifier];
        return ids;
    }];
}

typedef NSArray *(^uexDownloadMgrBGMgrEditIdentifierArrayBlock)(NSMutableArray * ids);

- (void)editIdentifierArrayAndSave:(uexDownloadMgrBGMgrEditIdentifierArrayBlock)block{
    if (!block) {
        return;
    }
    OSSpinLockLock(&_lock);
    NSMutableDictionary *UDDict = [self userDefaultsDictinary];
    NSMutableArray *ids = [[self storedIdentifiers] mutableCopy];
    NSArray *newIds = block(ids);
    [UDDict setObject:newIds forKey:kUexDownloadBackgroundTaskManagerUDIdentifierKey];
    [[NSUserDefaults standardUserDefaults]setObject:UDDict forKey:kUexDownloadBackgroundTaskManagerUserDefaultsKey];
    [[NSUserDefaults standardUserDefaults]synchronize];
    OSSpinLockUnlock(&_lock);
}

- (NSMutableDictionary *)userDefaultsDictinary{
    NSMutableDictionary *dict = [[[NSUserDefaults standardUserDefaults]objectForKey:kUexDownloadBackgroundTaskManagerUserDefaultsKey] mutableCopy];
    if (!dict) {
        dict = [NSMutableDictionary dictionary];
    }
    return dict;
}

@end
