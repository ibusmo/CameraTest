//
//  VideoEditor.swift
//  CameraTest
//
//  Created by Cpt. Omsub Sukkhee on 2/15/17.
//  Copyright © 2017 omsubusmo. All rights reserved.
//

import UIKit
import Foundation
import AVFoundation
import MobileCoreServices

class VideoEditor: NSObject {
    
    class func crop(asset: AVAsset) {
        
        let deletTempFileResult = deleteTempFile()
        let isClearTempFile: Bool = deletTempFileResult.0
        let destinationURL: NSURL = deletTempFileResult.1
        
        print("cropVideo() \nsource: \(asset) \ndestination: \(destinationURL)")
    
        if (!isClearTempFile) {
            print("cropVideo() - problem with deleteTempFile()")
            return ;
        }
        
        if (!isCompatiblePresets(asset: asset)) {
            print("cropVideo() - problem with checkCompatiblePresets()")
            return ;
        }
        
        if (!isAssetReady(asset: asset)) {
            print("cropVideo() - Cannot extract video track")
            return ;
        }
        
        let assetVideoTrack: AVAssetTrack = asset.tracks(withMediaType: AVMediaTypeVideo).first!
        let transformOrientation: CGAffineTransform = assetVideoTrack.preferredTransform
        
        // setup time range
        let start: CMTime               = kCMTimeZero
        let duration: CMTime            = CMTimeMakeWithSeconds(Float64(CMTimeGetSeconds(asset.duration)), asset.duration.timescale)
        let timeRangeForCurrentSlice    = CMTimeRangeMake(start, duration)
        
        let transformer: AVMutableVideoCompositionLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: assetVideoTrack)
        transformer.setTransform(transformOrientation, at: kCMTimeZero)
        
        let instruction: AVMutableVideoCompositionInstruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = timeRangeForCurrentSlice
        instruction.layerInstructions = NSArray(object: transformer) as [AnyObject] as [AnyObject] as! [AVVideoCompositionLayerInstruction]
        
        let videoComposition: AVMutableVideoComposition = AVMutableVideoComposition()
        videoComposition.frameDuration = CMTimeMake(1, 30)
        videoComposition.renderSize = CGSize(width: 360, height: 360)
        videoComposition.instructions = NSArray(object: instruction) as [AnyObject] as [AnyObject] as! [AVVideoCompositionInstructionProtocol]
        
        // Export by passthrough preset and compsiton with video, audio
        let exportSession: AVAssetExportSession? = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetMediumQuality)
        exportSession?.videoComposition         = videoComposition
        exportSession?.outputURL                = destinationURL as URL
        exportSession?.outputFileType           = AVFileTypeQuickTimeMovie
        exportSession?.shouldOptimizeForNetworkUse = true

        export(destinationURL: destinationURL, exportSession: exportSession)
    }
    
    class func export(destinationURL: NSURL, exportSession: AVAssetExportSession?) {
        
        if exportSession == nil {
            print("export() nil")
            return ;
        }
        
        exportSession!.exportAsynchronously(completionHandler: { () -> Void in
            
            switch (exportSession!.status) {
            case .failed:
                print("export() failed")
                print(exportSession!.error?.localizedDescription as Any)
                
            case .cancelled:
                print("export() canceled")
                
            case .completed:
                print("export() completed")
                DispatchQueue.main.async(execute: {
                    // copy asset to Photo Libraries
                    UISaveVideoAtPathToSavedPhotosAlbum(destinationURL.relativePath!, self, #selector(VideoEditor.video(videoPath:didFinishSavingWithError:contextInfo:)), nil)
                    
                })
                
            default:
                print("export() not completed")
                
            }
            
        })
        
    }
    
    @objc class func video(videoPath: NSString, didFinishSavingWithError error: NSError?, contextInfo info: AnyObject) {
        if (error != nil) {
            print("Saved to photos ablum: \(error?.localizedDescription)")
        } else {
            print("Saved to photos ablum: success")
        }
        
        // Clear video temp file
        if (!deleteTempFile().0) {
            print("cropVideo() - problem with deleteTempFile()")
        }
    }
    
    class func isCompatiblePresets(asset: AVAsset) -> Bool {
        let compatiblePresets = AVAssetExportSession.exportPresets(compatibleWith: asset)
        if (compatiblePresets.contains(AVAssetExportPresetMediumQuality)) {
            return true
        }
        return false
    }
    
    class func isAssetReady(asset: AVAsset) -> Bool {
        let assetVideoTrack: AVAssetTrack? = asset.tracks(withMediaType: AVMediaTypeVideo).first
        if let _ = assetVideoTrack {
            return true
        }
        return false
    }
    
    class func getDestinationURL() -> NSURL {
        let tempVideoPath: String = NSTemporaryDirectory().appending("tempExportMovie.mov") as String
        let destinationURL: NSURL = NSURL(fileURLWithPath: tempVideoPath)
        
        return destinationURL
    }
    
    class func deleteTempFile() -> (Bool, NSURL) {
        let tempVideoPath: String = NSTemporaryDirectory().appending("tempExportMovie.mov") as String
        let url: NSURL = NSURL(fileURLWithPath: tempVideoPath)
        return deleteTempFile(url: url)
    }
    
    class func deleteTempFile(url: NSURL) -> (Bool, NSURL) {
        let fm = FileManager.default
        let exist = fm.fileExists(atPath: url.path!)
        if (exist) {
            do {
                try fm.removeItem(at: url as URL)
                print("file was romeved - \(url)")
            } catch {
                print("file romeve error - \(url)")
                return (false, url)
            }
        } else {
            print("no file by that name - \(url)")
        }
        return (true, url)
    }
    
}
