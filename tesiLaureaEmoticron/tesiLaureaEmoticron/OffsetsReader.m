//
//  FileReader.m
//  tesiLaureaEmoticron
//
//  Created by Alessandro Emoticron on 16/05/2018.
//  Copyright © 2018 Alessandro Marotta. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OffsetsReader.h"


@implementation OffsetsReader: NSObject


+ (NSMutableArray <NSString *> *)getOffsetStringsFromFile{
    
    NSMutableArray <NSString *> *offsetsStrings;
    NSString *path = [[NSBundle mainBundle] pathForResource:@"offsets"
                                                     ofType:@"txt"];
    
    NSString *content = [NSString stringWithContentsOfFile:path
                                                  encoding:NSUTF8StringEncoding
                                                     error:NULL];
    
    offsetsStrings = (NSMutableArray <NSString *> *)[content componentsSeparatedByString:@"\n"];
    
    [offsetsStrings removeLastObject];
    
    return offsetsStrings;
}

@end
