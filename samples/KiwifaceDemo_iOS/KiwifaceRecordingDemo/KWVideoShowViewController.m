//
//  KWVideoShowViewController.m
//  KiwifaceRecordingDemo
//
//  Created by zhaoyichao on 2017/2/4.
//  Copyright © 2017年 kiwiFaceSDK. All rights reserved.
//

#import "KWVideoShowViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/ALAssetsLibrary.h>
#import <Foundation/Foundation.h>
#import "FaceTracker.h"
#import "KWSDK.h"

#import "Global.h"

@interface KWVideoShowViewController ()<GPUImageVideoCameraDelegate,KWSDKUIDelegate>
@property (nonatomic, strong) GPUImageStillCamera *videoCamera;
@property (nonatomic, strong) GPUImageMovieWriter *movieWriter;
@property (nonatomic, strong) GPUImageView *previewView;
@property (nonatomic, strong) NSURL *movieURL;
@property (nonatomic, strong) NSURL *exportURL;
@property (nonatomic, strong) CALayer *watermarkLayer;
@property (nonatomic, strong) GPUImageFilter *emptyFilter;

@property (nonatomic, strong) CIImage *outputImage;
@property (nonatomic, assign) size_t outputWidth;
@property (nonatomic, assign) size_t outputheight;

@property (nonatomic, strong) UILabel *labRecordState;
@property (nonatomic, strong) dispatch_queue_t sessionQueue;

@end

@implementation KWVideoShowViewController
{
    __block KWVideoShowViewController *__blockSelf;
    __weak KWVideoShowViewController *__weakSelf;
    dispatch_queue_t queue; //视频录制队列
    AVURLAsset *asset;
    
    UIButton *btnRecord;//临时申请的按钮控件指针 控制是否可用。
}


- (void)viewDidLoad {
    [super viewDidLoad];
    
    //设置视频录制文件导出路径
    [self commonInit];
    
    self.navigationController.navigationBarHidden = YES;
    
    [[UIApplication sharedApplication]setStatusBarHidden:YES withAnimation:UIStatusBarAnimationFade];
    
    
    self.kwSdkUI = [KWSDK_UI shareManagerUI];
    self.kwSdkUI.delegate = self;
    self.kwSdkUI.kwSdk = [KWSDK sharedManager];
    
    self.kwSdkUI.kwSdk.renderer = [[KWRenderer alloc]initWithModelPath:self.modelPath];

    self.kwSdkUI.kwSdk.cameraPositionBack  = NO;
    if([KWRenderer isSdkInitFailed]){
        //        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"错误提示" message:@"使用 license 文件生成激活码时失败，可能是授权文件过期。" delegate:nil cancelButtonTitle:@"好的" otherButtonTitles:nil, nil];
        //
        //        [alert show];
        return;
    }
    
    [self.kwSdkUI setViewDelegate:self];
    [self.kwSdkUI.kwSdk initSdk];

    self.videoCamera.horizontallyMirrorFrontFacingCamera = YES;
    self.videoCamera.horizontallyMirrorRearFacingCamera = NO;
    self.kwSdkUI.isClearOldUI = YES;
    
    /******** 录制功能 *********************/
    self.kwSdkUI.kwSdk.videoCamera = self.videoCamera;
    self.kwSdkUI.previewView = self.previewView;
    self.kwSdkUI.kwSdk.movieWriter = self.movieWriter;
    
    [self.kwSdkUI initSDKUI];
    
    [self.kwSdkUI setCloseVideoBtnHidden:NO];
    
    __blockSelf = self;
    __weakSelf = __blockSelf;
    
    __weak KWSDK_UI *__weakSdkUI = self.kwSdkUI;
    __weakSdkUI.toggleBtnBlock = ^()
    {
        /* 切换摄像头 */
        __weakSelf.kwSdkUI.kwSdk.cameraPositionBack  = !__weakSelf.kwSdkUI.kwSdk.cameraPositionBack;
        [__weakSelf.videoCamera rotateCamera];
    };
    
    self.kwSdkUI.closeVideoBtnBlock = ^(void)
    {
        [__weakSelf dismissViewControllerAnimated:YES completion:^{
            [[NSNotificationCenter defaultCenter] removeObserver:__weakSelf name:kReachabilityChangedNotification object:nil];
            if (__weakSelf.sessionQueue) {
                dispatch_sync(__weakSelf.sessionQueue, ^{
                });
            }
            
            __weakSelf.sessionQueue = nil;
            
            [__weakSelf.kwSdkUI popAllView];
            
            
            [__weakSdkUI.kwSdk.videoCamera stopCameraCapture];
            /* 内存释放 */
            [KWSDK_UI releaseManager];
            [KWSDK releaseManager];
            
            
        }];
    };
    //拍照
//    self.kwSdkUI.takePhotoBtnTapBlock = ^(UIButton *sender)
//    {
//        [__weakSelf takePhoto:sender];
//    };
    
//    __weakSdkUI.offPhoneBlock = ^(UIButton *sender)
//    {
//        //录制视频
//        [__weakSelf recordVideo:sender];
//        
//    };

    [self.view addSubview:self.labRecordState];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillResignActive:)
                                                 name:UIApplicationWillResignActiveNotification object:nil]; //监听是否触发home键挂起程序.
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive:)
                                                 name:UIApplicationDidBecomeActiveNotification object:nil]; //监听是否重新进入程序程序.

}

