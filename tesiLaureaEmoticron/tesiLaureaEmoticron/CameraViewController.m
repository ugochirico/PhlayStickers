
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
#import <ImageIO/CGImageProperties.h>
#include <math.h>

#define radians(angleInDegrees) ((angleInDegrees) * M_PI / 180.0)
#define degrees(angleInRadians) ((angleInRadians) * 180.0 / M_PI)

@interface CameraViewController ()<AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureFileOutputRecordingDelegate>
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
    [self setWhiteBalanceMode:AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance];
    
    _stickers = [NSMutableArray new];
   
    _offsetsStrings = [self getOffsetStringsFromFile];
    [self getStickers];
    
    
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

- (void)setWhiteBalanceMode:(AVCaptureWhiteBalanceMode)whiteBalanceMode
{
    
    if ([self.captureDevice isWhiteBalanceModeSupported:whiteBalanceMode]) {
        NSError *error;
        if ([self.captureDevice lockForConfiguration:&error]) {
            [self.captureDevice setWhiteBalanceMode:whiteBalanceMode];
            [self.captureDevice unlockForConfiguration];
        }
    }
}


- (IBAction)takePhoto:(id)sender {
    
    
    //    AVCaptureStillImageOutput *stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
    //    NSDictionary *stillSettings = [[NSDictionary alloc] initWithObjectsAndKeys:AVVideoCodecTypeJPEG, AVVideoCodecKey, nil];
    //    [stillImageOutput setOutputSettings:stillSettings];
    //    [self.session addOutput: stillImageOutput];
    //
    //
    //
    //    AVCaptureConnection *videoConnection = nil;
    //
    //
    //    for (AVCaptureConnection *connection in stillImageOutput.connections)
    //    {
    //        for (AVCaptureInputPort *port in [connection inputPorts])
    //        {
    //            if ([[port mediaType] isEqual:AVMediaTypeVideo] )
    //            {
    //                videoConnection = connection;
    //                break;
    //            }
    //        }
    //        if (videoConnection)
    //        {
    //            break;
    //        }
    //    }
    //
    //    NSLog(@"about to request a capture from: %@", stillImageOutput);
    //    if(videoConnection.isEnabled){
    //        [stillImageOutput captureStillImageAsynchronouslyFromConnection:videoConnection completionHandler: ^(CMSampleBufferRef imageSampleBuffer, NSError *error)
    //         {
    //             CFDictionaryRef exifAttachments = CMGetAttachment( imageSampleBuffer, kCGImagePropertyExifDictionary, NULL);
    //             if (exifAttachments)
    //             {
    //                 // Do something with the attachments.
    //                 NSLog(@"attachements: %@", exifAttachments);
    //             } else {
    //                 NSLog(@"no attachments");
    //             }
    //
    //
    //             NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageSampleBuffer];
    //             UIImage *image = [[UIImage alloc] initWithData:imageData];
    
    UIImage *frameFromPreview = [GMVUtility sampleBufferTo32RGBA:_globalSampleBuffer];;
    UIImageView *wholeScreen = [[UIImageView alloc] initWithImage:frameFromPreview];
    [wholeScreen addSubview:_overlayView];
    // define the size and grab a UIImage from it
    UIGraphicsBeginImageContextWithOptions(wholeScreen.bounds.size, wholeScreen.opaque, 0.0);
    [wholeScreen.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *screengrab = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    UIImageWriteToSavedPhotosAlbum(screengrab, nil, nil, nil);
    
    
    
    
    
    
}




#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection {
    
    _globalSampleBuffer = sampleBuffer;
    UIImage *image = [GMVUtility sampleBufferTo32RGBA:_globalSampleBuffer];
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
    _oldFaces = _faces;
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
    _xScale = 1;
    _yScale = 1;
    _videoBox = CGRectZero;
    if (viewRatio > cameraRatio) {
        _videoBox.size.width = parentFrameSize.height * clap.size.width / clap.size.height;
        _videoBox.size.height = parentFrameSize.height;
        _videoBox.origin.x = (parentFrameSize.width - _videoBox.size.width) / 2;
        _videoBox.origin.y = (_videoBox.size.height - parentFrameSize.height) / 2;
        
        _xScale = _videoBox.size.width / clap.size.width;
        _yScale = _videoBox.size.height / clap.size.height;
    } else {
        _videoBox.size.width = parentFrameSize.width;
        _videoBox.size.height = clap.size.width * (parentFrameSize.width / clap.size.height);
        _videoBox.origin.x = (_videoBox.size.width - parentFrameSize.width) / 2;
        _videoBox.origin.y = (parentFrameSize.height - _videoBox.size.height) / 2;
        
        _xScale = _videoBox.size.width / clap.size.height;
        _yScale = _videoBox.size.height / clap.size.width;
    }
    
    
    
    dispatch_sync(dispatch_get_main_queue(), ^{
        // Remove previously added feature views.
        for (UIView *featureView in self.overlayView.subviews) {
            [featureView removeFromSuperview];
        }
        
        // Display detected features in overlay.
        for (GMVFaceFeature *face in self.faces) {
            
            
            if(face.hasLeftEyePosition && face.hasRightEyePosition){
                CGPoint leftEye = face.leftEyePosition;
                CGPoint rightEye = face.rightEyePosition;
                
                self->_eyesDistance = sqrt(pow(rightEye.x - leftEye.x,2) + pow(rightEye.y - leftEye.y,2));
                NSLog(@"******DISTANZA OCCHI = %f*******", self->_eyesDistance);
            }
            
            
            
            
            if (face.hasMouthPosition && face.hasNoseBasePosition){
                
                //STICKER DI TIPO "BAFFI"
                if(self->_stickerToPlace.type == mouth){
                    
                    
                    CGPoint mouthPosition = CGPointMake(face.mouthPosition.x + self->_stickerToPlace.offsetX, (face.mouthPosition.y + face.noseBasePosition.y)/2 + 10 + self->_stickerToPlace.offsetY);
                    
                    CGPoint point = [DrawingUtility scaledPoint:mouthPosition
                                                        xScale:self->_xScale
                                                        yScale:self->_yScale
                                                        offset:self->_videoBox.origin];
                    
                    [self placeSticker:point onFace:face];
                    
                }
                
            }
            
            if(face.hasLeftEyePosition && face.hasRightEyePosition){
                
                CGFloat midEyesPointX = (face.leftEyePosition.x + face.rightEyePosition.x) / 2;
                CGFloat midEyesPointY = (face.leftEyePosition.y + face.rightEyePosition.y) / 2;
                
                if(self->_stickerToPlace.type == eye){
                    
                    
                    
                    CGPoint midEyespoint = CGPointMake(midEyesPointX, midEyesPointY);
                    
                    midEyespoint = [DrawingUtility scaledPoint:midEyespoint xScale:self->_xScale yScale:self->_yScale offset:self->_videoBox.origin];
                    
                    
                    [self placeSticker:midEyespoint onFace:face];
                    
                    
                }else if(self->_stickerToPlace.type == head){
                    
                    self->_stickerToPlace.offsetY = -50;
                    
                    CGPoint forehead = CGPointMake(midEyesPointX,midEyesPointY - self->_eyesDistance + self->_stickerToPlace.offsetY);
                    
                    forehead = [DrawingUtility scaledPoint:forehead
                                xScale:self->_xScale
                                yScale:self->_yScale
                                offset:self->_videoBox.origin];
                    
                    [self placeSticker: forehead onFace:face];
                    
                }
                
                
            }
            
            
            
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




-(void) placeSticker: (CGPoint)position onFace: (GMVFaceFeature*) face{
    
    UIImage *stickerImage = [UIImage imageNamed: self->_stickerToPlace.name];
    CGFloat scaleMultiplier = 100.0;
    
    switch(_stickerToPlace.type){
            
        case mouth:
            scaleMultiplier = 60.0;
            break;
        case eye:
            scaleMultiplier = 40.0;
            break;
        case head:
            scaleMultiplier = 75.0;
            break;
            
        case undefined:
            break;
        case ear:
            
            break;
        case nose:
            
            break;
    }
    CGFloat newWidth = (stickerImage.size.width / stickerImage.size.height) * scaleMultiplier*(face.bounds.size.height / 100);
    //                    CGFloat newHeight = (stickerImage.size.height / stickerImage.size.width) * face.bounds.size.width;
    
    stickerImage = [DrawingUtility scaleImageWithImage:stickerImage scaledToWidth:newWidth];
    
    
    UIImageView *stickerView = [[UIImageView alloc]initWithImage:stickerImage];
    
    
    stickerView.contentMode = UIViewContentModeScaleAspectFit;
    stickerView.layer.position = position;
    
    CGPoint chinPivot = CGPointMake(face.noseBasePosition.x, face.noseBasePosition.y - face.bounds.size.height / 3);
    chinPivot = [DrawingUtility scaledPoint:chinPivot
                         xScale:self->_xScale
                         yScale:self->_yScale
                         offset:self->_videoBox.origin];
//    [DrawingUtility setAnchorPoint:chinPivot forView:stickerView];
    NSLog(@"****POSIZIONE PIVOT: X = %f, Y = %f\n",chinPivot.x, chinPivot.y);
    
    
    
    if(face.hasHeadEulerAngleY){
        
        
        CGFloat perspective = -1000.0; //This relates to the m34 perspective matrix.
        CATransform3D rotationAndPerspectiveTransform = CATransform3DIdentity;
        rotationAndPerspectiveTransform.m34 = 1.0 / perspective;
        rotationAndPerspectiveTransform = CATransform3DRotate(rotationAndPerspectiveTransform, face.headEulerAngleY / 180.0 * (CGFloat)M_PI, 0, 1, 0);
        
        stickerView.layer.transform = rotationAndPerspectiveTransform;
        NSLog(@"******ANGOLO Y = %f******",face.headEulerAngleY);
        
    }
    
    if(face.hasHeadEulerAngleZ){
        stickerView.layer.transform = CATransform3DRotate(stickerView.layer.transform, - face.headEulerAngleZ / 180.0 * (CGFloat)M_PI, 0, 0, 1);
        NSLog(@"******ANGOLO Z = %f******",face.headEulerAngleZ);
    }
    
    
    
    [self->_overlayView addSubview:stickerView];
}




- (NSMutableArray <NSString *> *)getOffsetStringsFromFile{
    
    NSMutableArray <NSString *> *offsetsStrings;
    NSString *path = [[NSBundle mainBundle] pathForResource:@"offsets"
                                                     ofType:@"txt"];
    
    NSString *content = [NSString stringWithContentsOfFile:path
                                                  encoding:NSUTF8StringEncoding
                                                     error:NULL];
    
    offsetsStrings = (NSMutableArray <NSString *> *)[content componentsSeparatedByString:@"\n"];
    
    [offsetsStrings removeLastObject];
    
    return offsetsStrings;
}

-(void) getStickers{
    
    NSMutableArray *stickerStrings = [[NSMutableArray alloc] initWithCapacity:_offsetsStrings.count];
    
    
    for(int i=0; i<_offsetsStrings.count;i++)
        [stickerStrings insertObject:[_offsetsStrings[i] componentsSeparatedByString:@";"] atIndex: i];
    
    
    for(int i=0;i<stickerStrings.count;i++){
        _stickers[i] = [[Sticker alloc] initWithName: stickerStrings[i][0] withType: stickerStrings[i][3]];
        _stickers[i].offsetX = [stickerStrings[i][1] floatValue];
        _stickers[i].offsetY = [stickerStrings[i][2] floatValue];
    }
}

@end
