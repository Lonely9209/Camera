//
//  ViewController.m
//  XFCamera
//  拍照（默认使用后置摄像头）
//  Created by zhanglong on 16/10/13.
//  Copyright © 2016年 ZKXC. All rights reserved.
//

#import "XFCameraViewController.h"
#import "XFConfirmViewController.h"
#import "XFCameraPemission.h"
#import "UIImage+DJResize.h"

#import <AVFoundation/AVFoundation.h>
#import <ImageIO/ImageIO.h>
#import <QuartzCore/QuartzCore.h>

#define adjustingFocus @"adjustingFocus"
#define CameraFlashModeKey @"flashMode"

@interface XFCameraViewController ()
< AVCaptureAudioDataOutputSampleBufferDelegate, UIImagePickerControllerDelegate, AVCaptureMetadataOutputObjectsDelegate>
@property (strong, nonatomic) AVCaptureSession           *session;       // 捕获会话
@property (nonatomic, strong) AVCaptureDeviceInput       *inputDevice;   // 输入设备
@property (nonatomic, strong) AVCaptureStillImageOutput  *captureOutput; // 输出设备
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;  // 取景器
@property (nonatomic) dispatch_queue_t sessionQueue;
@property (nonatomic, strong) UIImageView *focusImageView;
@property (nonatomic, assign) BOOL isManualFocus; //判断是否手动对焦
@property (weak, nonatomic) IBOutlet UIButton *flashButton;
@end

@implementation XFCameraViewController

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (![self.session isRunning]) {
        self.isManualFocus = false;
        [self startRunning];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if ([self.session isRunning]) {
        [self.session stopRunning];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [XFCameraPemission requestCameraPemissionWithResult:^(BOOL granted) {
        if (!granted) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                NSLog(@"尚未开启相机权限,您可以去设置->隐私->相机开启");
            });
            [self.navigationController popViewControllerAnimated:YES];
        }
    }];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationController.navigationBarHidden = YES;
    [self setupCamera];
}

/** 初始化相机 */
- (void)setupCamera {
    // 添加输入设备
    [self addVideoInputFrontCamera:NO];
    // 添加输出设备
    [self addCaptureStillImageOutput];
    // 对焦MVO
    [self setFocusObserver:YES];
    
    // 预览视图(取景器)
    _previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.session];
    [_previewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    CALayer *preLayer = [[self view] layer];
    [preLayer setMasksToBounds:YES];
    [_previewLayer setFrame:self.view.bounds];
    [preLayer insertSublayer:_previewLayer atIndex:0];
    [self startRunning];
    
    // 加入对焦框
    [self initfocusImageWithParent:self.view];
    
    AVCaptureConnection *videoConnection = [self findVideoConnection];
    if (!videoConnection) {
        NSLog(@"您的设备没有照相机");
        return;
    }
}

- (void)startRunning {
    dispatch_async(self.sessionQueue, ^{
        [self.session startRunning];
    });
    NSNumber *flashMode = [[NSUserDefaults standardUserDefaults] objectForKey:CameraFlashModeKey];
    [self setFlashMode:(flashMode ? [flashMode integerValue] : AVCaptureFlashModeAuto)];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    CGPoint point = [[touches anyObject] locationInView:self.view];
    [self focusInPoint:point];
}

/** 对焦的框 */
- (void)initfocusImageWithParent:(UIView *)view {
    if (self.focusImageView) {
        return;
    }
    self.focusImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"camera_touch_focus"]];
    CGRect frame = self.focusImageView.frame;
    frame.size = CGSizeMake(100, 100);
    self.focusImageView.frame = frame;
    self.focusImageView.alpha = 0;
    [view addSubview:self.focusImageView];
}

/** 点击对焦 */
- (void)focusInPoint:(CGPoint)devicePoint {
    if (CGRectContainsPoint(_previewLayer.bounds, devicePoint) == NO) {
        return;
    }
    self.isManualFocus = YES;
    [self focusImageAnimateWithCenterPoint:devicePoint];
    devicePoint = [self convertToPointOfInterestFromViewCoordinates:devicePoint];
    [self focusWithMode:AVCaptureFocusModeAutoFocus exposeWithMode:AVCaptureExposureModeContinuousAutoExposure atDevicePoint:devicePoint monitorSubjectAreaChange:YES];
}

