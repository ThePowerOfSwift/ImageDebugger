//
//  ViewController.swift
//  ImageDebuggerExample
//
//  Created by Shaan Singh on 1/15/20.
//  Copyright © 2020 Blue Cocoa, Inc. All rights reserved.
//

import UIKit
import AVFoundation
import VideoToolbox

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    /// Handles live camera input
    let captureSession = AVCaptureSession()
    
    /// Interfaces with OpenCV to process our frames
    let processor = OpenCVWrapper()
    
    /// Logs frames with the server, viewable on the web client
    let debugger = ImageDebugger.shared
    
    /// Displays the results of our image processing
    @IBOutlet weak var imageView: UIImageView!
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Configure the capture session for real-time camera input
        captureSession.sessionPreset = .photo
        
        guard let cameraDevice = AVCaptureDevice.default(for: .video) else { return }
        
        do {
            let input = try AVCaptureDeviceInput(device: cameraDevice)
            captureSession.addInput(input)
        } catch {
            print("Failed to configure capture session. \(error.localizedDescription)")
        }
        
        // Setup video output
        let videoOutput = AVCaptureVideoDataOutput()
        let queue = DispatchQueue(label: "com.bluecocoa.ImageDebuggerExample.videoDataQueue",
                                  qos: .userInitiated,
                                  attributes: [],
                                  autoreleaseFrequency: .workItem)
        videoOutput.setSampleBufferDelegate(self, queue: queue)
        
        // Start streaming from the camera
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
            captureSession.startRunning()
        }
    }
    
    /**
     Here we will use OpenCV to do some basic image processing on our `sampleBuffer`,
     logging interim results with `ImageDebugger` along the way. When we have a processed
     result, we'll replace the camera output with it. (Goal: a video of edges.)
     */
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // Lock the pixel buffer so that we have exclusive processing access
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        
        debugger.log(pixelBuffer, withMessage: "Raw pixel buffer")
        
        // Convert CVPixelBuffer to UIImage (via CGImage, which OpenCV needs for Mat conversions)
        var cgImage: CGImage!
        VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &cgImage)
        let uiImage = UIImage(cgImage: cgImage)
        
        // Prepare the image for Canny edge detection
        let pre = processor.performPreProcessing(uiImage)
        
        debugger.log(pre, withMessage: "Pre-processed image; ready for edge detection")
        
        // Find edges
        var edges = processor.findEdges(pre)
        
        // Rotate the final image back to portrait orientation
        edges = UIImage(cgImage: edges.cgImage!, scale: 1, orientation: .right)
        
        debugger.log(edges, withMessage: "Final canny result")
        
        // Only log every 100 frames
        if debugger.logsLeftForUnblock == 0 && !debugger.unblockOccurred {
            debugger.blockNextLogs(300)  // # of logs in this method * # of frames to ignore
        }
        
        DispatchQueue.main.async {
            // Display result
            self.imageView.image = edges
        }
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
    }
}