//拍照
- (void)takePhoto
{
    if (self.outputImage) {
        
        /* 录制demo 前置摄像头修正图片朝向*/
        UIImage *processedImage = [self image:[self convertBufferToImage] rotation:UIImageOrientationRight];
        UIImageWriteToSavedPhotosAlbum(processedImage, self, @selector(image:finishedSavingWithError:contextInfo:), nil);
    }
}

- (void)startRecording
{
    
    [self.labRecordState setText:@"正在录制"];
    [self.labRecordState setHidden:NO];
    if (self.kwSdkUI.kwSdk.currentStickerIndex >= 0) {
        [self.kwSdkUI.kwSdk.filters.lastObject addTarget:self.movieWriter];
    } else if (self.kwSdkUI.kwSdk.currentDistortionFilter) {
        [self.kwSdkUI.kwSdk.currentDistortionFilter addTarget:self.movieWriter];
    } else if (self.kwSdkUI.kwSdk.currentColorFilter) {
        [self.kwSdkUI.kwSdk.currentColorFilter addTarget:self.movieWriter];
        
    }
    
    self.videoCamera.audioEncodingTarget = self.movieWriter;
    
    [[NSFileManager defaultManager] removeItemAtURL:self.movieURL error:nil];
    
    [self.videoCamera startCameraCapture];
    
    [self.previewView setHidden:NO];
    
    [Global sharedManager].PIXCELBUFFER_ROTATE = KW_PIXELBUFFER_ROTATE_0;
    
    [self.kwSdkUI.kwSdk resetDistortionParams];
    
    [self.movieWriter startRecording];
}


- (void)endRecording
{
    [self.labRecordState setText:@"正在保存视频..."];
    [self.kwSdkUI setCloseBtnEnable:NO];
    if (self.kwSdkUI.kwSdk.currentStickerIndex >= 0) {
        [self.kwSdkUI.kwSdk.filters.lastObject removeTarget:self.movieWriter];
    }
    if (self.kwSdkUI.kwSdk.currentDistortionFilter) {
        [self.kwSdkUI.kwSdk.currentDistortionFilter removeTarget:self.movieWriter];
    }
    if (self.kwSdkUI.kwSdk.currentColorFilter) {
        [self.kwSdkUI.kwSdk.currentColorFilter removeTarget:self.movieWriter];
    }
    
    self.videoCamera.audioEncodingTarget = nil;
    
    [self.movieWriter finishRecordingWithCompletionHandler:^{
        [self addWatermarkToVideo];
    }];
}

-(void)didClickOffPhoneButton
{
    [self takePhoto];
}

-(void)didBeginLongPressOffPhoneButton
{
    [self startRecording];
}

-(void)didEndLongPressOffPhoneButton
{
    [self endRecording];
}


