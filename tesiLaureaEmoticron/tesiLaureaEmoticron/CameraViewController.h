
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
@import GoogleMobileVision;

// View controller demonstraing how to use the face detector with the AVFoundation video pipeline.
@interface CameraViewController : UIViewController

@property NSArray<NSString *> *stickers;
@property NSArray<GMVFaceFeature *> *faces;
@property NSString *stickerToPlace;

@property(nonatomic, weak) IBOutlet UIView *placeHolder;
@property(nonatomic, weak) IBOutlet UIView *overlayView;
@property(nonatomic, weak) IBOutlet UISwitch *cameraSwitch;

// Video objects.
@property(nonatomic, strong) AVCaptureSession *session;
@property(nonatomic, strong) AVCaptureVideoDataOutput *videoDataOutput;
@property(nonatomic, strong) dispatch_queue_t videoDataOutputQueue;
@property(nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;
@property(nonatomic, assign) UIDeviceOrientation lastKnownDeviceOrientation;

//Detector
@property(nonatomic, strong) GMVDetector *faceDetector;


@end

