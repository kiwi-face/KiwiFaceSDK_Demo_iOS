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
#import "KWRenderManager.h"

#import "Global.h"

@interface KWVideoShowViewController () <GPUImageVideoCameraDelegate, KWUIManagerDelegate>

@property(nonatomic, strong) KWUIManager *UIManager;

@property(nonatomic, strong) KWRenderManager *renderManager;

@property(nonatomic, strong) GPUImageStillCamera *videoCamera;
@property(nonatomic, strong) GPUImageMovieWriter *movieWriter;
@property(nonatomic, strong) GPUImageView *previewView;
@property(nonatomic, strong) NSURL *movieURL;
@property(nonatomic, strong) NSURL *exportURL;
@property(nonatomic, strong) AVURLAsset *videoAsset;

@property(nonatomic, strong) CALayer *watermarkLayer;
@property(nonatomic, strong) GPUImageFilter *emptyFilter;

@property(nonatomic, strong) CIImage *outputImage;
@property(nonatomic, assign) size_t outputWidth;
@property(nonatomic, assign) size_t outputheight;

@property(nonatomic, strong) UILabel *labRecordState;
@property(nonatomic, assign) BOOL isRecording;


@end

@implementation KWVideoShowViewController

//加载拍照,视频录制摄像头工具类
- (GPUImageStillCamera *)videoCamera {
    if (!_videoCamera) {
        _videoCamera = [[GPUImageStillCamera alloc] initWithSessionPreset:AVCaptureSessionPreset640x480
                                                           cameraPosition:AVCaptureDevicePositionFront];
        _videoCamera.frameRate = 25;
        _videoCamera.outputImageOrientation = UIDeviceOrientationPortrait;
        _videoCamera.horizontallyMirrorFrontFacingCamera = YES;
        
        [_videoCamera addAudioInputsAndOutputs];
        
        _videoCamera.delegate = self;
        
        [_videoCamera startCameraCapture];
        
        [self.previewView setHidden:NO];
        
        [_videoCamera addTarget:self.movieWriter];
        
        [_videoCamera addTarget:self.previewView];
        
    }
    return _videoCamera;
}

- (GPUImageView *)previewView {
    if (!_previewView) {
        _previewView = [[GPUImageView alloc] initWithFrame:self.view.frame];
        _previewView.fillMode = kGPUImageFillModeStretch;
        _previewView.fillMode = kGPUImageFillModePreserveAspectRatioAndFill;
    }
    return _previewView;
}

- (GPUImageMovieWriter *)movieWriter {
    if (!_movieWriter) {
        NSDictionary *videoSettings = @{AVVideoCodecKey: AVVideoCodecH264,
                                        AVVideoWidthKey: @(480),
                                        AVVideoHeightKey: @(640),
                                        AVVideoScalingModeKey: AVVideoScalingModeResizeAspectFill};
        _movieWriter =
        [[GPUImageMovieWriter alloc] initWithMovieURL:self.movieURL size:CGSizeMake(480.0, 640.0) fileType:AVFileTypeQuickTimeMovie outputSettings:videoSettings];
    }
    return _movieWriter;
}

- (GPUImageFilter *)emptyFilter {
    if (!_emptyFilter) {
        _emptyFilter = [[GPUImageFilter alloc] init];
    }
    return _emptyFilter;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    //设置视频录制文件导出路径
    [self commonInit];
    
    self.navigationController.navigationBarHidden = YES;
    
    [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationFade];
    
    
    [self initCamera];
    
    [self initRenderManager];
    
    [self initKiwiFaceUI];
    
    [self.view addSubview:self.labRecordState];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillResignActive:)
                                                 name:UIApplicationWillResignActiveNotification object:nil]; //监听是否触发home键挂起程序.
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive:)
                                                 name:UIApplicationDidBecomeActiveNotification object:nil]; //监听是否重新进入程序程序.
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)applicationWillResignActive:(NSNotification *)noti {
    
    if (self.isRecording) {
        [self.movieWriter setPaused:YES];
        [self.videoCamera stopCameraCapture];
    }
    
}