- (void)applicationWillResignActive:(NSNotification *)noti
{
    if (btnRecord.isSelected) {
        [self.movieWriter setPaused:YES];
        [self.videoCamera stopCameraCapture];
    }
    
}

- (void)applicationDidBecomeActive:(NSNotification *)noti
{
    if (btnRecord.isSelected) {
        [self.movieWriter setPaused:NO];
        [self.videoCamera startCameraCapture];
    }
}

#pragma mark < 录制视频 code

//加载拍照,视频录制摄像头工具类
-(GPUImageStillCamera *)videoCamera
{
    if (!_videoCamera) {
        _videoCamera = [[GPUImageStillCamera alloc] initWithSessionPreset:AVCaptureSessionPreset640x480
                                                           cameraPosition:AVCaptureDevicePositionFront];
        _videoCamera.frameRate = 25;
        _videoCamera.outputImageOrientation = UIDeviceOrientationPortrait;
        _videoCamera.horizontallyMirrorFrontFacingCamera = YES;
        _videoCamera.horizontallyMirrorRearFacingCamera = NO;
 
        [_videoCamera addAudioInputsAndOutputs];
        _videoCamera.delegate = self;
        

        [_videoCamera startCameraCapture];
        [self.previewView setHidden:NO];

        [_videoCamera addTarget:self.movieWriter];
        [_videoCamera addTarget:self.previewView];
        
    }
    return _videoCamera;
}

- (GPUImageView *)previewView
{
    if (!_previewView) {
        _previewView = [[GPUImageView alloc] initWithFrame:self.view.frame];
        _previewView.fillMode = kGPUImageFillModeStretch;
        _previewView.fillMode = kGPUImageFillModePreserveAspectRatioAndFill;
    }
    return _previewView;
}

- (GPUImageMovieWriter *)movieWriter
{
    if (!_movieWriter) {
        NSDictionary * videoSettings = @{ AVVideoCodecKey : AVVideoCodecH264,
                                          AVVideoWidthKey : @(480),
                                          AVVideoHeightKey : @(640),
                                          AVVideoScalingModeKey : AVVideoScalingModeResizeAspectFill};
        _movieWriter = [[GPUImageMovieWriter alloc] initWithMovieURL:self.movieURL size:CGSizeMake(480.0, 640.0) fileType:AVFileTypeQuickTimeMovie outputSettings:videoSettings];
    }
    return _movieWriter;
}

- (GPUImageFilter *)emptyFilter
{
    if (!_emptyFilter) {
        _emptyFilter = [[GPUImageFilter alloc]init];
    }
    return _emptyFilter;
}

//设置视频录制文件导出路径
- (void)commonInit
{
    NSString *fileName = [[NSUUID UUID] UUIDString];
    NSString *pathToMovie = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.MOV", fileName]];
    self.movieURL = [NSURL fileURLWithPath:pathToMovie];
    
    NSString *pathToExport = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%@_export.MOV", fileName]];
    self.exportURL = [NSURL fileURLWithPath:pathToExport];
}