- (void)focusImageAnimateWithCenterPoint:(CGPoint)point {
    [self.focusImageView setCenter:point];
    self.focusImageView.transform = CGAffineTransformMakeScale(2.0, 2.0);
    __weak typeof(self) weak = self;
    [UIView animateWithDuration:0.3f delay:0.f options:UIViewAnimationOptionAllowUserInteraction animations:^{
        weak.focusImageView.alpha = 1.f;
        weak.focusImageView.transform = CGAffineTransformMakeScale(1.0, 1.0);
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.5f delay:0.5f options:UIViewAnimationOptionAllowUserInteraction animations:^{
            weak.focusImageView.alpha = 0.f;
        } completion:^(BOOL finished) {
            //            weak.isManualFocus = NO;
        }];
    }];
}

- (void)focusWithMode:(AVCaptureFocusMode)focusMode exposeWithMode:(AVCaptureExposureMode)exposureMode atDevicePoint:(CGPoint)point monitorSubjectAreaChange:(BOOL)monitorSubjectAreaChange {
    dispatch_async(self.sessionQueue, ^{
        AVCaptureDevice *device = [self.inputDevice device];
        NSError *error = nil;
        if ([device lockForConfiguration:&error]) {
            if ([device isFocusPointOfInterestSupported] && [device isFocusModeSupported:focusMode]) {
                [device setFocusPointOfInterest:point];
                [device setFocusMode:focusMode];
            }
            if ([device isExposurePointOfInterestSupported] && [device isExposureModeSupported:exposureMode]) {
                [device setExposurePointOfInterest:point];
                [device setExposureMode:exposureMode];
            }
            [device setSubjectAreaChangeMonitoringEnabled:monitorSubjectAreaChange];
            [device unlockForConfiguration];
        }
    });
}

/**
 *  外部的point转换为camera需要的point(外部point/相机页面的frame)
 *
 *  @param viewCoordinates 外部的point
 *
 *  @return 相对位置的point
 */
- (CGPoint)convertToPointOfInterestFromViewCoordinates:(CGPoint)viewCoordinates {
    CGPoint pointOfInterest = CGPointMake(.5f, .5f);
    CGSize frameSize = _previewLayer.bounds.size;
    
    AVCaptureVideoPreviewLayer *videoPreviewLayer = self.previewLayer;
    
    if([[videoPreviewLayer videoGravity] isEqualToString:AVLayerVideoGravityResize]) {
        pointOfInterest = CGPointMake(viewCoordinates.y / frameSize.height, 1.f - (viewCoordinates.x / frameSize.width));
    } else {
        CGRect cleanAperture;
        for(AVCaptureInputPort *port in [[self.session.inputs lastObject]ports]) {
            if([port mediaType] == AVMediaTypeVideo) {
                cleanAperture = CMVideoFormatDescriptionGetCleanAperture([port formatDescription], YES);
                CGSize apertureSize = cleanAperture.size;
                CGPoint point = viewCoordinates;
                
                CGFloat apertureRatio = apertureSize.height / apertureSize.width;
                CGFloat viewRatio = frameSize.width / frameSize.height;
                CGFloat xc = .5f;
                CGFloat yc = .5f;
                
                if([[videoPreviewLayer videoGravity]isEqualToString:AVLayerVideoGravityResizeAspect]) {
                    if(viewRatio > apertureRatio) {
                        CGFloat y2 = frameSize.height;
                        CGFloat x2 = frameSize.height * apertureRatio;
                        CGFloat x1 = frameSize.width;
                        CGFloat blackBar = (x1 - x2) / 2;
                        if(point.x >= blackBar && point.x <= blackBar + x2) {
                            xc = point.y / y2;
                            yc = 1.f - ((point.x - blackBar) / x2);
                        }
                    } else {
                        CGFloat y2 = frameSize.width / apertureRatio;
                        CGFloat y1 = frameSize.height;
                        CGFloat x2 = frameSize.width;
                        CGFloat blackBar = (y1 - y2) / 2;
                        if(point.y >= blackBar && point.y <= blackBar + y2) {
                            xc = ((point.y - blackBar) / y2);
                            yc = 1.f - (point.x / x2);
                        }
                    }
                } else if([[videoPreviewLayer videoGravity]isEqualToString:AVLayerVideoGravityResizeAspectFill]) {
                    if(viewRatio > apertureRatio) {
                        CGFloat y2 = apertureSize.width * (frameSize.width / apertureSize.height);
                        xc = (point.y + ((y2 - frameSize.height) / 2.f)) / y2;
                        yc = (frameSize.width - point.x) / frameSize.width;
                    } else {
                        CGFloat x2 = apertureSize.height * (frameSize.height / apertureSize.width);
                        yc = 1.f - ((point.x + ((x2 - frameSize.width) / 2)) / x2);
                        xc = point.y / frameSize.height;
                    }
                    
                }
                
                pointOfInterest = CGPointMake(xc, yc);
                break;
            }
        }
    }
    
    return pointOfInterest;
}

