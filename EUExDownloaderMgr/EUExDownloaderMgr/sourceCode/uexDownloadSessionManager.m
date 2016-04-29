/**
 *
 *	@file   	: uexDownloadSessionManager.m  in EUExDownloaderMgr
 *
 *	@author 	: CeriNo 
 * 
 *	@date   	: Created on 16/4/16.
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

#import "uexDownloadSessionManager.h"
#import "BUtility.h"
#import "WidgetOneDelegate.h"
#import "EXTScope.h"

@implementation uexDownloadSessionManager

+ (instancetype)defaultManager{
    static uexDownloadSessionManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[self alloc]initWithSessionConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
        [manager defaultInitializer];
    });
    return manager;
    
}




#pragma mark - Default Initializer
- (void)defaultInitializer{
    //HTTPS
    if(theApp.useCertificateControl){
        //setupSSLPolicy
        [self setSessionDidReceiveAuthenticationChallengeBlock:^NSURLSessionAuthChallengeDisposition(NSURLSession * _Nonnull session, NSURLAuthenticationChallenge * _Nonnull challenge, NSURLCredential *__autoreleasing  _Nullable * _Nullable credential) {
            return [uexDownloadHelper authChallengeDispositionWithSession:session challenge:challenge credential:credential];
        }];
    }else{
        AFSecurityPolicy *policy = [AFSecurityPolicy defaultPolicy];
        policy.allowInvalidCertificates = YES;
    }
}



@end
