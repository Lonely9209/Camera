//
//  XFCameraPemission.m
//  ZHXF
//
//  Created by Lonely920 on 2018/4/27.
//  Copyright © 2018年 ZKXC. All rights reserved.
//

#import "XFCameraPemission.h"
#import <AVFoundation/AVFoundation.h>

@implementation XFCameraPemission

+ (BOOL)cameraPemission {
//    if (!([UIImagePickerController isCameraDeviceAvailable:UIImagePickerControllerCameraDeviceRear])) {
//        NSLog(@"设备暂不支持此功能");
//        return NO;
//    }
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if (status == AVAuthorizationStatusDenied || status == AVAuthorizationStatusRestricted) {
//        [UIAlertController alertWithTitle:nil message:@"尚未开启相机权限,您可以去设置->隐私->相机开启(修改权限后,应用将会重启),点击'确定'立即进入设置界面！" preferredStyle:UIAlertControllerStyleAlert actionTitles:@[@"取消", @"确定"] actionHandler:^(UIAlertAction *action, NSUInteger index) {
//            if (index == 1) {
//                //无权限 引导去开启
//                NSURL *url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
//                if ([[UIApplication sharedApplication] canOpenURL:url]) {
//                    [[UIApplication sharedApplication] openURL:url];
//                }
//            }
//        } completion:nil];
        return NO;
    }
    return YES;
}

+ (void)requestCameraPemissionWithResult:(void(^)( BOOL granted))completion
{
    if ([AVCaptureDevice respondsToSelector:@selector(authorizationStatusForMediaType:)])
    {
        AVAuthorizationStatus permission =
        [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
        
        switch (permission) {
            case AVAuthorizationStatusAuthorized:
                completion(YES);
                break;
            case AVAuthorizationStatusDenied:
            case AVAuthorizationStatusRestricted:
                completion(NO);
                break;
            case AVAuthorizationStatusNotDetermined:
            {
                [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo
                                         completionHandler:^(BOOL granted) {
                                             
                                             dispatch_async(dispatch_get_main_queue(), ^{
                                                 if (granted) {
                                                     completion(true);
                                                 } else {
                                                     completion(false);
                                                 }
                                             });
                                             
                                         }];
            }
                break;
                
        }
    }
    
    
}


@end
