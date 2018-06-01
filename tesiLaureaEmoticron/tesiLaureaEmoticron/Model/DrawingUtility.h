/*
 Copyright 2017 Google Inc.
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

@import Foundation;
@import UIKit;

@interface DrawingUtility : NSObject

+ (void)addCircleAtPoint:(CGPoint)point
                  toView:(UIView *)view
               withColor:(UIColor *)color
              withRadius:(NSInteger)width;

+ (void)addRectangle:(CGRect)rect
              toView:(UIView *)view
           withColor:(UIColor *)color;

+ (void)addTextLabel:(NSString *)text
              atRect:(CGRect)rect
              toView:(UIView *)view
           withColor:(UIColor *)color;

+ (CGRect)scaledRect:(CGRect)rect
              xScale:(CGFloat)xscale
              yScale:(CGFloat)yscale
              offset:(CGPoint)offset;

+ (CGPoint)scaledPoint:(CGPoint)point
                xScale:(CGFloat)xscale
                yScale:(CGFloat)yscale
                offset:(CGPoint)offset;

+(UIImage*)scaleImageWithImage: (UIImage*) sourceImage scaledToWidth: (float) i_width;

+ (UIImage *)scaleImageToSize: (UIImage*) image withNewSize: (CGSize)newSize;

+(void)setAnchorPoint:(CGPoint)anchorPoint forView:(UIView *)view;

+(UIImage*) drawImage:(UIImage*) fgImage
              inImage:(UIImage*) bgImage;

+(UIImage *)renderViewAsImage: (UIView*) viewToRender;

+(UIImage*)mergeImage:(UIImage*)mask overImage:(UIImage*)source inSize:(CGSize)size inView: (UIView *)thisView;



@end
