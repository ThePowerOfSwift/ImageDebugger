//
//  ImageDebugger.swift
//  ImageDebuggerExample
//
//  Created by Shaan Singh on 1/15/20.
//  Copyright © 2020 Blue Cocoa, Inc. All rights reserved.
//

import Foundation
import Firebase

class ImageDebugger {
    
    static let shared = ImageDebugger()
    
    private let sessionUUID = UUID()
    
    private var sessionLogCount: Int = 0
    
    /// Date when next log call will be allowed to upload to server
    private(set) var logsBlockedUntil: Date?
    
    /// Number of log calls left before debugger is unblocked
    private(set) var logsLeftForUnblock: Int = 0
    
    /**
     `blockLogsFor(_:)` and `blockNextLogs(_:)` can block ImageDebugger from uploading images. When a block ends, this is set to true. It resets to false after the next successful `log` call.
     
     `blockNextLogs(2) -> log(image...) -> log(image...) -> unblockOccurred -> log(image...) -> !unblockOccurred`
     */
    private(set) var unblockOccurred = false
    
    /// Images for this session are uploaded under this reference
    private var storageSessionRef: StorageReference
    
    /// Documents for this session are stored under this reference
    private var databaseSessionRef: CollectionReference
    
    /// Used to maximize CPU resources while uploading images
    private let uploadQueue = OperationQueue()
    
    /**
     When logging a `UIImage` with an `imageOrientation` that is not `.up`, the orientation will be lost because `imageOrientation` is merely a flag that adjusts the display of `UIImage`s (it is not a representation of an image's actual orientation). Setting `shouldFixOrientationBeforeUpload` to true ensures that the logged image will match the `imageOrientation` flag because the debugger will manually redraw it before upload. This may affect your app's performance, and if it does, you can use `blockLogsFor(_:)` and/or `blockNextLogs(_:)` to compensate. To avoid using this setting altogether, try to fix the orientation earlier in your pipeline (for example, by ensuring your video stream outputs correctly oriented frames before applying any image processing).
     */
    public var shouldFixOrientationBeforeUpload = false
    
    init() {
        storageSessionRef = Storage.storage()
            .reference()
            .child(sessionUUID.uuidString)
        
        databaseSessionRef = Firestore.firestore()
            .collection("sessions")
            .document(sessionUUID.uuidString)
            .collection("images")
        
        // We want to upload serially, so results are displayed in order.
        // Also, we are perfectly happy with slow logs for high app performance.
        uploadQueue.maxConcurrentOperationCount = 1
        
        // Log the session start time
        Firestore.firestore().collection("sessions").document(sessionUUID.uuidString).setData([
            "sessionStartTime" : Timestamp(date: Date())
        ], merge: true)
    }
    
    /// Capture and store a CVPixelBuffer
    func log(_ pixelBuffer: CVPixelBuffer, withMessage message: String) {
        guard canLog() else { return }
        unblockOccurred = false
        log(CIImage(cvPixelBuffer: pixelBuffer), withMessage: message)
    }
    
    /// Capture and store a CGImage
    func log(_ cgImage: CGImage, withMessage message: String) {
        guard canLog() else { return }
        unblockOccurred = false
        log(UIImage(cgImage: cgImage), withMessage: message)
    }
    
    /// Capture and store a CIImage
    func log(_ ciImage: CIImage, withMessage message: String) {
        guard canLog() else { return }
        unblockOccurred = false
        log(UIImage(ciImage: ciImage), withMessage: message)
    }
    
