//
//  ViewController.swift
//  tesiLaureaEmoticron
//
//  Created by Alessandro Emoticron on 04/04/2018.
//  Copyright © 2018 Alessandro Marotta. All rights reserved.
//

import UIKit
import GoogleMobileVision

class ViewController: UIViewController{
    

    @IBOutlet weak var previewView: UIImageView!
    
    var faceDetector: GMVDetector?
    var faces: [GMVFaceFeature]?
    var options: [AnyHashable : Any]?
    var frameExtractor: FrameExtractor?
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        frameExtractor = FrameExtractor()
        frameExtractor?.delegate = self
        
        
        let options =
            [GMVDetectorFaceLandmarkType: GMVDetectorFaceLandmark.all.rawValue,
             GMVDetectorFaceClassificationType: GMVDetectorFaceClassification.all.rawValue,
             GMVDetectorFaceMode: GMVDetectorFaceModeOption.fastMode.rawValue,
             GMVDetectorFaceTrackingEnabled: true,
             GMVDetectorFaceMinSize: 0.3] as [AnyHashable : Any]

        
        faceDetector = GMVDetector(ofType: GMVDetectorTypeFace, options: options)
        
        
    }
    
    
    
    
    func drawFaceLandmarks(){
        
        for face in faces! {
            // Face
            previewView.drawRectangle(with: face.bounds)
            
            
            // Mouth
            if face.hasMouthPosition {
                let leftMouthPosition = face.leftMouthPosition
                let rightMouthPosition = face.rightMouthPosition
                let bottomMouthPosition = face.bottomMouthPosition
                let mouthPosition = face.mouthPosition
                print("Mouth \(face.mouthPosition.x) \(face.mouthPosition.y)")
                
                previewView.drawCircle(at: leftMouthPosition)
                
            }
            // Smiling
            if face.hasSmilingProbability {
                print("Smiling probability \(face.smilingProbability)")
            }
        }
        
    }
}

extension UIImageView{
    
    func drawRectangle(with rect: CGRect){
        
        let rectangleView = UIView(frame: rect)
        rectangleView.layer.cornerRadius = 10
        rectangleView.layer.borderColor = UIColor.red.cgColor
        rectangleView.layer.borderWidth = 2
        addSubview(rectangleView)
        
    }
    
    func drawCircle(at point: CGPoint) {
        
        //        let width: CGFloat = image!.size.width / 2
        //
        //        let circle = CGRect(x: point.x - width / 2, y: point.y - width / 2, width: width, height: width)
        //        let circleView = UIView(frame: circle)
        //
        //        circleView.center = point
        //        circleView.layer.cornerRadius = width / 2
        //        circleView.clipsToBounds = true
        //        circleView.layer.borderColor = UIColor.green.cgColor
        //        circleView.layer.borderWidth = 2
        //        circleView.draw(circle)
        //        addSubview(circleView)
        
        let width: CGFloat = 5
        
        let circle = CGRect(x: point.x - width / 2, y: point.y - width / 2, width: width, height: width)
        let circleView = UIView(frame: circle)
        circleView.center = point
        circleView.layer.cornerRadius = width / 2
        circleView.layer.borderWidth = 2
        circleView.layer.borderColor = UIColor.red.cgColor
        addSubview(circleView)
    }
        
        
}

extension ViewController: FrameExtractorDelegate{
    func captured(image: UIImage) {
        previewView.image = image
    }
}

