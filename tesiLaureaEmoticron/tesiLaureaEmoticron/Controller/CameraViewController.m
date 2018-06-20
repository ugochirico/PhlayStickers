
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

#import "CameraViewController.h"
#import "DrawingUtility.h"
#import "PreviewViewController.h"
#import "Sticker.h"
#import <ImageIO/CGImageProperties.h>
#include <math.h>

#define radians(angleInDegrees) ((angleInDegrees) * M_PI / 180.0)
#define degrees(angleInRadians) ((angleInRadians) * 180.0 / M_PI)

@interface CameraViewController ()<AVCaptureVideoDataOutputSampleBufferDelegate, UINavigationControllerDelegate,AVCaptureFileOutputRecordingDelegate, UIImagePickerControllerDelegate>
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
    _stickersToPlace = [NSMutableArray new];
    
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
    
    self.stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
    self.stillImageOutput.outputSettings = [[NSDictionary alloc] initWithObjectsAndKeys: AVVideoCodecJPEG, AVVideoCodecKey, nil];
    
    if([_session canAddOutput:_stillImageOutput]){
        [_session addOutput:_stillImageOutput];
    }
    
    
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
    
    AVCaptureConnection *connection = [_stillImageOutput connectionWithMediaType:AVMediaTypeVideo];
    
    if(connection.isEnabled){
        [_stillImageOutput captureStillImageAsynchronouslyFromConnection: connection completionHandler: ^(CMSampleBufferRef imageSampleBuffer, NSError *error) {
            
            NSDictionary *metadata = nil;
            
            // check if we got the image buffer
             if(imageSampleBuffer != NULL) {
                CFDictionaryRef exifAttachments = CMGetAttachment(imageSampleBuffer, kCGImagePropertyExifDictionary, NULL);
                if(exifAttachments) {
                    metadata = (__bridge NSDictionary*)exifAttachments;
                }
                
                NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageSampleBuffer];
                self->_tmpImage.image = [[UIImage alloc] initWithData:imageData].imageFlippedForRightToLeftLayoutDirection;
                
                 
                UIImage *renderedOverlay = [DrawingUtility renderViewAsImage:self->_overlayView].imageWithHorizontallyFlippedOrientation;
                
                
                self->_tmpImage.image = [DrawingUtility imageByCombiningImage:self->_tmpImage.image withImage:renderedOverlay].imageWithHorizontallyFlippedOrientation;
                
                 UIImageWriteToSavedPhotosAlbum(self->_tmpImage.image, self, nil, nil);
                
                [self loadPreviewViewController];
                
                
                //                [self performSegueWithIdentifier:@"previewSegue" sender:nil];
                
            }
        }];
    }
    
}


-(void)loadPreviewViewController{
    
    UIStoryboard * storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    
    PreviewViewController * vc = [storyboard instantiateViewControllerWithIdentifier:@"PreviewViewController"];
    //    UIImage * image = _takenPicture.image;
    
    vc.imageToView.image = _tmpImage.image;
    
    [self.navigationController presentViewController:vc animated:YES completion:(^{[vc.imageToView setImage:self->_tmpImage.image];})];
}


//- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender{
//
//    if([segue.identifier isEqualToString:@"previewSegue"]){
//
//        PreviewViewController *destination = [segue destinationViewController];
//        UIImage * image = _tmpImage.image;
//        //
//        destination.imageToView.image = _tmpImage.image;
//        [destination.imageToView setImage: _tmpImage.image];
//
//    }
//
//
//}






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
            
            for(Sticker *sticker in self->_stickersToPlace){
                
                NSMutableArray *positions = [self getPositionForStickerToPlace:sticker onFace:face];
                
                for(NSValue *pointValue in positions){
                    CGPoint point = pointValue.CGPointValue;
                    [self placeSticker:sticker inPosition:point onFace:face inView: _overlayView];
                }
            }
            
        }
    });
}