- (void)applicationDidBecomeActive:(NSNotification *)noti {
    if (self.isRecording) {
        [self.movieWriter setPaused:NO];
        [self.videoCamera startCameraCapture];
    }
}

#pragma mark - 初始化相机
- (void)initCamera{
    
    self.videoCamera.delegate = self;
    
    self.isRecording = NO;
    
    [self.view addSubview:self.previewView];
}

#pragma mark - 初始化KiwiFaceSDK

- (void)initRenderManager {
    
    //1.创建 KWRenderManager对象,指定models文件路径 若不传则默认路径是KWResource.bundle/models
    self.renderManager = [[KWRenderManager alloc] initWithModelPath:self.modelPath isCameraPositionBack:NO];
    
    //2.KWSDK鉴权提示
    if ([KWRenderManager renderInitCode] != 0) {
        UIAlertView *alertView =
        [[UIAlertView alloc] initWithTitle:[NSString stringWithFormat:@"KiwiFaceSDK初始化失败,错误码: %d", [KWRenderManager renderInitCode]] message:@"可在FaceTracker.h中查看错误码" delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"确定", nil];
        
        [alertView show];
        
        return;
    }
    
    //3.加载贴纸滤镜
    [self.renderManager loadRender];
    
}

#pragma mark -初始化KiwiFace的演示UI
- (void)initKiwiFaceUI{
    //1.初始化UIManager
    self.UIManager = [[KWUIManager alloc] initWithRenderManager:self.renderManager delegate:self superView:self.view];
    //2.是否清除原UI
    self.UIManager.isClearOldUI = NO;
    
    //3.创建内置UI
    [self.UIManager createUI];
}


#pragma mark - 拍照相关

- (void)takePhoto {
    if (self.outputImage) {
        /* 录制demo 前置摄像头修正图片朝向*/
        UIImage *processedImage = [self image:[self convertBufferToImage] rotation:UIImageOrientationRight];
        UIImageWriteToSavedPhotosAlbum(processedImage, self, @selector(image:finishedSavingWithError:contextInfo:), nil);
    }
}

- (UIImage *)image:(UIImage *)image rotation:(UIImageOrientation)orientation {
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
            scaleY = rect.size.width / rect.size.height;
            scaleX = rect.size.height / rect.size.width;
            break;
        case UIImageOrientationRight:
            rotate = 3 * M_PI_2;
            rect = CGRectMake(0, 0, image.size.height, image.size.width);
            translateX = -rect.size.height;
            translateY = 0;
            scaleY = rect.size.width / rect.size.height;
            scaleX = rect.size.height / rect.size.width;
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
    
    if (self.videoCamera.cameraPosition == AVCaptureDevicePositionFront) {
        //前置摄像头要转换镜像图片
        newPic = [self convertMirrorImage:newPic];
    }
    
    return newPic;
}

- (UIImage *)convertMirrorImage:(UIImage *)image {
    //Quartz重绘图片
    CGRect rect = CGRectMake(0, 0, image.size.width, image.size.height);
    UIGraphicsBeginImageContextWithOptions(rect.size, false, 2);
    CGContextRef currentContext = UIGraphicsGetCurrentContext();
    CGContextClipToRect(currentContext, rect);
    CGContextRotateCTM(currentContext, (CGFloat) M_PI);
    CGContextTranslateCTM(currentContext, -rect.size.width, -rect.size.height);
    CGContextDrawImage(currentContext, rect, image.CGImage);
    
    //翻转图片
    UIImage *drawImage = UIGraphicsGetImageFromCurrentImageContext();
    UIImage *flipImage = [[UIImage alloc] initWithCGImage:drawImage.CGImage];
    
    return flipImage;
}

