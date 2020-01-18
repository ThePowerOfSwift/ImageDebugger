//
//  OpenCVWrapper.m
//  ImageDebuggerExample
//
//  Created by Shaan Singh on 1/15/20.
//  Copyright © 2020 Blue Cocoa, Inc. All rights reserved.
//

#import "OpenCVWrapper.h"
#import <opencv2/opencv.hpp>
#import <opencv2/imgcodecs/ios.h>
#import <UIKit/UIKit.h>
#import <CoreGraphics/CoreGraphics.h>

@implementation OpenCVWrapper

using namespace cv;

/// Prepares image for Canny edge detection
- (UIImage *) performPreProcessing:(UIImage *)src {
    // Convert to Mat
    Mat img;
    UIImageToMat(src, img);
    
    // Grayscale
    Mat gray;
    cvtColor(img, gray, COLOR_BGR2GRAY);
    
    // Blur slightly
    Mat blurred;
    GaussianBlur(img, blurred, cv::Size(3, 3), 0);
    
    return MatToUIImage(blurred);
}

/// Finds edges in an image
- (UIImage *) findEdges:(UIImage *)src {
    // Convert to Mat
    Mat img;
    UIImageToMat(src, img);
    
    // Detect edges
    Mat edges;
    Canny(img, edges, 10, 250);
    
    return MatToUIImage(edges);
}

@end
