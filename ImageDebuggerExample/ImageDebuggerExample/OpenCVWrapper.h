//
//  OpenCVWrapper.h
//  ImageDebuggerExample
//
//  Created by Shaan Singh on 1/15/20.
//  Copyright © 2020 Blue Cocoa, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class UIImage;
@interface OpenCVWrapper : NSObject

/// Prepares image for Canny edge detection
- (UIImage *) performPreProcessing:(UIImage *)src;

/// Finds edges in an image
- (UIImage *) findEdges:(UIImage *)src;

@end

NS_ASSUME_NONNULL_END