- (UIImage *)convertBufferToImage {
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

- (void)image:(UIImage *)image finishedSavingWithError:(NSError *)error contextInfo:(void *)contextInfo {
    UIAlertController *alertView = [[UIAlertController alloc] init];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleCancel handler:nil];
    [alertView addAction:cancelAction];
    [alertView setTitle:@"提示"];
    
    if (error) {
        [alertView setMessage:[NSString stringWithFormat:@"拍照失败，原因：%@", error]];
        
        NSLog(@"save failed.");
    } else {
        [alertView setMessage:[NSString stringWithFormat:@"拍照成功！相片已保存到相册！"]];
        NSLog(@"save success.");
    }
    [self presentViewController:alertView animated:NO completion:nil];
}

#pragma mark - 录制视频相关

- (UILabel *)labRecordState {
    if (!_labRecordState) {
        _labRecordState = [[UILabel alloc] initWithFrame:CGRectMake(0, 400, ScreenWidth_KW, 50)];
        [_labRecordState setHidden:YES];
        [_labRecordState setText:@"正在录制"];
        [_labRecordState setFont:[UIFont systemFontOfSize:25.f]];
        [_labRecordState setTextAlignment:NSTextAlignmentCenter];
        [_labRecordState setTextColor:[UIColor whiteColor]];
    }
    return _labRecordState;
}

- (CALayer *)watermarkLayer {
    if (!_watermarkLayer) {
        UIImage *watermark = [UIImage imageNamed:@"watermark"];
        _watermarkLayer = [CALayer layer];
        _watermarkLayer.contents = (id) watermark.CGImage;
        _watermarkLayer.frame = CGRectMake(0, 0, watermark.size.width, watermark.size.height);
    }
    return _watermarkLayer;
}