- (NSMutableArray *)getPositionForStickerToPlace: (Sticker *) stickerToPlace onFace: (GMVFaceFeature*) face{
    
    NSMutableArray *positions = [NSMutableArray <NSValue *> new];
    CGPoint newPosition;
    NSValue *newPositionValue;
    
    
    if(face.hasLeftEyePosition && face.hasRightEyePosition){
        CGPoint leftEye = face.leftEyePosition;
        CGPoint rightEye = face.rightEyePosition;
        
        self->_eyesDistance = sqrt(pow(rightEye.x - leftEye.x,2) + pow(rightEye.y - leftEye.y,2));
        NSLog(@"******DISTANZA OCCHI = %f*******", self->_eyesDistance);
    }
    
    
    
    
    if (face.hasMouthPosition && face.hasNoseBasePosition){
        
        //STICKER DI TIPO "BOCCA"
        if(stickerToPlace.type == mouth){
            
            
            newPosition = CGPointMake(face.mouthPosition.x + stickerToPlace.offsetX, (face.mouthPosition.y + face.noseBasePosition.y)/2 + stickerToPlace.offsetY);
            
            newPosition = [DrawingUtility scaledPoint:newPosition
                                               xScale:self->_xScale
                                               yScale:self->_yScale
                                               offset:self->_videoBox.origin];
            
            
            newPositionValue = [NSValue valueWithCGPoint:newPosition];
            [positions addObject:newPositionValue];
            
            
        }
        
    }
    
    if(face.hasLeftEyePosition && face.hasRightEyePosition){
        
        CGFloat midEyesPointX;
        CGFloat x1 = face.leftEyePosition.x, x2 = face.rightEyePosition.x, cosAngleY = cos(radians(face.headEulerAngleY));
        
        if(face.hasHeadEulerAngleY){
            
            if(face.headEulerAngleY < 0) //verso sinistra
                midEyesPointX = x1 + (x2-x1)*(cosAngleY)/2;//(x2 - x1)* (cosAngleY) / 2;
            else if(face.headEulerAngleY > 0) //verso destra
                midEyesPointX = x1 + (x2-x1)*(1 + (1-cosAngleY)) / 2;
        }else
            midEyesPointX = (face.leftEyePosition.x + face.rightEyePosition.x)/2;
        
        CGFloat midEyesPointY = (face.leftEyePosition.y + face.rightEyePosition.y) / 2;
        
        if(stickerToPlace.type == eye){
            
            
            newPosition = CGPointMake(midEyesPointX + stickerToPlace.offsetX, midEyesPointY + stickerToPlace.offsetY);
            
            newPosition = [DrawingUtility scaledPoint:newPosition xScale:self->_xScale yScale:self->_yScale offset:self->_videoBox.origin];
            
            newPositionValue = [NSValue valueWithCGPoint:newPosition];
            [positions addObject:newPositionValue];
            
            
        }else if(stickerToPlace.type == head){
            
            
            newPosition = CGPointMake(midEyesPointX + stickerToPlace.offsetX, midEyesPointY - self->_eyesDistance - stickerToPlace.offsetY);
            
            newPosition = [DrawingUtility scaledPoint:newPosition
                                               xScale:self->_xScale
                                               yScale:self->_yScale
                                               offset:self->_videoBox.origin];
            
            newPositionValue = [NSValue valueWithCGPoint:newPosition];
            [positions addObject:newPositionValue];
            
        }
        
        
    }
    
    
    if(face.hasNoseBasePosition){
        
        if(stickerToPlace.type == nose){
            
            newPosition = CGPointMake(face.noseBasePosition.x + stickerToPlace.offsetX, face.noseBasePosition.y + stickerToPlace.offsetY);
            
            newPosition = [DrawingUtility scaledPoint:newPosition
                                               xScale:self->_xScale
                                               yScale:self->_yScale
                                               offset:self->_videoBox.origin];
            
            newPositionValue = [NSValue valueWithCGPoint:newPosition];
            [positions addObject:newPositionValue];
        }
        
    }
    
    if(face.hasLeftCheekPosition && face.hasRightCheekPosition){
        
        if(stickerToPlace.type == cheek){
            
            CGPoint leftCheek = CGPointMake(face.leftCheekPosition.x + stickerToPlace.offsetX, face.leftCheekPosition.y + stickerToPlace.offsetY);
            CGPoint rightCheek = CGPointMake(face.rightCheekPosition.x + stickerToPlace.offsetX, face.rightCheekPosition.y + stickerToPlace.offsetY);
            
            leftCheek = [DrawingUtility scaledPoint:leftCheek xScale:self->_xScale yScale:self->_yScale offset:self->_videoBox.origin];
            newPosition = leftCheek;
            newPositionValue = [NSValue valueWithCGPoint:newPosition];
            [positions addObject:newPositionValue];
            
            rightCheek = [DrawingUtility scaledPoint:rightCheek xScale:self->_xScale yScale:self->_yScale offset:self->_videoBox.origin];
            newPosition = rightCheek;
            newPositionValue = [NSValue valueWithCGPoint:newPosition];
            [positions addObject:newPositionValue];
            
        }
        
        
    }
    
    
    
    return positions;
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
    if (self.previewLayer.connection.supportsVideoStabilization) {
        self.previewLayer.connection.preferredVideoStabilizationMode = AVCaptureVideoStabilizationModeAuto;
    }
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




-(void) placeSticker: (Sticker*) stickerToPlace inPosition: (CGPoint)position onFace: (GMVFaceFeature*) face inView: (UIView*)destinationView{
    
    UIImage *stickerImage = [UIImage imageNamed: stickerToPlace.name];
    
    
    CGFloat newWidth = (stickerImage.size.width / stickerImage.size.height) * stickerToPlace.scaleFactor *(face.bounds.size.height / 100);
    
    stickerImage = [DrawingUtility scaleImageWithImage:stickerImage scaledToWidth:newWidth];
    
    UIImageView *stickerView = [[UIImageView alloc]initWithImage:stickerImage];
    
    stickerView.layer.position = position;
    
    if(face.hasHeadEulerAngleZ){
        CGFloat angle = -radians(face.headEulerAngleZ);
        CGAffineTransform t = CGAffineTransformMakeRotation(angle);
        
        stickerView.contentMode = UIViewContentModeScaleAspectFill;
        stickerView.image = [DrawingUtility rotateAroundZAxis:stickerView.image byAngle: angle withTransform:t];
        NSLog(@"******ANGOLO Z = %f******",face.headEulerAngleZ);
    }
    
    if(face.hasHeadEulerAngleY){
                
        CGFloat angle = radians(face.headEulerAngleY);
        CGFloat perspective = -250.0; //This relates to the m34 perspective matrix.
        CATransform3D rotationAndPerspectiveTransform = CATransform3DIdentity;
        rotationAndPerspectiveTransform.m34 = 1.0 / perspective;
        rotationAndPerspectiveTransform = CATransform3DRotate(rotationAndPerspectiveTransform, angle, 0, 1, 0);
        
        stickerView.contentMode = UIViewContentModeScaleAspectFit;
        
        stickerView.layer.transform = rotationAndPerspectiveTransform;
       
//        stickerView.image = [DrawingUtility transformImage:stickerView.image with3DTransform:rotationAndPerspectiveTransform];
//        stickerView.image = [DrawingUtility rotateAroundZAxis:stickerView.image byAngle: angle withTransform:CATransform3DGetAffineTransform(rotationAndPerspectiveTransform)];
        NSLog(@"******ANGOLO Y = %f******",face.headEulerAngleY);
        
    }
    
    
    
    
    
    [destinationView addSubview:stickerView];
    
}




-(void) getStickers{
    
    NSString *path = [[NSBundle mainBundle] pathForResource:@"stickersDetails"
                                                     ofType:@"txt"];
    
    NSString *content = [NSString stringWithContentsOfFile:path
                                                  encoding:NSUTF8StringEncoding
                                                     error:NULL];
    
    _stickersDetails = (NSMutableArray <NSString *> *)[content componentsSeparatedByString:@"\n"];
    
    [_stickersDetails removeLastObject];
    
    
    NSMutableArray *stickerStrings = [[NSMutableArray alloc] initWithCapacity:_stickersDetails.count];
    
    
    for(int i=0; i<_stickersDetails.count;i++)
        [stickerStrings insertObject:[_stickersDetails[i] componentsSeparatedByString:@";"] atIndex: i];
    
    
    for(int i=0;i<stickerStrings.count;i++){
        _stickers[i] = [[Sticker alloc] initWithName: stickerStrings[i][0] withType: stickerStrings[i][3]];
        _stickers[i].offsetX = [stickerStrings[i][1] floatValue];
        _stickers[i].offsetY = [stickerStrings[i][2] floatValue];
        _stickers[i].scaleFactor = [stickerStrings[i][4] floatValue];
    }
}

@end
