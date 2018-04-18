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
        let arrayOfStickers = stickers as! [Sticker]
        let sticker = UIImage(named: arrayOfStickers[indexPath.row].name)
        cell.stickerImageView.image = sticker
        
        return cell
        
    }
    
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        if !faces.isEmpty{
            stickerToPlace = Sticker(name: "somesticker.png", with: undefined)
            let arrayOfStickers = stickers as! [Sticker]
            stickerToPlace = arrayOfStickers[indexPath.row]
        }
        
        
    }
    
    

    

    
    
    
    
    
    
}
