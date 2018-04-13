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
        
        cell.stickerImageView.image = stickers[indexPath.row] as? UIImage
        
        return cell
        
    }
    
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        let sticker = stickers[indexPath.row]
        
        
        
    }
    
    
    
    
    
    
}
