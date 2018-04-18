//
//  Sticker.h
//  tesiLaureaEmoticron
//
//  Created by Alessandro Emoticron on 18/04/2018.
//  Copyright © 2018 Alessandro Marotta. All rights reserved.
//

@import Foundation;

#ifndef StickerType_h
#define StickerType_h

typedef enum{
    mask,
    moustache,
    glasses,
    undefined
}StickerType;

#endif

@interface Sticker : NSObject 

@property NSString *name;
@property StickerType type;


- (id)initWithName: (NSString *)name withType:(StickerType )type;
- (BOOL)equalType: (StickerType) type;


@end