    /// Capture and store a UIImage
    func log(_ uiImage: UIImage, withMessage message: String) {
        guard canLog() else { return }
        unblockOccurred = false
        
        // UIImage log is the "real" log
        let now = Timestamp(date: Date())
        let id = sessionLogCount
        sessionLogCount += 1
        
        // Upload image to Storage and log info on Firestore
        uploadQueue.addOperation { [weak self] in
            guard let self = self else { return }
            
            // Fix orientation if requested
            let imageToUpload = self.shouldFixOrientationBeforeUpload ? self.redrawImageFromFlaggedOrientation(uiImage) : uiImage
            
            // Convert UIImage to JPEG data, then upload
            if let data = self.jpegData(imageToUpload, compressionQuality: 1.0) {
                self.uploadImage(data, withID: id) { (url) in
                    self.storeDocument(for: url, withID: id, takenAt: now, message: message)
                }
            } else {
                print("ImageDebugger failed to convert image to appropriate format. Log failed.")
            }
        }
    }
    
    /**
     Causes ImageDebugger to ignore all `log` calls for the given number of seconds.
     
     An app with live video input rarely needs to debug every single frame, and one that does would likely feel a performance hit, so `blockLogsFor(_:)` can be used in conjunction with `logsBlockedUntil` to only log frames every few seconds.
     
     # Example
     ~~~
     let debugger = ImageDebugger.shared
     func videoStream(didOutput frame: CVPixelBuffer) {
        let newFrame = self.doImageProcessing(on: frame)
     
        // Try logging my newFrame.
        // Will succeed if debugger.logsBlockedUntil is nil.
        debugger.log(newFrame, withMessage: "Processed image.")
     
        // If log succeeded, block future logs for 4 seconds.
        if debugger.logsBlockedUntil == nil {
            debugger.blockLogsFor(4)
        }
     }
     ~~~
     */
    func blockLogsFor(_ seconds: TimeInterval) {
        guard seconds > 0 else { return }
        
        if logsBlockedUntil == nil {
            logsBlockedUntil = Date().addingTimeInterval(seconds)
        } else {
            // Blocks should compound
            logsBlockedUntil!.addTimeInterval(seconds)
        }
        
        unblockOccurred = false
    }
    
    /**
     Unlike `blockLogsFor(_:)`, which blocks all logs for a given time, this blocks the next `count` calls.
     
     If you use both methods, ImageDebugger will start logging when the last constraint is lifted. For example, `blockLogsFor(5)` followed by `blockNextLogs(10)` will allow a `log` call after five seconds or after ten counted `log` calls, whichever comes last.
     
     While `blockLogsFor(_:)` can be useful for simple blocking, this method allows for fine precision. For example, if you have a live video input that makes three calls, then `blockNextLogs(12)` will block four frames exactly.
     
     - Important: Blocking compounds. Make sure to use `logsLeftForUnblock` and `unblockOccurred` to avoid an infinite block. Consider the following live video input example:
     ~~~
     let debugger = ImageDebugger.shared
     func videoStream(didOutput frame: CVPixelBuffer) {
        let newFrame = self.doImageProcessing(on: frame)
     
        // Try logging my newFrame.
        // Will succeed if debugger.logsLeftForUnblock is 0.
        debugger.log(newFrame, withMessage: "Processed image.")
     
        // If log succeeded, block logs for the next three frames.
        if debugger.logsLeftForUnblock == 0 {
            debugger.blockNextLogs(3)
        }
     }
     ~~~
     Though this code works for `blockLogsFor(_:)`, in this case it creates an infinite block. We log once, then block three frames. The next three `log` calls go by, and after the third, the ImageDebugger is unblocked. Our next `log` call should go through. However, `logsLeftForUnblock == 0`, so the if statement evaluates to `true` and we call `block` again. Instead, we should also use `unblockOccurred` to ensure that we don't call `block` when an unblock has just happened. This would be the correct if statement for the code above:
     
     `if debugger.logsLeftForUnblock == 0 && !debugger.unblockOccurred`
     */
    func blockNextLogs(_ count: Int) {
        guard count > 0 else { return }
        logsLeftForUnblock += count
        unblockOccurred = false
    }
    
