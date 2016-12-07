//
//  XFConfirmViewController.m
//  XFCamera
//
//  Created by zhanglong on 16/10/13.
//  Copyright © 2016年 ZKXC. All rights reserved.
//

#import "XFConfirmViewController.h"

@interface XFConfirmViewController ()


@end

@implementation XFConfirmViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (IBAction)goback:(id)sender {
    [self.navigationController popViewControllerAnimated:YES];
}
- (IBAction)confirmButtonCLick:(id)sender {
    NSLog(@"确认");
}

@end