- (void)addWatermarkToVideo
{
    asset = [AVURLAsset URLAssetWithURL:self.movieURL options:nil];
    
    /*****************    裁剪视频头0.1秒 解决第一帧偶现黑屏问题    ************************/
    // 创建可变的音视频组合
    AVMutableComposition *comosition = [AVMutableComposition composition];
    //分离视频的音轨和视频轨
    AVMutableCompositionTrack *videoTrack = [comosition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    AVMutableCompositionTrack *audioTrack = [comosition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
    
    //视频原时长
    CMTime duration = asset.duration;
    //要截取的时间
    CMTime clipTime = CMTimeMakeWithSeconds(0.1, duration.timescale);
    //截取后的视频时长
    CMTime clipDurationTime = CMTimeSubtract(duration, clipTime);
    //截取后的视频时间范围
    CMTimeRange videoTimeRange = CMTimeRangeMake(clipTime, clipDurationTime);
    
    //视频采集通道
    AVAssetTrack *videoAssetTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] firstObject];
    //把采集的轨道数据加入到视频轨道之中
    [videoTrack insertTimeRange:videoTimeRange ofTrack:videoAssetTrack atTime:kCMTimeZero error:nil];
    
    //音频采集通道
    AVAssetTrack *audioAssetTrack = [[asset tracksWithMediaType:AVMediaTypeAudio]firstObject];
    //把采集的轨道数据加入到音频轨道之中
    [audioTrack insertTimeRange:videoTimeRange ofTrack:audioAssetTrack atTime:kCMTimeZero error:nil];
    
    /************************************************************************************************/
    
    AVMutableVideoCompositionLayerInstruction *passThroughLayer = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:videoAssetTrack];
    
    AVMutableVideoCompositionInstruction *passThroughInstruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
    
    
    passThroughInstruction.timeRange = CMTimeRangeMake(kCMTimeZero, comosition.duration);
    //     passThroughInstruction.timeRange = videoTimeRange;
    
    passThroughInstruction.layerInstructions = @[ passThroughLayer ];
    
    AVMutableVideoComposition *videoComposition = [AVMutableVideoComposition videoComposition];
    videoComposition.frameDuration = CMTimeMake(1, self.videoCamera.frameRate);
    videoComposition.renderSize = videoAssetTrack.naturalSize;
    videoComposition.instructions = @[ passThroughInstruction ];
    
    
    // watermark
    CGSize renderSize = videoComposition.renderSize;
    CGFloat ratio = MIN(renderSize.width / CGRectGetWidth(self.previewView.frame), renderSize.height / CGRectGetHeight(self.previewView.frame));
    CGFloat watermarkWidth = ceil(renderSize.width / 5.);
    CGFloat watermarkHeight = ceil(watermarkWidth * CGRectGetHeight(self.watermarkLayer.frame) / CGRectGetWidth(self.watermarkLayer.frame));
    //
    CALayer *exportWatermarkLayer = [CALayer layer];
    exportWatermarkLayer.contents = self.watermarkLayer.contents;
    exportWatermarkLayer.frame = CGRectMake(renderSize.width - watermarkWidth - ceil(ratio * 16), ceil(ratio * 16), watermarkWidth, watermarkHeight);
    
    CALayer *parentLayer = [CALayer layer];
    CALayer *videoLayer = [CALayer layer];
    parentLayer.frame = CGRectMake(0, 0, renderSize.width, renderSize.height);
    videoLayer.frame = CGRectMake(0, 0, renderSize.width, renderSize.height);
    [parentLayer addSublayer:videoLayer];
    [parentLayer addSublayer:exportWatermarkLayer];
    videoComposition.animationTool = [AVVideoCompositionCoreAnimationTool videoCompositionCoreAnimationToolWithPostProcessingAsVideoLayer:videoLayer inLayer:parentLayer];
    
    // export
    AVAssetExportSession *exportSession = [[AVAssetExportSession alloc] initWithAsset:[comosition copy] presetName:AVAssetExportPresetHighestQuality];
    exportSession.videoComposition = videoComposition;
    exportSession.shouldOptimizeForNetworkUse = NO;
    exportSession.outputURL = self.exportURL;
    exportSession.outputFileType = AVFileTypeQuickTimeMovie;
    
    [[NSFileManager defaultManager] removeItemAtURL:self.exportURL error:nil];
    
    
    __weak AVAssetExportSession *weakExportSession = exportSession;
    [exportSession exportAsynchronouslyWithCompletionHandler:^(void){
        if (weakExportSession.status == AVAssetExportSessionStatusCompleted) {
            [[NSFileManager defaultManager] removeItemAtURL:self.movieURL error:nil];
            [self saveVideoToAssetsLibrary];
        } else {
            
            
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"Video Saving Failed"
                                                           delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alert show];
            
            [self.kwSdkUI setCloseBtnEnable:YES];
            [btnRecord setEnabled:YES];
            [self.labRecordState setHidden:YES];
            
            [self.videoCamera removeTarget:_movieWriter];
            _movieWriter = nil;
            [self.videoCamera addTarget:self.movieWriter];
        }
    }];
}