    /// Returns true if logs are not blocked. Also handles progression towards unblock.
    private func canLog() -> Bool {
        if logsLeftForUnblock > 0 {
            let currentValue = logsLeftForUnblock
            logsLeftForUnblock -= 1
            
            // If next log will be allowed, mark unblockOccurred
            if logsLeftForUnblock == 0 && logsBlockedUntil == nil {
                unblockOccurred = true
            }
            
            // BLOCK if there are (were) still logs left
            if currentValue > 0 {
                return false
            }
        }
        
        // Passed the # of logs check, now look at the time left
        if let logsBlockedUntil = logsBlockedUntil {
            // BLOCK if there is still time left
            if Date() < logsBlockedUntil {
                return false
            }
            
            // O/w unblock
            self.logsBlockedUntil = nil
            self.unblockOccurred = true
        }
        
        // ALL CHECKS PASSED
        return true
    }
    
    /// Bakes the `imageOrientation` value into the drawing of a UIImage.
    /// UIImage must be backed by an underlying CGImage.
    private func redrawImageFromFlaggedOrientation(_ image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        
        if image.imageOrientation == .up { return image }
        
        var transform = CGAffineTransform.identity
        
        // Capture orientation
        switch image.imageOrientation {
        case .down, .downMirrored:
            transform = transform.translatedBy(x: image.size.width, y: image.size.height)
            transform = transform.rotated(by: .pi)
        case .left, .leftMirrored:
            transform = transform.translatedBy(x: image.size.width, y: 0)
            transform = transform.rotated(by: .pi / 2)
        case .right, .rightMirrored:
            transform = transform.translatedBy(x: 0, y: image.size.height)
            transform = transform.rotated(by: -.pi / 2)
        default:
            break
        }
        
        // Capture mirror
        switch image.imageOrientation {
        case .upMirrored, .downMirrored:
            transform.translatedBy(x: image.size.width, y: 0)
            transform.scaledBy(x: -1, y: 1)
        case .leftMirrored, .rightMirrored:
            transform.translatedBy(x: image.size.height, y: 0)
            transform.scaledBy(x: -1, y: 1)
        default:
            break
        }
        
        // Re-draw
        if let context = CGContext(data: nil, width: Int(image.size.width), height: Int(image.size.height), bitsPerComponent: cgImage.bitsPerComponent, bytesPerRow: 0, space: cgImage.colorSpace!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
            
            context.concatenate(transform)
            
            switch image.imageOrientation {
            case .left, .leftMirrored, .right, .rightMirrored:
                context.draw(cgImage, in: CGRect(x: 0, y: 0, width: image.size.height, height: image.size.width))
            default:
                context.draw(cgImage, in: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))
            }
            
            if let finalImage = context.makeImage() {
                return UIImage(cgImage: finalImage)
            }
        }
        
        // Failed
        return image
    }
    
    /// Get JPEG data from a UIImage
    private func jpegData(_ image: UIImage, compressionQuality: CGFloat) -> Data? {
        return autoreleasepool { () -> Data? in
            return image.jpegData(compressionQuality: compressionQuality)
        }
    }
    
    /// Upload image to Cloud Storage
    private func uploadImage(_ data: Data,
                             withID id: Int,
                             completion: @escaping (URL) -> ()) {
        // Image name corresponds to the moment it was taken
        let ref = storageSessionRef.child("\(id).jpeg")
        
        ref.putData(data, metadata: nil) { (_, error) in
            if let error = error {
                print("ImageDebugger failed to upload image. \(error.localizedDescription)")
                return
            }
            
            // Retreive the long URL
            ref.downloadURL { (url, error) in
                if let error = error {
                    print("ImageDebugger failed to retreive long URL. \(error.localizedDescription)")
                    return
                }
                
                guard let url = url else {
                    print("ImageDebugger failed to safely unwrap long URL.")
                    return
                }
                
                completion(url)
            }
        }
    }
    
    /// Upload image details and log message to Firestore
    private func storeDocument(for imageURL: URL,
                               withID id: Int,
                               takenAt timestamp: Timestamp,
                               message: String) {
        databaseSessionRef.document(String(id)).setData([
            "link" : imageURL.absoluteString,
            "captureTime" : timestamp,
            "message" : message
        ])
    }
}