//设置视频录制文件导出路径
- (void)commonInit {
    NSString *fileName = [[NSUUID UUID] UUIDString];
    NSString *pathToMovie =
    [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.MOV", fileName]];
    self.movieURL = [NSURL fileURLWithPath:pathToMovie];
    
    NSString *pathToExport =
    [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%@_export.MOV", fileName]];
    self.exportURL = [NSURL fileURLWithPath:pathToExport];
}

- (void)startRecording {
    [self.labRecordState setText:@"正在录制"];
    self.isRecording = YES;
    [self.labRecordState setHidden:NO];
    
    if (self.renderManager.currentStickerIndex >= 0) {
        [self.renderManager.stickerRender addTarget:self.movieWriter];
    } else if (self.renderManager.currentDistortionFilter) {
        [self.renderManager.currentDistortionFilter addTarget:self.movieWriter];
    } else if (self.renderManager.currentGlobalFilter) {
        [self.renderManager.currentGlobalFilter addTarget:self.movieWriter];
    }
    
    self.videoCamera.audioEncodingTarget = self.movieWriter;
    
    [[NSFileManager defaultManager] removeItemAtURL:self.movieURL error:nil];
    
    [self.videoCamera startCameraCapture];
    
    [self.previewView setHidden:NO];
    
    [Global sharedManager].PIXCELBUFFER_ROTATE = KW_PIXELBUFFER_ROTATE_0;
    
    [self.renderManager resetDistortionParams];
    
    [self.movieWriter startRecording];
}

- (void)endRecording {
    [self.labRecordState setText:@"正在保存视频..."];
    [self.UIManager setCloseBtnEnable:NO];
    self.isRecording = NO;
    if (self.renderManager.currentStickerIndex >= 0) {
        [self.renderManager.stickerRender removeTarget:self.movieWriter];
    }
    if (self.renderManager.currentDistortionFilter) {
        [self.renderManager.currentDistortionFilter removeTarget:self.movieWriter];
    }
    if (self.renderManager.currentGlobalFilter) {
        [self.renderManager.currentGlobalFilter removeTarget:self.movieWriter];
    }
    
    self.videoCamera.audioEncodingTarget = nil;
    
    [self.movieWriter finishRecordingWithCompletionHandler:^{
        [self addWatermarkToVideo];
    }];
}

- (void)addWatermarkToVideo {
    self.videoAsset = [AVURLAsset URLAssetWithURL:self.movieURL options:nil];
    
    /*****************    裁剪视频头0.1秒 解决第一帧偶现黑屏问题    ************************/
    // 创建可变的音视频组合
    AVMutableComposition *comosition = [AVMutableComposition composition];
    //分离视频的音轨和视频轨
    AVMutableCompositionTrack *videoTrack =
    [comosition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    AVMutableCompositionTrack *audioTrack =
    [comosition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
    
    //视频原时长
    CMTime duration = self.videoAsset.duration;
    //要截取的时间
    CMTime clipTime = CMTimeMakeWithSeconds(0.1, duration.timescale);
    //截取后的视频时长
    CMTime clipDurationTime = CMTimeSubtract(duration, clipTime);
    //截取后的视频时间范围
    CMTimeRange videoTimeRange = CMTimeRangeMake(clipTime, clipDurationTime);
    
    //视频采集通道
    AVAssetTrack *videoAssetTrack = [[self.videoAsset tracksWithMediaType:AVMediaTypeVideo] firstObject];
    //把采集的轨道数据加入到视频轨道之中
    [videoTrack insertTimeRange:videoTimeRange ofTrack:videoAssetTrack atTime:kCMTimeZero error:nil];
    
    //音频采集通道
    AVAssetTrack *audioAssetTrack = [[self.videoAsset tracksWithMediaType:AVMediaTypeAudio] firstObject];
    //把采集的轨道数据加入到音频轨道之中
    [audioTrack insertTimeRange:videoTimeRange ofTrack:audioAssetTrack atTime:kCMTimeZero error:nil];
    
    /************************************************************************************************/
    
    AVMutableVideoCompositionLayerInstruction *passThroughLayer =
    [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:videoAssetTrack];
    
    AVMutableVideoCompositionInstruction
    *passThroughInstruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
    
    passThroughInstruction.timeRange = CMTimeRangeMake(kCMTimeZero, comosition.duration);
    //     passThroughInstruction.timeRange = videoTimeRange;
    
    passThroughInstruction.layerInstructions = @[passThroughLayer];
    
    AVMutableVideoComposition *videoComposition = [AVMutableVideoComposition videoComposition];
    videoComposition.frameDuration = CMTimeMake(1, self.videoCamera.frameRate);
    videoComposition.renderSize = videoAssetTrack.naturalSize;
    videoComposition.instructions = @[passThroughInstruction];
    
    
    // watermark
    CGSize renderSize = videoComposition.renderSize;
    CGFloat ratio =
    MIN(renderSize.width / CGRectGetWidth(self.previewView.frame), renderSize.height / CGRectGetHeight(self.previewView.frame));
    CGFloat watermarkWidth = ceil(renderSize.width / 5.);
    CGFloat watermarkHeight =
    ceil(watermarkWidth * CGRectGetHeight(self.watermarkLayer.frame) / CGRectGetWidth(self.watermarkLayer.frame));
    //
    CALayer *exportWatermarkLayer = [CALayer layer];
    exportWatermarkLayer.contents = self.watermarkLayer.contents;
    exportWatermarkLayer.frame =
    CGRectMake(renderSize.width - watermarkWidth - ceil(ratio * 16), ceil(ratio * 16), watermarkWidth, watermarkHeight);
    
    CALayer *parentLayer = [CALayer layer];
    CALayer *videoLayer = [CALayer layer];
    parentLayer.frame = CGRectMake(0, 0, renderSize.width, renderSize.height);
    videoLayer.frame = CGRectMake(0, 0, renderSize.width, renderSize.height);
    [parentLayer addSublayer:videoLayer];
    [parentLayer addSublayer:exportWatermarkLayer];
    videoComposition.animationTool =
    [AVVideoCompositionCoreAnimationTool videoCompositionCoreAnimationToolWithPostProcessingAsVideoLayer:videoLayer inLayer:parentLayer];
    
    // export
    AVAssetExportSession *exportSession =
    [[AVAssetExportSession alloc] initWithAsset:[comosition copy] presetName:AVAssetExportPresetHighestQuality];
    exportSession.videoComposition = videoComposition;
    exportSession.shouldOptimizeForNetworkUse = NO;
    exportSession.outputURL = self.exportURL;
    exportSession.outputFileType = AVFileTypeQuickTimeMovie;
    
    [[NSFileManager defaultManager] removeItemAtURL:self.exportURL error:nil];
    
    __weak AVAssetExportSession *weakExportSession = exportSession;
    [exportSession exportAsynchronouslyWithCompletionHandler:^(void) {
        if (weakExportSession.status == AVAssetExportSessionStatusCompleted) {
            [[NSFileManager defaultManager] removeItemAtURL:self.movieURL error:nil];
            [self saveVideoToAssetsLibrary];
        } else {
            
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"Video Saving Failed"
                                                           delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alert show];
            
            [self.UIManager setCloseBtnEnable:YES];
            [self.labRecordState setHidden:YES];
            
            [self.videoCamera removeTarget:_movieWriter];
            _movieWriter = nil;
            [self.videoCamera addTarget:self.movieWriter];
        }
    }];
}

- (void)saveVideoToAssetsLibrary {
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    
    if ([library videoAtPathIsCompatibleWithSavedPhotosAlbum:self.exportURL]) {
        [library writeVideoAtPathToSavedPhotosAlbum:self.exportURL completionBlock:^(NSURL *assetURL, NSError *error) {
            //             self.recordButton.enabled = YES;
            [[NSFileManager defaultManager] removeItemAtURL:self.exportURL error:nil];
            
            dispatch_sync(dispatch_get_main_queue(), ^{
                if (error) {
                    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"Video Saving Failed"
                                                                   delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                    [alert show];
                    
                } else {
                    UIAlertView
                    *alert = [[UIAlertView alloc] initWithTitle:@"Video Saved" message:@"Saved To Photo Album"
                                                       delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
                    [alert show];
                }
                [self.UIManager setCloseBtnEnable:YES];
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
        
        [self.UIManager setCloseBtnEnable:YES];
        [self.labRecordState setHidden:YES];
        
        [self.videoCamera removeTarget:_movieWriter];
        _movieWriter = nil;
        [self.videoCamera addTarget:self.movieWriter];
    }
}

#pragma mark - 获取视频帧

- (void)willOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    
    
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    [KWRenderManager processPixelBuffer:pixelBuffer];
    
    if (!self.renderManager.renderer.trackResultState) {
        //没有捕捉到人脸
    } else {
        //捕捉到人脸
    }
    
    /*********** 如果有拍照功能则加上***********/
    self.outputImage = [CIImage imageWithCVPixelBuffer:pixelBuffer];
    self.outputWidth = CVPixelBufferGetWidth(pixelBuffer);
    self.outputheight = CVPixelBufferGetHeight(pixelBuffer);
    /***********       End       ***********/
}

#pragma mark - KWUIManager Delegte

- (void)didClickOffPhoneButton {
    [self takePhoto];
}

- (void)didBeginLongPressOffPhoneButton {
    [self startRecording];
}

- (void)didEndLongPressOffPhoneButton {
    [self endRecording];
}

- (void)didClickSwitchCameraButton {
    /* 切换摄像头 */
    [self.videoCamera rotateCamera];
    
    //若出现镜像问题则加上下面代码
    self.renderManager.cameraPositionBack = !self.renderManager.cameraPositionBack;
}

- (void)didClickCloseVideoButton {
    
    [self dismissViewControllerAnimated:YES completion:^{
        [[NSNotificationCenter defaultCenter] removeObserver:self name:kReachabilityChangedNotification object:nil];
        
        [self.UIManager popAllView];
        
        [self.videoCamera stopCameraCapture];
        /* 内存释放 */
        [self.renderManager releaseManager];
        [self.UIManager releaseManager];
        
    }];
}


@end
