//
//  ViewController.h
//  XFCamera
//
//  Created by zhanglong on 16/10/13.
//  Copyright © 2016年 ZKXC. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef void(^SuccessBlock)(NSData *imageData);

typedef void(^CancleBlock)(void);

@interface XFCameraViewController : UIViewController

/** 需要时自己设置 */
+ (void)showCameraWithSuccess:(SuccessBlock)success cancle:(CancleBlock)cancle;

@end