- (CALayer *)watermarkLayer
{
    if (!_watermarkLayer) {
        UIImage *watermark = [UIImage imageNamed:@"watermark"];
        _watermarkLayer = [CALayer layer];
        _watermarkLayer.contents = (id)watermark.CGImage;
        _watermarkLayer.frame = CGRectMake(0, 0, watermark.size.width, watermark.size.height);
    }
    
    return _watermarkLayer;
}

- (void)saveVideoToAssetsLibrary
{
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    
    if ([library videoAtPathIsCompatibleWithSavedPhotosAlbum:self.exportURL])
    {
        [library writeVideoAtPathToSavedPhotosAlbum:self.exportURL completionBlock:^(NSURL *assetURL, NSError *error)
         {
             //             self.recordButton.enabled = YES;
             [[NSFileManager defaultManager] removeItemAtURL:self.exportURL error:nil];
             
             dispatch_sync(dispatch_get_main_queue(), ^{
                 if (error) {
                     UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"Video Saving Failed"
                                                                    delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                     [alert show];
                     
                     
                 } else {
                     UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Video Saved" message:@"Saved To Photo Album"
                                                                    delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
                     [alert show];
                 }
                 [self.kwSdkUI setCloseBtnEnable:YES];
                 [btnRecord setEnabled:YES];
                 [self.labRecordState setHidden:YES];
                 [self.videoCamera removeTarget:self.movieWriter];
                 _movieWriter = nil;
                 [self.videoCamera addTarget:self.movieWriter];
             });
         }];
    } else {
        //        self.recordButton.enabled = YES;
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"Video Cannot Be Saved"
                                                       delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
        
        [self.kwSdkUI setCloseBtnEnable:YES];
        [btnRecord setEnabled:YES];
        [self.labRecordState setHidden:YES];
        
        [self.videoCamera removeTarget:_movieWriter];
        _movieWriter = nil;
        [self.videoCamera addTarget:self.movieWriter];
    }
}

- (void)recordVideo:(UIButton *)sender
{
    btnRecord = sender;
    if (sender.selected) {
        // recording
        sender.selected = NO;
        sender.enabled = NO;
        [self.labRecordState setText:@"正在保存视频..."];
        [self.kwSdkUI setCloseBtnEnable:NO];
        if (self.kwSdkUI.kwSdk.currentStickerIndex >= 0) {
            [self.kwSdkUI.kwSdk.filters.lastObject removeTarget:self.movieWriter];
        }
        if (self.kwSdkUI.kwSdk.currentDistortionFilter) {
            [self.kwSdkUI.kwSdk.currentDistortionFilter removeTarget:self.movieWriter];
        }
        if (self.kwSdkUI.kwSdk.currentColorFilter) {
            [self.kwSdkUI.kwSdk.currentColorFilter removeTarget:self.movieWriter];
        }
        
        self.videoCamera.audioEncodingTarget = nil;
        
        [self.movieWriter finishRecordingWithCompletionHandler:^{
            [self addWatermarkToVideo];
        }];
        
        
    } else {
        [self.labRecordState setText:@"正在录制"];
        [self.labRecordState setHidden:NO];
        if (self.kwSdkUI.kwSdk.currentStickerIndex >= 0) {
            [self.kwSdkUI.kwSdk.filters.lastObject addTarget:self.movieWriter];
        } else if (self.kwSdkUI.kwSdk.currentDistortionFilter) {
            [self.kwSdkUI.kwSdk.currentDistortionFilter addTarget:self.movieWriter];
        } else if (self.kwSdkUI.kwSdk.currentColorFilter) {
            [self.kwSdkUI.kwSdk.currentColorFilter addTarget:self.movieWriter];
        }
        
        self.videoCamera.audioEncodingTarget = self.movieWriter;

        [[NSFileManager defaultManager] removeItemAtURL:self.movieURL error:nil];
        
        sender.selected = YES;
        
        [self.videoCamera startCameraCapture];
        
        [self.previewView setHidden:NO];
        
        [Global sharedManager].PIXCELBUFFER_ROTATE = KW_PIXELBUFFER_ROTATE_0;
        
        [self.kwSdkUI.kwSdk resetDistortionParams];
        
        [self.movieWriter startRecording];
        
    }
}
#pragma mark > 录制视频 End


