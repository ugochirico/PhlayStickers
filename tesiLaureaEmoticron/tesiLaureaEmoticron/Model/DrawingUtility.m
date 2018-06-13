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

#import "Foundation/Foundation.h"
#import "DrawingUtility.h"

@implementation DrawingUtility


+ (void)addCircleAtPoint:(CGPoint)point
                  toView:(UIView *)view
               withColor:(UIColor *)color
              withRadius:(NSInteger)width {
    CGRect circleRect = CGRectMake(point.x - width / 2, point.y - width / 2, width, width);
    UIView *circleView = [[UIView alloc] initWithFrame:circleRect];
    circleView.layer.cornerRadius = width / 2;
    circleView.alpha = 0.7;
    circleView.backgroundColor = color;
    [view addSubview:circleView];
}

+ (void)addRectangle:(CGRect)rect
              toView:(UIView *)view
           withColor:(UIColor *)color {
    UIView *newView = [[UIView alloc] initWithFrame:rect];
    newView.layer.cornerRadius = 10;
    newView.alpha = 0.3;
    newView.backgroundColor = color;
    [view addSubview:newView];
}

+ (void)addTextLabel:(NSString *)text
              atRect:(CGRect)rect
              toView:(UIView *)view
           withColor:(UIColor *)color {
    UILabel *label = [[UILabel alloc] initWithFrame:rect];
    [label setTextColor:color];
    label.text = text;
    [view addSubview:label];
}

+ (CGRect)scaledRect:(CGRect)rect
              xScale:(CGFloat)xscale
              yScale:(CGFloat)yscale
              offset:(CGPoint)offset {
    CGRect resultRect = CGRectMake(rect.origin.x * xscale,
                                   rect.origin.y * yscale,
                                   rect.size.width * xscale,
                                   rect.size.height * yscale);
    resultRect = CGRectOffset(resultRect, offset.x, offset.y);
    return resultRect;
}

+ (CGPoint)scaledPoint:(CGPoint)point
                xScale:(CGFloat)xscale
                yScale:(CGFloat)yscale
                offset:(CGPoint)offset {
    CGPoint resultPoint = CGPointMake(point.x * xscale + offset.x, point.y * yscale + offset.y);
    return resultPoint;
}

+(UIImage*)scaleImageWithImage: (UIImage*) sourceImage scaledToWidth: (float) i_width
{
    float oldWidth = sourceImage.size.width;
    float scaleFactor = i_width / oldWidth;
    
    float newHeight = sourceImage.size.height * scaleFactor;
    float newWidth = oldWidth * scaleFactor;
    
    UIGraphicsBeginImageContext(CGSizeMake(newWidth, newHeight));
    [sourceImage drawInRect:CGRectMake(0, 0, newWidth, newHeight)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}

+ (UIImage *)scaleImageToSize: (UIImage*) image withNewSize: (CGSize)newSize {
    
    CGRect scaledImageRect = CGRectZero;
    
    CGFloat aspectWidth = newSize.width / newSize.width;
    CGFloat aspectHeight = newSize.height / newSize.height;
    CGFloat aspectRatio = MIN ( aspectWidth, aspectHeight );
    
    scaledImageRect.size.width = newSize.width * aspectRatio;
    scaledImageRect.size.height = newSize.height * aspectRatio;
    scaledImageRect.origin.x = (newSize.width - scaledImageRect.size.width) / 2.0f;
    scaledImageRect.origin.y = (newSize.height - scaledImageRect.size.height) / 2.0f;
    
    UIGraphicsBeginImageContextWithOptions( newSize, NO, 0 );
    [image drawInRect: scaledImageRect];
    UIImage* scaledImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return scaledImage;
    
}

+(void)setAnchorPoint:(CGPoint)anchorPoint forView:(UIView *)view
{
    CGPoint newPoint = CGPointMake(view.bounds.size.width * anchorPoint.x, view.bounds.size.height * anchorPoint.y);
    CGPoint oldPoint = CGPointMake(view.bounds.size.width * view.layer.anchorPoint.x, view.bounds.size.height * view.layer.anchorPoint.y);
    
    newPoint = CGPointApplyAffineTransform(newPoint, view.transform);
    oldPoint = CGPointApplyAffineTransform(oldPoint, view.transform);
    
    CGPoint position = view.layer.position;
    
    position.x -= oldPoint.x;
    position.x += newPoint.x;
    
    position.y -= oldPoint.y;
    position.y += newPoint.y;
    
    view.layer.position = position;
    view.layer.anchorPoint = anchorPoint;
}

+(UIImage*) drawImage:(UIImage*) fgImage
              inImage:(UIImage*) bgImage
{
    UIGraphicsBeginImageContextWithOptions(bgImage.size, FALSE, 0.0);
    [bgImage drawInRect:CGRectMake( 0, 0, bgImage.size.width, bgImage.size.height)];
    [fgImage drawInRect:CGRectMake( 0, 0, fgImage.size.width, fgImage.size.height)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return newImage;
}

+ (UIImage *)renderViewAsImage: (UIView*) viewToRender
{
    // setup context
    UIGraphicsBeginImageContextWithOptions(viewToRender.bounds.size, NO, 0.0f); // use same scale factor as device
    CGContextRef c = UIGraphicsGetCurrentContext();
    
    // render view
    [viewToRender.layer renderInContext:c];
    
    // get reslting image
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return result;
}

+(UIImage*)mergeImage:(UIImage*)mask overImage:(UIImage*)source inSize:(CGSize)size inView: (UIView *)myview
{
    //Capture image context ref
    UIGraphicsBeginImageContext(size);
    [myview.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *viewImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    //Draw images onto the context
    [source drawInRect:CGRectMake(0, 0, source.size.width, source.size.height)];
    [mask drawInRect:CGRectMake(0, 0, mask.size.width, mask.size.height)];
    
    return viewImage;
    
}


+ (UIImage*)imageByCombiningImage:(UIImage*)firstImage withImage:(UIImage*)secondImage {
    UIImage *image = nil;
    
    CGSize newImageSize = CGSizeMake(MAX(firstImage.size.width, secondImage.size.width), MAX(firstImage.size.height, secondImage.size.height));
    @try{
        UIGraphicsBeginImageContextWithOptions(newImageSize, NO, [[UIScreen mainScreen] scale]);
    }@catch(NSException *e){
        UIGraphicsBeginImageContext(newImageSize);
    }
    [firstImage drawAtPoint:CGPointMake(roundf((newImageSize.width-firstImage.size.width)/2),
                                        roundf((newImageSize.height-firstImage.size.height)/2))];
    [secondImage drawAtPoint:CGPointMake(roundf((newImageSize.width-secondImage.size.width)/2),
                                         roundf((newImageSize.height-secondImage.size.height)/2))];
    image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}

+ (UIImage *) rotatedImage: (UIImage *) image byAngle: (CGFloat) rotation // rotation in radians
{
    // Calculate Destination Size
    CGAffineTransform t = CGAffineTransformMakeRotation(rotation);
    CGRect sizeRect = (CGRect) {.size = image.size};
    CGRect destRect = CGRectApplyAffineTransform(sizeRect, t);
    CGSize destinationSize = destRect.size;
    
    // Draw image
    UIGraphicsBeginImageContext(destinationSize);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM(context, destinationSize.width / 2.0f, destinationSize.height / 2.0f);
    CGContextRotateCTM(context, rotation);
    [image drawInRect:CGRectMake(-image.size.width / 2.0f, -image.size.height / 2.0f, image.size.width, image.size.height)];
    
    // Save image
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}






@end


