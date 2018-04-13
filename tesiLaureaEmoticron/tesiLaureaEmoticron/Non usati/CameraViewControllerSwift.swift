
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
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Set up default camera settings.
        videoDataOutputQueue = DispatchQueue(label: "VideoDataOutputQueue")
        session = AVCaptureSession()
        session?.sessionPreset = .medium
        cameraSwitch.isOn = true
        updateCameraSelection()
        // Setup video processing pipeline.
        setupVideoProcessing()
        // Setup camera preview.
        setupCameraPreview()
        // Initialize the face detector.
        let options = [GMVDetectorFaceMinSize: 0.3, GMVDetectorFaceTrackingEnabled: true, GMVDetectorFaceLandmarkType: GMVDetectorFaceLandmark.all.rawValue] as [AnyHashable: Any]
        faceDetector = GMVDetector(ofType: GMVDetectorTypeFace, options: options)
    }
    

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
        previewLayer?.position = CGPoint(x: (previewLayer?.frame.midX)!, y: (previewLayer?.frame.midY)!)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        cleanupCaptureSession()
    }
    
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        session?.startRunning()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        session?.stopRunning()
    }
    

    override func willAnimateRotation(to toInterfaceOrientation: UIInterfaceOrientation, duration: TimeInterval) {
        // Camera rotation needs to be manually set when rotation changes.
        if (previewLayer != nil) {
            if toInterfaceOrientation == .portrait {
                previewLayer?.connection?.videoOrientation = .portrait
            } else if toInterfaceOrientation == .portraitUpsideDown {
                previewLayer?.connection?.videoOrientation = .portraitUpsideDown
            } else if toInterfaceOrientation == .landscapeLeft {
                previewLayer?.connection?.videoOrientation = .landscapeLeft
            } else if toInterfaceOrientation == .landscapeRight {
                previewLayer?.connection?.videoOrientation = .landscapeRight
            }
        }
    }
    
    func scaledRect(_ rect: CGRect, xScale xscale: CGFloat, yScale yscale: CGFloat, offset: CGPoint) -> CGRect {
        var resultRect = CGRect(x: rect.origin.x * xscale, y: rect.origin.y * yscale, width: rect.size.width * xscale, height: rect.size.height * yscale)
        resultRect = resultRect.offsetBy(dx: offset.x, dy: offset.y)
        return resultRect
    }
    
    func scaledPoint(_ point: CGPoint, xScale xscale: CGFloat, yScale yscale: CGFloat, offset: CGPoint) -> CGPoint {
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
        if (videoDataOutput != nil) {
            session?.removeOutput(videoDataOutput!)
        }
        videoDataOutput = nil
    }
    
    func cleanupCaptureSession() {
        session?.stopRunning()
        cleanupVideoProcessing()
        session = nil
        previewLayer?.removeFromSuperlayer()
    }
    
    
    
    func updateCameraSelection() {
        
        session?.beginConfiguration()
        // Remove old inputs
        let oldInputs = session?.inputs
        for oldInput: AVCaptureInput? in oldInputs! {
            if let anInput = oldInput {
                session?.removeInput(anInput)
            }
        }
        let desiredPosition: AVCaptureDevice.Position = cameraSwitch.isOn ? .front : .back
        let input: AVCaptureDeviceInput? = cameraForPosition(desiredPosition: desiredPosition)
        if input == nil {
            // Failed, restore old inputs
            for oldInput: AVCaptureInput? in oldInputs! {
                if let anInput = oldInput {
                    session?.addInput(anInput)
                }
            }
        } else {
            // Succeeded, set input and update connection states
            if let anInput = input {
                session?.addInput(anInput)
            }
        }
        session?.commitConfiguration()
    }
    
    func setupVideoProcessing() {
        videoDataOutput = AVCaptureVideoDataOutput()
        let rgbOutputSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        videoDataOutput?.videoSettings = rgbOutputSettings
        if !session!.canAddOutput(videoDataOutput!) {
            cleanupVideoProcessing()
            print("Failed to setup video output")
            return
        }
        videoDataOutput?.alwaysDiscardsLateVideoFrames = true
        videoDataOutput?.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        session?.addOutput(videoDataOutput!)
    }
    
    func setupCameraPreview() {
        previewLayer = AVCaptureVideoPreviewLayer(session: session!)
        previewLayer?.backgroundColor = UIColor.white.cgColor
        previewLayer?.videoGravity = .resizeAspect
        let rootLayer: CALayer? = placeHolder.layer
        rootLayer?.masksToBounds = true
        previewLayer?.frame = (rootLayer?.bounds)!
        rootLayer?.addSublayer(previewLayer!)
    }
    
    
    
    
    
    func cameraForPosition(desiredPosition: AVCaptureDevice.Position) -> AVCaptureDeviceInput? {
        for device: AVCaptureDevice? in
            AVCaptureDevice.devices(for: .video) {
            if device?.position == desiredPosition {
                var error: Error? = nil
                var input: AVCaptureDeviceInput? = nil
                if let aDevice = device {
                    input = try? AVCaptureDeviceInput(device: aDevice)
                }
                if let anInput = input {
                    if (session?.canAddInput(anInput))! {
                        return input
                    }
                }
                return nil
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
                
                var faceRect: CGRect = scaledRect(face.bounds, xScale: xScale, yScale: yScale, offset: videoBox.origin)
                
                DrawingUtility.addRectangle(faceRect, to: overlayView, with: UIColor.red)
                
                if face.hasBottomMouthPosition {
                    var point: CGPoint = scaledPoint(face.bottomMouthPosition, xScale: xScale, yScale: yScale, offset: videoBox.origin)
                    DrawingUtility.addCircle(at: point, to: overlayView, with: UIColor.green, withRadius: 5)
                }
                
                if face.hasMouthPosition {
                    var point: CGPoint = scaledPoint(face.mouthPosition, xScale: xScale, yScale: yScale, offset: videoBox.origin)
                    DrawingUtility.addCircle(at: point, to: overlayView, with: UIColor.green, withRadius: 10)
                }
                
                if face.hasRightMouthPosition {
                    var point: CGPoint = scaledPoint(face.rightMouthPosition, xScale: xScale, yScale: yScale, offset: videoBox.origin)
                    DrawingUtility.addCircle(at: point, to: overlayView, with: UIColor.green, withRadius: 5)
                }
                
                if face.hasLeftMouthPosition {
                    var point: CGPoint = scaledPoint(face.leftMouthPosition, xScale: xScale, yScale: yScale, offset: videoBox.origin)
                    DrawingUtility.addCircle(at: point, to: overlayView, with: UIColor.green, withRadius: 5)
                }
                
                // Nose
                
                if face.hasNoseBasePosition {
                    var point: CGPoint = scaledPoint(face.noseBasePosition, xScale: xScale, yScale: yScale, offset: videoBox.origin)
                    DrawingUtility.addCircle(at: point, to: overlayView, with: UIColor.darkGray, withRadius: 10)
                }
                
                //Eyes
                
                if face.hasLeftEyePosition {
                    var point: CGPoint = scaledPoint(face.leftEyePosition, xScale: xScale, yScale: yScale, offset: videoBox.origin)
                    DrawingUtility.addCircle(at: point, to: overlayView, with: UIColor.blue, withRadius: 10)
                }
                
                if face.hasRightEyePosition {
                    var point: CGPoint = scaledPoint(face.rightEyePosition, xScale: xScale, yScale: yScale, offset: videoBox.origin)
                    DrawingUtility.addCircle(at: point, to: overlayView, with: UIColor.blue, withRadius: 10)
                }
                
                //Ears
                
                if face.hasLeftEarPosition {
                    var point: CGPoint = scaledPoint(face.leftEarPosition, xScale: xScale, yScale: yScale, offset: videoBox.origin)
                    DrawingUtility.addCircle(at: point, to: overlayView, with: UIColor.purple, withRadius: 10)
                }
                
                if face.hasRightEarPosition {
                    var point: CGPoint = scaledPoint(face.rightEarPosition, xScale: xScale, yScale: yScale, offset: videoBox.origin)
                    DrawingUtility.addCircle(at: point, to: overlayView, with: UIColor.purple, withRadius: 10)
                }
                
                // Cheeks
                
                if face.hasLeftCheekPosition {
                    var point: CGPoint = scaledPoint(face.leftCheekPosition, xScale: xScale, yScale: yScale, offset: videoBox.origin)
                    DrawingUtility.addCircle(at: point, to: overlayView, with: UIColor.magenta, withRadius: 10)
                }
                
                if face.hasRightCheekPosition {
                    var point: CGPoint = scaledPoint(face.rightCheekPosition, xScale: xScale, yScale: yScale, offset: videoBox.origin)
                    DrawingUtility.addCircle(at: point, to: overlayView, with: UIColor.magenta, withRadius: 10)
                }
                
                if face.hasTrackingID {
                    var point: CGPoint = scaledPoint(face.bounds.origin, xScale: xScale, yScale: yScale, offset: videoBox.origin)
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




