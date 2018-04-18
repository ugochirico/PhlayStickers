//
//  Sticker.m
//  tesiLaureaEmoticron
//
//  Created by Alessandro Emoticron on 18/04/2018.
//  Copyright © 2018 Alessandro Marotta. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Sticker.h"

@implementation Sticker

@synthesize type;
@synthesize name;


- (id)initWithName: (NSString *)name withType:(StickerType)type{
    self.name = name;
    self.type = type;
    return self;
}


- (BOOL)equalType: (StickerType) type{
    if(self.type == type){
        return YES;
    }else{
        return NO;
    }
}




@end

