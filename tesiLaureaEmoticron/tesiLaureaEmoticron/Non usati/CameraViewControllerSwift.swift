
import AVFoundation
import GoogleMobileVision

class CameraViewControllerSwift: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    // UI elements.
    
    @IBOutlet weak var placeHolder: UIView!
    @IBOutlet weak var overlayView: UIView!
    @IBOutlet weak var cameraSwitch: UISwitch!
    // Video objects.
    var session: AVCaptureSession?
    var videoDataOutput: AVCaptureVideoDataOutput?
    var videoDataOutputQueue: DispatchQueue?
    var previewLayer: AVCaptureVideoPreviewLayer?
    var lastKnownDeviceOrientation: UIDeviceOrientation?
    
    // Detector.
    var faceDetector: GMVDetector?
    
    let stickers: [UIImage] = [#imageLiteral(resourceName: "moustache")]
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Set up default camera settings.
        videoDataOutputQueue = DispatchQueue(label: "VideoDataOutputQueue")
        self.session = AVCaptureSession()
        self.session?.sessionPreset = .medium
        self.cameraSwitch.isOn = true
        self.updateCameraSelection()
        // Setup video processing pipeline.
        self.setupVideoProcessing()
        // Setup camera preview.
        self.setupCameraPreview()
        // Initialize the face detector.
        let options = [GMVDetectorFaceMinSize: 0.3, GMVDetectorFaceTrackingEnabled: true, GMVDetectorFaceLandmarkType: GMVDetectorFaceLandmark.all.rawValue] as [AnyHashable: Any]
        self.faceDetector = GMVDetector(ofType: GMVDetectorTypeFace, options: options)
    }
    
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.previewLayer?.frame = view.layer.bounds
        self.previewLayer?.position = CGPoint(x: (self.previewLayer?.frame.midX)!, y: (self.previewLayer?.frame.midY)!)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        self.cleanupCaptureSession()
    }
    
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.session?.startRunning()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.session?.stopRunning()
    }
    
    
    override func willAnimateRotation(to toInterfaceOrientation: UIInterfaceOrientation, duration: TimeInterval) {
        // Camera rotation needs to be manually set when rotation changes.
        if (self.previewLayer != nil) {
            if toInterfaceOrientation == .portrait {
                self.previewLayer?.connection?.videoOrientation = .portrait
            } else if toInterfaceOrientation == .portraitUpsideDown {
                self.previewLayer?.connection?.videoOrientation = .portraitUpsideDown
            } else if toInterfaceOrientation == .landscapeLeft {
                self.previewLayer?.connection?.videoOrientation = .landscapeLeft
            } else if toInterfaceOrientation == .landscapeRight {
                self.previewLayer?.connection?.videoOrientation = .landscapeRight
            }
        }
    }
    
    func scaledRect(_ rect: CGRect, xscale: CGFloat, yscale: CGFloat, offset: CGPoint) -> CGRect {
        var resultRect = CGRect(x: rect.origin.x * xscale, y: rect.origin.y * yscale, width: rect.size.width * xscale, height: rect.size.height * yscale)
        resultRect = resultRect.offsetBy(dx: offset.x, dy: offset.y)
        return resultRect
    }
    
    func scaledPoint(_ point: CGPoint, xscale: CGFloat, yscale: CGFloat, offset: CGPoint) -> CGPoint {
        let resultPoint = CGPoint(x: point.x * xscale + offset.x, y: point.y * yscale + offset.y)
        return resultPoint
    }
    
    func setLastKnownDeviceOrientation(_ orientation: UIDeviceOrientation) {
        if orientation != .unknown && orientation != .faceUp && orientation != .faceDown {
            lastKnownDeviceOrientation = orientation
        }
    }
    
    
    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
    
    
    func cleanupVideoProcessing() {
        if (self.videoDataOutput != nil) {
            self.session?.removeOutput(self.videoDataOutput!)
        }
        self.videoDataOutput = nil
    }
    
    func cleanupCaptureSession() {
        self.session?.stopRunning()
        self.cleanupVideoProcessing()
        self.session = nil
        self.previewLayer?.removeFromSuperlayer()
    }
    
    
    
    func updateCameraSelection() {
        
        self.session?.beginConfiguration()
        // Remove old inputs
        let oldInputs = self.session?.inputs
        
        for oldInput in oldInputs!
        {
            self.session?.removeInput(oldInput)
        }
        
        let desiredPosition: AVCaptureDevice.Position = self.cameraSwitch.isOn ? .front : .back
        let input: AVCaptureDeviceInput? = self.cameraForPosition(desiredPosition: desiredPosition)
        if input == nil {
            // Failed, restore old inputs
            for oldInput in oldInputs! {
                self.session?.addInput(oldInput)
            }
        } else {
            // Succeeded, set input and update connection states
            self.session?.addInput(input!)
            
        }
        self.session?.commitConfiguration()
    }
    
    func setupVideoProcessing() {
        self.videoDataOutput = AVCaptureVideoDataOutput()
        let rgbOutputSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        self.videoDataOutput?.videoSettings = rgbOutputSettings
        if !self.session!.canAddOutput(self.videoDataOutput!) {
            self.cleanupVideoProcessing()
            print("Failed to setup video output")
            return
        }
        self.videoDataOutput?.alwaysDiscardsLateVideoFrames = true
        self.videoDataOutput?.setSampleBufferDelegate(self, queue: self.videoDataOutputQueue)
        self.session?.addOutput(self.videoDataOutput!)
    }
    
    func setupCameraPreview() {
        self.previewLayer = AVCaptureVideoPreviewLayer(session: self.session!)
        self.previewLayer?.backgroundColor = UIColor.white.cgColor
        self.previewLayer?.videoGravity = .resizeAspect
        let rootLayer: CALayer? = self.placeHolder.layer
        rootLayer?.masksToBounds = true
        self.previewLayer?.frame = (rootLayer?.bounds)!
        rootLayer?.addSublayer(self.previewLayer!)
    }
    
    
    
    
    
    func cameraForPosition(desiredPosition: AVCaptureDevice.Position) -> AVCaptureDeviceInput? {
        
        let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera,.builtInDualCamera,.builtInTelephotoCamera,.builtInTrueDepthCamera], mediaType: .video, position: desiredPosition)
        
        for device in discoverySession.devices {
            if device.position == desiredPosition {
                    var error: Error? = nil
                    var input: AVCaptureDeviceInput? = nil
                        input = try? AVCaptureDeviceInput(device: device)
                    if let anInput = input {
                        if (session?.canAddInput(anInput))! {
                            return input
                        }
                    }
                }
        }
        return nil
    }
    
    
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        var image: UIImage? = GMVUtility.sampleBufferTo32RGBA(sampleBuffer)
        var devicePosition: AVCaptureDevice.Position = cameraSwitch.isOn ? .front : .back
        // Establish the image orientation.
        var deviceOrientation: UIDeviceOrientation = UIDevice.current.orientation
        
        var orientation: GMVImageOrientation = GMVUtility.imageOrientation(from: deviceOrientation, with: devicePosition, defaultDeviceOrientation: lastKnownDeviceOrientation!)
        
        var options = [GMVDetectorImageOrientation: orientation]
        
        // Detect features using GMVDetector.
        
        var faces = faceDetector?.features(in: image, options: options) as? [GMVFaceFeature]
        print("Detected \(faces?.count) face(s).")
        // The video frames captured by the camera are a different size than the video preview.
        // Calculates the scale factors and offset to properly display the features.
        var fdesc = CMSampleBufferGetFormatDescription(sampleBuffer)
        var clap: CGRect = CMVideoFormatDescriptionGetCleanAperture(fdesc!, false)
        var parentFrameSize: CGSize = previewLayer!.frame.size
        
        // Assume AVLayerVideoGravityResizeAspect
        
        var cameraRatio: CGFloat = clap.size.height / clap.size.width
        var viewRatio: CGFloat = parentFrameSize.width / parentFrameSize.height
        var xScale: CGFloat = 1
        var yScale: CGFloat = 1
        var videoBox: CGRect = CGRect.zero
        if viewRatio > cameraRatio {
            videoBox.size.width = parentFrameSize.height * clap.size.width / clap.size.height
            videoBox.size.height = parentFrameSize.height
            videoBox.origin.x = (parentFrameSize.width - videoBox.size.width) / 2
            videoBox.origin.y = (videoBox.size.height - parentFrameSize.height) / 2
            xScale = videoBox.size.width / clap.size.width
            yScale = videoBox.size.height / clap.size.height
        }else{
            videoBox.size.width = parentFrameSize.width
            videoBox.size.height = clap.size.width * (parentFrameSize.width / clap.size.height)
            videoBox.origin.x = (videoBox.size.width - parentFrameSize.width) / 2
            videoBox.origin.y = (parentFrameSize.height - videoBox.size.height) / 2
            
            xScale = videoBox.size.width / clap.size.height
            yScale = videoBox.size.height / clap.size.width
        }
        
        DispatchQueue.main.sync {
            
            for featureView in overlayView.subviews {
                featureView.removeFromSuperview()
            }
            
            for face in faces!{
                
                var faceRect: CGRect = scaledRect(face.bounds, xscale: xScale, yscale: yScale, offset: videoBox.origin)
                
                DrawingUtility.addRectangle(faceRect, to: overlayView, with: UIColor.red)
                
                if face.hasBottomMouthPosition {
                    var point: CGPoint = scaledPoint(face.bottomMouthPosition, xscale: xScale, yscale: yScale, offset: videoBox.origin)
                    DrawingUtility.addCircle(at: point, to: overlayView, with: UIColor.green, withRadius: 5)
                }
                
                if face.hasMouthPosition {
                    var point: CGPoint = scaledPoint(face.mouthPosition, xscale: xScale, yscale: yScale, offset: videoBox.origin)
                    DrawingUtility.addCircle(at: point, to: overlayView, with: UIColor.green, withRadius: 10)
                }
                
                if face.hasRightMouthPosition {
                    var point: CGPoint = scaledPoint(face.rightMouthPosition, xscale: xScale, yscale: yScale, offset: videoBox.origin)
                    DrawingUtility.addCircle(at: point, to: overlayView, with: UIColor.green, withRadius: 5)
                }
                
                if face.hasLeftMouthPosition {
                    var point: CGPoint = scaledPoint(face.leftMouthPosition, xscale: xScale, yscale: yScale, offset: videoBox.origin)
                    DrawingUtility.addCircle(at: point, to: overlayView, with: UIColor.green, withRadius: 5)
                }
                
                // Nose
                
                if face.hasNoseBasePosition {
                    var point: CGPoint = scaledPoint(face.noseBasePosition, xscale: xScale, yscale: yScale, offset: videoBox.origin)
                    DrawingUtility.addCircle(at: point, to: overlayView, with: UIColor.darkGray, withRadius: 10)
                }
                
                //Eyes
                
                if face.hasLeftEyePosition {
                    var point: CGPoint = scaledPoint(face.leftEyePosition, xscale: xScale, yscale: yScale, offset: videoBox.origin)
                    DrawingUtility.addCircle(at: point, to: overlayView, with: UIColor.blue, withRadius: 10)
                }
                
                if face.hasRightEyePosition {
                    var point: CGPoint = scaledPoint(face.rightEyePosition, xscale: xScale, yscale: yScale, offset: videoBox.origin)
                    DrawingUtility.addCircle(at: point, to: overlayView, with: UIColor.blue, withRadius: 10)
                }
                
                //Ears
                
                if face.hasLeftEarPosition {
                    var point: CGPoint = scaledPoint(face.leftEarPosition, xscale: xScale, yscale: yScale, offset: videoBox.origin)
                    DrawingUtility.addCircle(at: point, to: overlayView, with: UIColor.purple, withRadius: 10)
                }
                
                if face.hasRightEarPosition {
                    var point: CGPoint = scaledPoint(face.rightEarPosition, xscale: xScale, yscale: yScale, offset: videoBox.origin)
                    DrawingUtility.addCircle(at: point, to: overlayView, with: UIColor.purple, withRadius: 10)
                }
                
                // Cheeks
                
                if face.hasLeftCheekPosition {
                    var point: CGPoint = scaledPoint(face.leftCheekPosition, xscale: xScale, yscale: yScale, offset: videoBox.origin)
                    DrawingUtility.addCircle(at: point, to: overlayView, with: UIColor.magenta, withRadius: 10)
                }
                
                if face.hasRightCheekPosition {
                    var point: CGPoint = scaledPoint(face.rightCheekPosition, xscale: xScale, yscale: yScale, offset: videoBox.origin)
                    DrawingUtility.addCircle(at: point, to: overlayView, with: UIColor.magenta, withRadius: 10)
                }
                
                if face.hasTrackingID {
                    var point: CGPoint = scaledPoint(face.bounds.origin, xscale: xScale, yscale: yScale, offset: videoBox.origin)
                    var label = UILabel(frame: CGRect(x: point.x, y: point.y, width: 100, height: 20))
                    label.text = "id: \(UInt(face.trackingID))"
                    overlayView.addSubview(label)
                }
                
                
            }
            
            
        }
        
        
    }

    
    
    @IBAction func cameraDeviceChanged(_ sender: Any) {
        updateCameraSelection()
    }
}




