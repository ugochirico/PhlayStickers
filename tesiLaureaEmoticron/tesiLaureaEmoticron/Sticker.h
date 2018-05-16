//
//  Sticker.h
//  tesiLaureaEmoticron
//
//  Created by Alessandro Emoticron on 18/04/2018.
//  Copyright © 2018 Alessandro Marotta. All rights reserved.
//

@import Foundation;
@import UIKit;

#ifndef StickerType_h
#define StickerType_h

typedef enum{
    head,
    ear,
    eye,
    mouth,
    nose,
    cheekbones,
    undefined
}StickerType;

#endif

@interface Sticker : NSObject 

@property NSString *name;
@property StickerType type;
@property CGFloat offsetX;
@property CGFloat offsetY;


- (id)initWithName: (NSString *)name withType: (NSString *) type;


@end