- (UILabel *)labRecordState
{
    if (!_labRecordState) {
        _labRecordState = [[UILabel alloc]initWithFrame:CGRectMake(0, 400, ScreenWidth_KW, 50)];
        [_labRecordState setHidden:YES];
        [_labRecordState setText:@"正在录制"];
        [_labRecordState setFont:[UIFont systemFontOfSize:25.f]];
        [_labRecordState setTextAlignment:NSTextAlignmentCenter];
        [_labRecordState setTextColor:[UIColor whiteColor]];
    }
    return _labRecordState;
}



//拍照
- (void)takePhoto:(UIButton *)sender
{
    [sender setEnabled:NO];
    if (self.outputImage) {
        
        /* 录制demo修正图片朝向*/
        UIImage *processedImage = [self image:[self convertBufferToImage] rotation:UIImageOrientationRight];
        UIImageWriteToSavedPhotosAlbum(processedImage, self, @selector(image:finishedSavingWithError:contextInfo:), nil);
        [sender setEnabled:YES];
    }
}

- (UIImage *)convertBufferToImage
{
    CIContext *temporaryContext = [CIContext contextWithOptions:nil];
    CGImageRef videoImage = [temporaryContext
                             createCGImage:self.outputImage
                             fromRect:CGRectMake(0, 0,
                                                 self.outputWidth,
                                                 self.outputheight)];
    
    UIImage *uiImage = [UIImage imageWithCGImage:videoImage];
    CGImageRelease(videoImage);
    return uiImage;
}


- (void)image:(UIImage *)image finishedSavingWithError:(NSError *)error contextInfo: (void *) contextInfo
{
    UIAlertController *alertView = [[UIAlertController alloc]init];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleCancel handler:nil];
    [alertView addAction:cancelAction];
    [alertView setTitle:@"提示"];
    
    if (error) {
        [alertView setMessage:[NSString stringWithFormat:@"拍照失败，原因：%@",error]];
        
        NSLog(@"save failed.");
    } else {
        [alertView setMessage:[NSString stringWithFormat:@"拍照成功！相片已保存到相册！"]];
        NSLog(@"save success.");
    }
    [self presentViewController:alertView animated:NO completion:nil];
}




- (void)willOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    
    UIDeviceOrientation iDeviceOrientation = [[UIDevice currentDevice] orientation];
    BOOL mirrored;

    mirrored = !self.kwSdkUI.kwSdk.cameraPositionBack && self.videoCamera.horizontallyMirrorFrontFacingCamera;

    cv_rotate_type cvMobileRotate;
    
    switch (iDeviceOrientation) {
        case UIDeviceOrientationPortrait:
            cvMobileRotate = CV_CLOCKWISE_ROTATE_90;
            [Global sharedManager].PIXCELBUFFER_ROTATE = KW_PIXELBUFFER_ROTATE_0;
            break;
            
        case UIDeviceOrientationLandscapeLeft:
            cvMobileRotate = mirrored ? CV_CLOCKWISE_ROTATE_180 : CV_CLOCKWISE_ROTATE_0;
            [Global sharedManager].PIXCELBUFFER_ROTATE = KW_PIXELBUFFER_ROTATE_270;
            break;
            
        case UIDeviceOrientationLandscapeRight:
            cvMobileRotate = mirrored ? CV_CLOCKWISE_ROTATE_0 : CV_CLOCKWISE_ROTATE_180;
            [Global sharedManager].PIXCELBUFFER_ROTATE = KW_PIXELBUFFER_ROTATE_90;
            break;
            
        case UIDeviceOrientationPortraitUpsideDown:
            cvMobileRotate = CV_CLOCKWISE_ROTATE_270;
            [Global sharedManager].PIXCELBUFFER_ROTATE = KW_PIXELBUFFER_ROTATE_180;
            break;
            
        default:
            cvMobileRotate = CV_CLOCKWISE_ROTATE_0;
            break;
    }
    
    
    [self.kwSdkUI.kwSdk.renderer processPixelBuffer:pixelBuffer withRotation:cvMobileRotate mirrored:mirrored];
    
    if (!self.kwSdkUI.kwSdk.renderer.trackResultState) {
        NSLog(@"没有捕捉到人脸！！！！！！！！！！！！！！！！！！！！！！！！！");
    }
    else
    {
        NSLog(@"捕捉到人脸！！！！！！！！！！！！！！！！！！！！！！！！！");
    }
    
    
    /*********** 如果有拍照功能则必须加上 ***********/
    self.outputImage =  [CIImage imageWithCVPixelBuffer:pixelBuffer];
    self.outputWidth = CVPixelBufferGetWidth(pixelBuffer);
    self.outputheight = CVPixelBufferGetHeight(pixelBuffer);
    /*********** End ***********/
}

