//
//  XFCameraPemission.h
//  ZHXF
//
//  Created by Lonely920 on 2018/4/27.
//  Copyright © 2018年 ZKXC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface XFCameraPemission : NSObject

+ (BOOL)cameraPemission;

+ (void)requestCameraPemissionWithResult:(void(^)( BOOL granted))completion;

@end