/** 获取图片 */
- (void)getPhoto {
    AVCaptureConnection *videoConnection = [self findVideoConnection];
    [_captureOutput captureStillImageAsynchronouslyFromConnection:videoConnection completionHandler:^(CMSampleBufferRef imageSampleBuffer, NSError *error)
     {
         // 获取图片数据
         NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageSampleBuffer];
         UIImage *t_image = [[UIImage alloc] initWithData:imageData];
         // 执行跳转
         XFConfirmViewController *confirmVC = [[XFConfirmViewController alloc] init];
         [self.navigationController pushViewController:confirmVC animated:YES];
         [confirmVC view];
         confirmVC.imageView.image = t_image;
     }];
}

/** 查找摄像头连接设备 */
- (AVCaptureConnection *)findVideoConnection {
    AVCaptureConnection *videoConnection = nil;
    for (AVCaptureConnection *connection in _captureOutput.connections) {
        for (AVCaptureInputPort *port in [connection inputPorts]) {
            if ([[port mediaType] isEqual:AVMediaTypeVideo] ) {
                videoConnection = connection;
                break;
            }
        }
        if (videoConnection) {
            break;
        }
    }
    return videoConnection;
}

/** 拍照 */
- (IBAction)takePhotoButtonClick:(UIButton *)sender {
    if ([self.session isRunning]) {
        [self getPhoto];
    }
}

/** 返回 */
- (IBAction)goBackButtonCLick:(id)sender {
    NSLog(@"返回");
    [self.navigationController popViewControllerAnimated:YES];
}

/** 切换闪光灯模式 */
- (IBAction)flishLightButtonCLick:(UIButton *)sender {
    AVCaptureDevice *device = [self.inputDevice device];
    [device lockForConfiguration:nil];
    if ([device hasFlash]) {
        switch (device.flashMode) {
            case AVCaptureFlashModeOff:
                [self setFlashMode:AVCaptureFlashModeAuto];
                break;
            case AVCaptureFlashModeAuto:
                [self setFlashMode:AVCaptureFlashModeOn];
                break;
            default:
                [self setFlashMode:AVCaptureFlashModeOff];
                break;
        }
    } else {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"提示信息" message:@"您的设备没有闪光灯功能" delegate:nil cancelButtonTitle:@"ok" otherButtonTitles: nil];
        [alert show];
    }
    [device unlockForConfiguration];
}

