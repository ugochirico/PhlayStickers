
/*
 Copyright 2017 Google Inc.
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

@import UIKit;
@import AVFoundation;
@import GoogleMobileVision;


#import "CameraViewController.h"
#import "DrawingUtility.h"
#import "Sticker.h"

@interface CameraViewController ()<AVCaptureVideoDataOutputSampleBufferDelegate>
// UI elemen(nonatomic) (nonatomic) ts.

@end

@implementation CameraViewController


- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        self.videoDataOutputQueue = dispatch_queue_create("VideoDataOutputQueue",
                                                          DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _stickers = [NSMutableArray new];
    _stickers[0] = [[Sticker alloc] initWithName: @"moustache.png" withType: moustache];
    _stickers[1] = [[Sticker alloc] initWithName: @"carnival.png" withType: glasses];

    //    _stickers[2] = [[Sticker alloc] initWithName: @"mask.png" withType: mask];
    
    
    
//    [_stickers addObject: [[Sticker alloc] initWithName: @"moustache.png" withType: moustache]];
//    [_stickers addObject: [[Sticker alloc] initWithName: @"carnival.png" withType: glasses]];
//    [_stickers addObject: [[Sticker alloc] initWithName: @"mask.png" withType: mask]];
//
    // Set up default camera settings.
    self.session = [[AVCaptureSession alloc] init];
    self.session.sessionPreset = AVCaptureSessionPresetMedium;
    self.cameraSwitch.on = YES;
    [self updateCameraSelection];
    
    // Setup video processing pipeline.
    [self setupVideoProcessing];
    
    // Setup camera preview.
    [self setupCameraPreview];
    
    // Initialize the face detector.
    NSDictionary *options = @{
                              GMVDetectorFaceMinSize : @(0.3),
                              GMVDetectorFaceTrackingEnabled : @(YES),
                              GMVDetectorFaceLandmarkType : @(GMVDetectorFaceLandmarkAll)
                              };
    self.faceDetector = [GMVDetector detectorOfType:GMVDetectorTypeFace options:options];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    self.previewLayer.frame = self.view.layer.bounds;
    self.previewLayer.position = CGPointMake(CGRectGetMidX(self.previewLayer.frame),
                                             CGRectGetMidY(self.previewLayer.frame));
}

- (void)viewDidUnload {
    [self cleanupCaptureSession];
    [super viewDidUnload];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.session startRunning];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self.session stopRunning];
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
                                         duration:(NSTimeInterval)duration {
    // Camera rotation needs to be manually set when rotation changes.
    if (self.previewLayer) {
        if (toInterfaceOrientation == UIInterfaceOrientationPortrait) {
            self.previewLayer.connection.videoOrientation = AVCaptureVideoOrientationPortrait;
        } else if (toInterfaceOrientation == UIInterfaceOrientationPortraitUpsideDown) {
            self.previewLayer.connection.videoOrientation = AVCaptureVideoOrientationPortraitUpsideDown;
        } else if (toInterfaceOrientation == UIInterfaceOrientationLandscapeLeft) {
            self.previewLayer.connection.videoOrientation = AVCaptureVideoOrientationLandscapeLeft;
        } else if (toInterfaceOrientation == UIInterfaceOrientationLandscapeRight) {
            self.previewLayer.connection.videoOrientation = AVCaptureVideoOrientationLandscapeRight;
        }
    }
}


- (void)setLastKnownDeviceOrientation:(UIDeviceOrientation)orientation {
    if (orientation != UIDeviceOrientationUnknown &&
        orientation != UIDeviceOrientationFaceUp &&
        orientation != UIDeviceOrientationFaceDown) {
        _lastKnownDeviceOrientation = orientation;
    }
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection {
    
    UIImage *image = [GMVUtility sampleBufferTo32RGBA:sampleBuffer];
    AVCaptureDevicePosition devicePosition = self.cameraSwitch.isOn ? AVCaptureDevicePositionFront :
    AVCaptureDevicePositionBack;
    
    // Establish the image orientation.
    UIDeviceOrientation deviceOrientation = [[UIDevice currentDevice] orientation];
    GMVImageOrientation orientation = [GMVUtility
                                       imageOrientationFromOrientation:deviceOrientation
                                       withCaptureDevicePosition:devicePosition
                                       defaultDeviceOrientation:self.lastKnownDeviceOrientation];
    NSDictionary *options = @{
                              GMVDetectorImageOrientation : @(orientation)
                              };
    // Detect features using GMVDetector.
    _faces = [self.faceDetector featuresInImage:image options:options];
    NSLog(@"Detected %lu face(s).", (unsigned long)[_faces count]);
    
    // The video frames captured by the camera are a different size than the video preview.
    // Calculates the scale factors and offset to properly display the features.
    CMFormatDescriptionRef fdesc = CMSampleBufferGetFormatDescription(sampleBuffer);
    CGRect clap = CMVideoFormatDescriptionGetCleanAperture(fdesc, false);
    CGSize parentFrameSize = self.previewLayer.frame.size;
    
    // Assume AVLayerVideoGravityResizeAspect
    CGFloat cameraRatio = clap.size.height / clap.size.width;
    CGFloat viewRatio = parentFrameSize.width / parentFrameSize.height;
    CGFloat xScale = 1;
    CGFloat yScale = 1;
    CGRect videoBox = CGRectZero;
    if (viewRatio > cameraRatio) {
        videoBox.size.width = parentFrameSize.height * clap.size.width / clap.size.height;
        videoBox.size.height = parentFrameSize.height;
        videoBox.origin.x = (parentFrameSize.width - videoBox.size.width) / 2;
        videoBox.origin.y = (videoBox.size.height - parentFrameSize.height) / 2;
        
        xScale = videoBox.size.width / clap.size.width;
        yScale = videoBox.size.height / clap.size.height;
    } else {
        videoBox.size.width = parentFrameSize.width;
        videoBox.size.height = clap.size.width * (parentFrameSize.width / clap.size.height);
        videoBox.origin.x = (videoBox.size.width - parentFrameSize.width) / 2;
        videoBox.origin.y = (parentFrameSize.height - videoBox.size.height) / 2;
        
        xScale = videoBox.size.width / clap.size.height;
        yScale = videoBox.size.height / clap.size.width;
    }
    
    dispatch_sync(dispatch_get_main_queue(), ^{
        // Remove previously added feature views.
        for (UIView *featureView in self.overlayView.subviews) {
            [featureView removeFromSuperview];
        }
        
        // Display detected features in overlay.
        for (GMVFaceFeature *face in self.faces) {
//            CGRect faceRect = [DrawingUtility scaledRect:face.bounds
//                                                  xScale:xScale
//                                                  yScale:yScale
//                                                  offset:videoBox.origin];
//            [DrawingUtility addRectangle:faceRect
//                                  toView:self.overlayView
//                               withColor:[UIColor redColor]];
            
            // Mouth
//            if (face.hasBottomMouthPosition) {
//                CGPoint point = [DrawingUtility scaledPoint:face.bottomMouthPosition
//                                                     xScale:xScale
//                                                     yScale:yScale
//                                                     offset:videoBox.origin];
//                [DrawingUtility addCircleAtPoint:point
//                                          toView:self.overlayView
//                                       withColor:[UIColor greenColor]
//                                      withRadius:5];
//            }
            if (face.hasMouthPosition && [self->_stickerToPlace equalType:moustache]) {
                CGPoint point = [DrawingUtility scaledPoint:face.mouthPosition
                                                     xScale:xScale
                                                     yScale:yScale
                                                     offset:videoBox.origin];
//                [DrawingUtility addCircleAtPoint:point
//                                          toView:self.overlayView
//                                       withColor:[UIColor greenColor]
//                                      withRadius:10];
                UIImage *stickerImage = [UIImage imageNamed: self->_stickerToPlace.name];
                
                stickerImage = [DrawingUtility scaleImageWithImage:stickerImage scaledToWidth: self->_overlayView.frame.size.width / 2];
                
                UIImageView *stickerView = [[UIImageView alloc]initWithImage:stickerImage];
                
                
                stickerView.contentMode = UIViewContentModeScaleAspectFit;
                stickerView.layer.position = point;
                
                
                if ([self->_stickerToPlace equalType: moustache]){
                    [self->_overlayView addSubview:stickerView];
                }
            }
            
//            if (face.hasRightMouthPosition) {
//                CGPoint point = [DrawingUtility scaledPoint:face.rightMouthPosition
//                                                     xScale:xScale
//                                                     yScale:yScale
//                                                     offset:videoBox.origin];
//                [DrawingUtility addCircleAtPoint:point
//                                          toView:self.overlayView
//                                       withColor:[UIColor greenColor]
//                                      withRadius:5];
//            }
//            if (face.hasLeftMouthPosition) {
//                CGPoint point = [DrawingUtility scaledPoint:face.leftMouthPosition
//                                                     xScale:xScale
//                                                     yScale:yScale
//                                                     offset:videoBox.origin];
//                [DrawingUtility addCircleAtPoint:point
//                                          toView:self.overlayView
//                                       withColor:[UIColor greenColor]
//                                      withRadius:5];
//            }
            
//            // Nose
//            if (face.hasNoseBasePosition) {
//                CGPoint point = [DrawingUtility scaledPoint:face.noseBasePosition
//                                                     xScale:xScale
//                                                     yScale:yScale
//                                                     offset:videoBox.origin];
//                [DrawingUtility addCircleAtPoint:point
//                                          toView:self.overlayView
//                                       withColor:[UIColor darkGrayColor]
//                                      withRadius:10];
//            }
            
//            // Eyes
//            if (face.hasLeftEyePosition) {
//                CGPoint point = [DrawingUtility scaledPoint:face.leftEyePosition
//                                                     xScale:xScale
//                                                     yScale:yScale
//                                                     offset:videoBox.origin];
//                [DrawingUtility addCircleAtPoint:point
//                                          toView:self.overlayView
//                                       withColor:[UIColor blueColor]
//                                      withRadius:10];
//            }
//            if (face.hasRightEyePosition) {
//                CGPoint point = [DrawingUtility scaledPoint:face.rightEyePosition
//                                                     xScale:xScale
//                                                     yScale:yScale
//                                                     offset:videoBox.origin];
//                [DrawingUtility addCircleAtPoint:point
//                                          toView:self.overlayView
//                                       withColor:[UIColor blueColor]
//                                      withRadius:10];
//            }
            
//            // Ears
//            if (face.hasLeftEarPosition) {
//                CGPoint point = [DrawingUtility scaledPoint:face.leftEarPosition
//                                                     xScale:xScale
//                                                     yScale:yScale
//                                                     offset:videoBox.origin];
//                [DrawingUtility addCircleAtPoint:point
//                                          toView:self.overlayView
//                                       withColor:[UIColor purpleColor]
//                                      withRadius:10];
//            }
//            if (face.hasRightEarPosition) {
//                CGPoint point = [DrawingUtility scaledPoint:face.rightEarPosition
//                                                     xScale:xScale
//                                                     yScale:yScale
//                                                     offset:videoBox.origin];
//                [DrawingUtility addCircleAtPoint:point
//                                          toView:self.overlayView
//                                       withColor:[UIColor purpleColor]
//                                      withRadius:10];
//            }
//
//            // Cheeks
//            if (face.hasLeftCheekPosition) {
//                CGPoint point = [DrawingUtility scaledPoint:face.leftCheekPosition
//                                                     xScale:xScale
//                                                     yScale:yScale
//                                                     offset:videoBox.origin];
//                [DrawingUtility addCircleAtPoint:point
//                                          toView:self.overlayView
//                                       withColor:[UIColor magentaColor]
//                                      withRadius:10];
//            }
//            if (face.hasRightCheekPosition) {
//                CGPoint point = [DrawingUtility scaledPoint:face.rightCheekPosition
//                                                     xScale:xScale
//                                                     yScale:yScale
//                                                     offset:videoBox.origin];
//                [DrawingUtility addCircleAtPoint:point
//                                          toView:self.overlayView
//                                       withColor:[UIColor magentaColor]
//                                      withRadius:10];
//            }
//
//            // Tracking Id.
//            if (face.hasTrackingID) {
//                CGPoint point = [DrawingUtility scaledPoint:face.bounds.origin
//                                                     xScale:xScale
//                                                     yScale:yScale
//                                                     offset:videoBox.origin];
//                UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(point.x, point.y, 100, 20)];
//                label.text = [NSString stringWithFormat:@"id: %lu", (unsigned long)face.trackingID];
//                [self.overlayView addSubview:label];
//            }
        }
    });
}

#pragma mark - Camera setup

- (void)cleanupVideoProcessing {
    if (self.videoDataOutput) {
        [self.session removeOutput:self.videoDataOutput];
    }
    self.videoDataOutput = nil;
}

- (void)cleanupCaptureSession {
    [self.session stopRunning];
    [self cleanupVideoProcessing];
    self.session = nil;
    [self.previewLayer removeFromSuperlayer];
}

- (void)setupVideoProcessing {
    self.videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    NSDictionary *rgbOutputSettings = @{
                                        (__bridge NSString*)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA)
                                        };
    [self.videoDataOutput setVideoSettings:rgbOutputSettings];
    
    if (![self.session canAddOutput:self.videoDataOutput]) {
        [self cleanupVideoProcessing];
        NSLog(@"Failed to setup video output");
        return;
    }
    [self.videoDataOutput setAlwaysDiscardsLateVideoFrames:YES];
    [self.videoDataOutput setSampleBufferDelegate:self queue:self.videoDataOutputQueue];
    [self.session addOutput:self.videoDataOutput];
}

- (void)setupCameraPreview {
    self.previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.session];
    [self.previewLayer setBackgroundColor:[[UIColor whiteColor] CGColor]];
    [self.previewLayer setVideoGravity:AVLayerVideoGravityResizeAspect];
    CALayer *rootLayer = [self.placeHolder layer];
    [rootLayer setMasksToBounds:YES];
    [self.previewLayer setFrame:[rootLayer bounds]];
    [rootLayer addSublayer:self.previewLayer];
}

- (void)updateCameraSelection {
    [self.session beginConfiguration];
    
    // Remove old inputs
    NSArray *oldInputs = [self.session inputs];
    for (AVCaptureInput *oldInput in oldInputs) {
        [self.session removeInput:oldInput];
    }
    
    AVCaptureDevicePosition desiredPosition = self.cameraSwitch.isOn ?
    AVCaptureDevicePositionFront : AVCaptureDevicePositionBack;
    AVCaptureDeviceInput *input = [self cameraForPosition:desiredPosition];
    if (!input) {
        // Failed, restore old inputs
        for (AVCaptureInput *oldInput in oldInputs) {
            [self.session addInput:oldInput];
        }
    } else {
        // Succeeded, set input and update connection states
        [self.session addInput:input];
    }
    [self.session commitConfiguration];
}

- (AVCaptureDeviceInput *)cameraForPosition:(AVCaptureDevicePosition)desiredPosition {
    for (AVCaptureDevice *device in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo]) {
        if ([device position] == desiredPosition) {
            NSError *error = nil;
            AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device
                                                                                error:&error];
            if ([self.session canAddInput:input]) {
                return input;
            }
        }
    }
    return nil;
}

- (IBAction)cameraDeviceChanged:(id)sender {
    [self updateCameraSelection];
}

@end
