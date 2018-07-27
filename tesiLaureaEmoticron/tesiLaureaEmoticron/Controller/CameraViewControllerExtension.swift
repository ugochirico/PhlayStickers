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
        cell.layer.cornerRadius = cell.frame.size.width / 2
        let arrayOfStickers = stickers as! [Sticker]
        let sticker = UIImage(named: arrayOfStickers[indexPath.row%stickers.count].name)
        cell.stickerImageView.image = sticker
        
        return cell
        
    }
    
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        stickersToPlace = NSMutableArray()
        pictureFrameToPlace = Sticker()
        if !faces.isEmpty{
            let arrayOfStickers = stickers as! [Sticker]
            stickersToPlace.add(arrayOfStickers[indexPath.row])
            if indexPath.row < pictureFrames.count{
                pictureFrameToPlace = pictureFrames[indexPath.row] as! Sticker
            }
            //NSLog("STICKER NAME: %s\n",stickerToPlace.name);
        }
        
        
    }
    

    
    
    
    
    
    
    
    
    
    
    
}