- (void)setFlashMode:(AVCaptureFlashMode)flashMode {
    NSString *imgName;
    AVCaptureDevice *device = [self.inputDevice device];
    if ([device lockForConfiguration:nil]) {
        switch (flashMode) {
            case AVCaptureFlashModeOff:
                //                device.torchMode = AVCaptureTorchModeOff;
                device.flashMode = AVCaptureFlashModeOff;
                imgName = @"camera_flash_off";
                break;
            case AVCaptureFlashModeOn:
                //                device.torchMode = AVCaptureTorchModeOn;
                device.flashMode = AVCaptureFlashModeOn;
                imgName = @"camera_flash_on";
                break;
            default:
                //                device.torchMode = AVCaptureTorchModeAuto;
                device.flashMode = AVCaptureFlashModeAuto;
                imgName = @"camera_flash_auto";
                break;
        }
        [self.flashButton setImage:[UIImage imageNamed:imgName] forState:UIControlStateNormal];
        [device unlockForConfiguration];
    }
    [[NSUserDefaults standardUserDefaults] setObject:@(flashMode) forKey:CameraFlashModeKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}


/** 添加输入设备（前或后摄像头） */
- (void)addVideoInputFrontCamera:(BOOL)front {
    NSArray *devices = [AVCaptureDevice devices];
    AVCaptureDevice *frontCamera;
    AVCaptureDevice *backCamera;
    for (AVCaptureDevice *device in devices) {
        if ([device hasMediaType:AVMediaTypeVideo]) {
            if ([device position] == AVCaptureDevicePositionBack) {
                backCamera = device;
            } else if ([device position] == AVCaptureDevicePositionFront) {
                frontCamera = device;
            }
        }
    }
    NSError *error = nil;
    if (front) {
        AVCaptureDeviceInput *frontFacingCameraDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:frontCamera error:&error];
        if (!error) {
            if ([self.session canAddInput:frontFacingCameraDeviceInput]) {
                [self.session addInput:frontFacingCameraDeviceInput];
                self.inputDevice = frontFacingCameraDeviceInput;
            } else {
                NSLog(@"Couldn't add front facing video input");
                [self.navigationController popViewControllerAnimated:NO];
            }
        }
    } else {
        AVCaptureDeviceInput *backFacingCameraDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:backCamera error:&error];
        if (!error) {
            if ([self.session canAddInput:backFacingCameraDeviceInput]) {
                [self.session addInput:backFacingCameraDeviceInput];
                self.inputDevice = backFacingCameraDeviceInput;
            } else {
                NSLog(@"Couldn't add back facing video input");
                [self.navigationController popViewControllerAnimated:NO];
            }
        }
    }
    if (error) {
        NSLog(@"您的设备没有照相机");
        [self.navigationController popViewControllerAnimated:NO];
    }
}

/** 添加输出设备 */
- (void)addCaptureStillImageOutput {
    _captureOutput = [[AVCaptureStillImageOutput alloc] init];
    NSDictionary *outputSettings = [[NSDictionary alloc] initWithObjectsAndKeys:AVVideoCodecJPEG,AVVideoCodecKey,nil];
    _captureOutput.outputSettings = outputSettings;
    if ([self.session canAddOutput:_captureOutput]) {
        [_session addOutput:_captureOutput];
    }
}

#pragma -mark Observer
- (void)setFocusObserver:(BOOL)yes {
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if (device && [device isFocusPointOfInterestSupported]) {
        if (yes) {
            [device addObserver:self forKeyPath:adjustingFocus options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld context:nil];
        }else{
            [device removeObserver:self forKeyPath:adjustingFocus context:nil];
        }
    }else{
        NSLog(@"你的设备没有照相机");
    }
}

//监听对焦是否完成了
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:adjustingFocus]) {
        BOOL isAdjustingFocus = [[change objectForKey:NSKeyValueChangeNewKey] boolValue];
        if (isAdjustingFocus) {
            if (self.isManualFocus==NO) {
                [self focusImageAnimateWithCenterPoint:CGPointMake(self.previewLayer.bounds.size.width/2, self.previewLayer.bounds.size.height/2)];
            }
        }
    }
}

#pragma mark - lazy
- (AVCaptureSession *)session {
    if (_session == nil) {
        _session = [[AVCaptureSession alloc] init];
        [_session setSessionPreset:AVCaptureSessionPresetHigh];
    }
    return _session;
}

/** 创建一个队列，防止阻塞主线程 */
- (dispatch_queue_t)sessionQueue {
    if (!_sessionQueue) {
        _sessionQueue = dispatch_queue_create("session queue", DISPATCH_QUEUE_SERIAL);
    }
    return _sessionQueue;
}

- (void)dealloc {
    [self setFocusObserver:NO];
}

@end
