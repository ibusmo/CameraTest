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

enum VideoEditorMode {
    case crop, trim
}

protocol VideoEditorDelegate {
    func cropExportOutput(success: Bool, outputFile: URL)
    func trimExportOutput(success: Bool, outputFile: URL)
}

class VideoEditor: NSObject {
    
    static var delegateB: VideoEditorDelegate?
    
    static let cropTempExportMoviePath: String = NSTemporaryDirectory().appending("cropTempExportMovie.mov")     as String
    static let trimTempExportMoviePath: String = NSTemporaryDirectory().appending("trimTempExportMoviePath.mov") as String
    
    class func crop(url : URL, delegate: VideoEditorDelegate?) {
        let asset = AVAsset(url: url)
        crop(asset: asset, delegate: delegate)
    }
    
    class func crop(asset: AVAsset, delegate: VideoEditorDelegate?) {
        
        delegateB = delegate
        
        let deletTempFileResult = deleteTempFile(mode: .crop)
        let isClearTempFile: Bool = deletTempFileResult.0
        let destinationURL: NSURL = deletTempFileResult.1
        
        print("VideoEditor: cropVideo() \nsource: \(asset) \ndestination: \(destinationURL)")
    
        if (!isClearTempFile) {
            print("VideoEditor: cropVideo() - problem with deleteTempFile()")
            delegateB?.cropExportOutput(success: false, outputFile: destinationURL as URL)
            return ;
        }
        
        if (!isCompatiblePresets(asset: asset)) {
            print("VideoEditor: cropVideo() - problem with checkCompatiblePresets()")
            delegateB?.cropExportOutput(success: false, outputFile: destinationURL as URL)
            return ;
        }
        
        if (!isAssetReady(asset: asset)) {
            print("VideoEditor: cropVideo() - Cannot extract video track")
            delegateB?.cropExportOutput(success: false, outputFile: destinationURL as URL)
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
            delegateB?.cropExportOutput(success: false, outputFile: destinationURL as URL)
            return ;
        }
        
        exportSession!.exportAsynchronously(completionHandler: { () -> Void in
            
            switch (exportSession!.status) {
                case .failed:
                    print("VideoEditor: export() failed")
                    print(exportSession!.error?.localizedDescription as Any)
                    delegateB?.cropExportOutput(success: false, outputFile: destinationURL as URL)
                    
                case .cancelled:
                    print("VideoEditor: export() canceled")
                    delegateB?.cropExportOutput(success: false, outputFile: destinationURL as URL)
                    
                case .completed:
                    print("VideoEditor: export() completed")
                    //OUTPUT
                    delegateB?.cropExportOutput(success: true, outputFile: destinationURL as URL)
                    
                    DispatchQueue.main.async(execute: {
                        // copy asset to Photo Libraries
                        UISaveVideoAtPathToSavedPhotosAlbum(destinationURL.relativePath!, self, #selector(VideoEditor.video(videoPath:didFinishSavingWithError:contextInfo:)), nil)
                        
                    })
                
            default:
                print("VideoEditor: export() not completed")
                delegateB?.cropExportOutput(success: false, outputFile: destinationURL as URL)
                
            }
            
        })
        
    }
    
    class func video(videoPath: NSString, didFinishSavingWithError error: NSError?, contextInfo info: AnyObject) {
        if (error != nil) {
            print("VideoEditor: Saved to photos ablum: \(error?.localizedDescription)")
        } else {
            print("VideoEditor: Saved to photos ablum: success")
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
    
    class func deleteTempFile(mode: VideoEditorMode) -> (Bool, NSURL) {
        if (mode == .crop) {
            let url: NSURL = NSURL(fileURLWithPath: cropTempExportMoviePath)
            return deleteTempFile(url: url)
            
        } else if (mode == .trim) {
            let url: NSURL = NSURL(fileURLWithPath: trimTempExportMoviePath)
            return deleteTempFile(url: url)
            
        } else {
            return (false, NSURL())
        }
    }
    
    class func deleteTempFile(urlString: String) -> (Bool, NSURL) {
        let url: NSURL = NSURL(fileURLWithPath: urlString)
        return deleteTempFile(url: url)
    }
    
    class func deleteTempFile(url: NSURL) -> (Bool, NSURL) {
        let fm = FileManager.default
        let exist = fm.fileExists(atPath: url.path!)
        if (exist) {
            do {
                try fm.removeItem(at: url as URL)
                print("VideoEditor: file was romeved - \(url)")
            } catch {
                print("VideoEditor: file romeve error - \(url)")
                return (false, url)
            }
        } else {
            print("VideoEditor: no file by that name - \(url)")
        }
        return (true, url)
    }
    
}
