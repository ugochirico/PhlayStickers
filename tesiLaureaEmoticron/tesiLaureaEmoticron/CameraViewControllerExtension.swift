//
//  CameraViewControllerExtension.swift
//  tesiLaureaEmoticron
//
//  Created by Alessandro Emoticron on 13/04/2018.
//  Copyright © 2018 Alessandro Marotta. All rights reserved.
//

import Foundation

extension CameraViewController: UICollectionViewDelegate, UICollectionViewDataSource{
    
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return stickers.count
    }
    
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "stickerCell", for: indexPath) as! StickerCell
        let sticker = UIImage(named: stickers[indexPath.row])
        cell.stickerImageView.image = sticker
        
        return cell
        
    }
    
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        if !faces.isEmpty{
//            let face = self.faces[indexPath.row]
//            let stickerName = stickers[indexPath.row]
//            let stickerImage = UIImage(named: stickerName)
//            let stickerView = UIImageView(image: stickerImage)
//
//            stickerView.contentMode = .scaleAspectFit
//            stickerView.layer.position = face.mouthPosition
//
//            DispatchQueue.main.async {
//                if face.hasMouthPosition{
//                    if stickerName == "moustache.png"{
//                        self.overlayView.addSubview(stickerView)
//                    }
//
//                }
//            }
            stickerToPlace = self.stickers[indexPath.row];
            
        }
        
    }
    
    

    

    
    
    
    
    
    
}
