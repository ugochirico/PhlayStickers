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




- (id)initWithName: (NSString *)name withType:(NSString*)type{
    
    self.name = name;
    self.offsetX = 0.0;
    self.offsetY = 0.0;
    self.scaleFactor = 0.0;
    
    if([type  isEqual: @"head"])
        self.type = head;
    else if([type  isEqual: @"ear"])
        self.type = ear;
    else if([type  isEqual: @"eye"])
        self.type = eye;
    else if([type  isEqual: @"mouth"])
        self.type = mouth;
    else if([type  isEqual: @"nose"])
        self.type = nose;
    else if([type  isEqual: @"cheek"])
        self.type = cheek;
    else if([type  isEqual: @"undefined"])
        self.type = undefined;

    
    return self;
}








@end

