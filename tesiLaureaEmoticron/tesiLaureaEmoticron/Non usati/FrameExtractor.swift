//
//  FrameExtractor.swift
//  tesiLaureaEmoticron
//
//  Created by Alessandro Emoticron on 11/04/2018.
//  Copyright © 2018 Alessandro Marotta. All rights reserved.
//

import UIKit
import Foundation
import GoogleMVDataOutput

//il seguente delegate deve essere adottato dal viewcontroller che dovrà implementare la funzione per catturare una UIImage ogni volta che ce ne sarà una disponibile
protocol FrameExtractorDelegate: class{
    func captured(image: UIImage)
}

class FrameExtractor: NSObject {
    
    private let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "session queue")
    private var permissionGranted = false
    private let position = AVCaptureDevice.Position.front
    private let quality = AVCaptureSession.Preset.high
    private var context: CIContext?
    
    weak var delegate: FrameExtractorDelegate?
    
    override init(){
        super.init()
        checkPermission()
        sessionQueue.async { [unowned self] in
            self.configureSession()
            self.captureSession.startRunning()
        }
    }
    
    public func getSessionQueue()->DispatchQueue{
        return sessionQueue
    }
    
    
    private func checkPermission(){
        switch AVCaptureDevice.authorizationStatus(for: AVMediaType.video) {
        case .authorized:
            // The user has explicitly granted permission for media capture
            permissionGranted = true
            break
            
        case .notDetermined:
            // The user has not yet granted or denied permission
            requestPermission()
            break
            
        default:
            // The user has denied permission
            permissionGranted = false
            break
        }
    }
    
    
    private func requestPermission(){
        sessionQueue.suspend()
        AVCaptureDevice.requestAccess(for: AVMediaType.video) { [unowned self] granted in
            self.permissionGranted = granted
            self.sessionQueue.resume()
        }
    }
    
    private func configureSession(){
        
        guard permissionGranted else { return }
        captureSession.sessionPreset = quality
        
        guard let captureDevice: AVCaptureDevice = selectCaptureDevice() else { return }
        
        
        //******************INPUT CAMERA******************//
        guard let captureDeviceInput = try? AVCaptureDeviceInput(device: captureDevice) else { return }
        //controlla se il dispositivo di input può essere aggiunto alla capture session, in caso affermativo aggiungilo
        guard captureSession.canAddInput(captureDeviceInput) else { return }
        captureSession.addInput(captureDeviceInput)
        
        
        //******************OUTPUT CAMERA******************//
        let videoOutput = AVCaptureVideoDataOutput()
        //il Frame Extractor deve essere il delegate del video output
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "sample buffer"))
        //come prima, controlla se il videoOutput può essere aggiunto alla sessione corrente, in caso affermativo aggiungilo
        guard captureSession.canAddOutput(videoOutput) else { return }
        captureSession.addOutput(videoOutput)
        
        //*****************ORIENTAMENTO CAMERA****************//
        guard let connection = videoOutput.connection(with: .video) else { return }
        guard connection.isVideoOrientationSupported else { return }
        guard connection.isVideoMirroringSupported else { return }
        
        connection.videoOrientation = .portrait
        connection.isVideoMirrored = position == .front
        
        
        
    }
    
    private func selectCaptureDevice()->AVCaptureDevice?{
        
        //filtriamo i dispositivi di cattura, in modo che siano solo quelli scelti con position (per ora, la camera frontale) e che regi    strino video
        
        let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera,.builtInDualCamera,.builtInTelephotoCamera,.builtInTrueDepthCamera], mediaType: .video, position: position)
        
        return (discoverySession.devices.filter {
            ($0 as AnyObject).hasMediaType(.video) &&
                ($0 as AnyObject).position == position
            }.first)!
    }
    
    private func imageFromSampleBuffer(sampleBuffer: CMSampleBuffer) -> UIImage? {
        
        /*1. Trasforma il sample buffer in un CVImageBuffer
         2. Trasforma il CVImageBuffer in una CIImage
         3. Trasforma la CIImage in una CGImage
         4. Trasforma la CGImage in una UIImage*/
        
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        context = CIContext() //necessario perchè da qui creiamo la CGImage
        guard let cgImage = context?.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        
        return UIImage(cgImage: cgImage)
    }
    
    
}


extension FrameExtractor: AVCaptureVideoDataOutputSampleBufferDelegate{
    
    //qui definiamo cosa succede ogni volta che ci sono nuovi frame disponibili e ogni volta che dei frame vengono scartati
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        guard let uiImage = imageFromSampleBuffer(sampleBuffer: sampleBuffer) else { return }
        
        //mandiamo al delegate l'immagine attraverso il main thread, in modo che il chiamante non debba avere a che fare con la serial queue
        DispatchQueue.main.async { [unowned self] in
            self.delegate?.captured(image: uiImage)
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        print("Butto frame")
    }
    
}
