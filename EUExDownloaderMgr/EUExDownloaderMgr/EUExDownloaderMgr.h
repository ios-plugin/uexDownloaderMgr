/**
 *
 *	@file   	: EUExDownloaderMgr.h  in EUExDownloaderMgr
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
#import "EUExBase.h"

#define UEX_FALSE @(NO)
#define UEX_TRUE @(YES)

#define UEX_ARGS_PACK(...) UEX_ARGS_PACK_(__VA_ARGS__)
#define UEX_ARGS_PACK_(...) (@[metamacro_foreach(UEX_OBJECT_OR_NSNULL,,__VA_ARGS__ )])
#define UEX_OBJECT_OR_NSNULL(index,obj) (obj) ? : NSNull.null,

#define UEX_STRING_VALUE_OR_NIL(obj) ([obj isKindOfClass:[NSString class]] ? obj : nil)

@interface EUExDownloaderMgr : EUExBase

- (void)callbackWithFunction:(NSString *)funcName arguments:(NSArray *)args;


@end
