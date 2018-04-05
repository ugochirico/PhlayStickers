//
//  ViewController.swift
//  tesiLaureaEmoticron
//
//  Created by Alessandro Emoticron on 04/04/2018.
//  Copyright © 2018 Alessandro Marotta. All rights reserved.
//

import UIKit
import AVFoundation
import GoogleMVDataOutput
import GoogleMobileVision

class ViewController: UIViewController {
    
    
    @IBOutlet weak var previewView: UIImageView!
    
    var captureSession: AVCaptureSession?
    var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    var faceDetector: GMVDetector?
    var faces: [GMVFaceFeature]?
    var options: [AnyHashable : Any]?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let captureDevice = AVCaptureDevice.default(for: .video)
        options = [
            GMVDetectorFaceMinSize : 0.3,
            GMVDetectorFaceTrackingEnabled: true,
            GMVDetectorFaceLandmarkType : GMVDetectorFaceLandmark.all
            ] 

        
        faceDetector = GMVDetector(ofType: GMVDetectorTypeFace, options: options)
        
        do {
            let input = try AVCaptureDeviceInput(device: captureDevice!)
            
            captureSession = AVCaptureSession()
            captureSession?.addInput(input)
            
            videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
            videoPreviewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
            videoPreviewLayer?.frame = view.layer.bounds
            
            previewView.layer.addSublayer(videoPreviewLayer!)
            
            captureSession?.startRunning()
        } catch {
            print(error)
        }
        
        
    }
    
    
    @IBAction func captureButton(_ sender: Any) {
    
        faces = faceDetector?.features(in: previewView.image, options: options) as? [GMVFaceFeature]
    
    }
    
    
}