- (UIImage *)image:(UIImage *)image rotation:(UIImageOrientation)orientation
{
    long double rotate = 0.0;
    CGRect rect;
    float translateX = 0;
    float translateY = 0;
    float scaleX = 1.0;
    float scaleY = 1.0;
    
    switch (orientation) {
        case UIImageOrientationLeft:
            rotate = M_PI_2;
            rect = CGRectMake(0, 0, image.size.height, image.size.width);
            translateX = 0;
            translateY = -rect.size.width;
            scaleY = rect.size.width/rect.size.height;
            scaleX = rect.size.height/rect.size.width;
            break;
        case UIImageOrientationRight:
            rotate = 3 * M_PI_2;
            rect = CGRectMake(0, 0, image.size.height, image.size.width);
            translateX = -rect.size.height;
            translateY = 0;
            scaleY = rect.size.width/rect.size.height;
            scaleX = rect.size.height/rect.size.width;
            break;
        case UIImageOrientationDown:
            rotate = M_PI;
            rect = CGRectMake(0, 0, image.size.width, image.size.height);
            translateX = -rect.size.width;
            translateY = -rect.size.height;
            break;
        default:
            rotate = 0.0;
            rect = CGRectMake(0, 0, image.size.width, image.size.height);
            translateX = 0;
            translateY = 0;
            break;
    }
    
    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    //做CTM变换
    CGContextTranslateCTM(context, 0.0, rect.size.height);
    CGContextScaleCTM(context, 1.0, -1.0);
    CGContextRotateCTM(context, rotate);
    CGContextTranslateCTM(context, translateX, translateY);
    
    CGContextScaleCTM(context, scaleX, scaleY);
    //绘制图片
    CGContextDrawImage(context, CGRectMake(0, 0, rect.size.width, rect.size.height), image.CGImage);
    
    UIImage *newPic = UIGraphicsGetImageFromCurrentImageContext();
    
    if (!self.kwSdkUI.kwSdk.cameraPositionBack) {
        newPic = [self convertMirrorImage:newPic];
    }
    
    
    return newPic;
}

- (UIImage *)convertMirrorImage:(UIImage *)image
{
    
    //Quartz重绘图片
    CGRect rect =  CGRectMake(0, 0, image.size.width , image.size.height);//创建矩形框
    //根据size大小创建一个基于位图的图形上下文
    UIGraphicsBeginImageContextWithOptions(rect.size, false, 2);
    CGContextRef currentContext =  UIGraphicsGetCurrentContext();//获取当前quartz 2d绘图环境
    CGContextClipToRect(currentContext, rect);//设置当前绘图环境到矩形框
    CGContextRotateCTM(currentContext, (CGFloat)M_PI); //旋转180度
    //平移， 这里是平移坐标系，跟平移图形是一个道理
    CGContextTranslateCTM(currentContext, -rect.size.width, -rect.size.height);
    CGContextDrawImage(currentContext, rect, image.CGImage);//绘图
    
    //翻转图片
    UIImage *drawImage =  UIGraphicsGetImageFromCurrentImageContext();//获得图片
    UIImage *flipImage =  [[UIImage alloc]initWithCGImage:drawImage.CGImage];
    
    
    return flipImage;
}

- (void)dealloc
{
    btnRecord = nil;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}


@end
