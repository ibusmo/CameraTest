//
//  PetPolarVideoTrimmerViewController.swift
//  CameraTest
//
//  Created by Cpt. Omsub Sukkhee on 1/19/17.
//  Copyright © 2017 omsubusmo. All rights reserved.
//

import UIKit
import Foundation
import AVFoundation
import MobileCoreServices
import ICGVideoTrimmer

protocol PetPolarVideoTrimmerVideoPlayerDelegate {}

class PetPolarVideoTrimmerViewController: UIViewController {
    
    @IBOutlet weak var backNavigationButton: UIButton!
    @IBOutlet weak var muteButton: UIButton!
    @IBOutlet weak var nextButton: UIButton!
    
    @IBOutlet weak var videoPreviewView: UIView!
    @IBOutlet weak var trimmerView: UIView!
    
    @IBOutlet weak var trimModeButton: UIButton!
    @IBOutlet weak var coverModeButton: UIButton!
    
    // Trimmer Layer
    var trimmerLayer = ICGVideoTrimmerView()
    
    // Video Player
    var isPlaying: Bool = false
    var isSoundAble: Bool = false
    var player: AVPlayer?
    var playerItem: AVPlayerItem?
    var playerLayer: AVPlayerLayer?
    var playbackTimeCheckerTimer: Timer?
    var videoPlaybackPosition: CGFloat = 0.0
    var startTime: CGFloat = 0.0
    var stopTime: CGFloat = 0.0
    
    // mark - source asset
    var asset: AVAsset?
    var url: URL?
    // mark - tempolary asset
    var tempVideoPath: NSString?
    var exportSession: AVAssetExportSession?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // let sound able to play in iPhone silent mode
        try! AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback, with: [])
        
        self.tempVideoPath = NSTemporaryDirectory().appending("tmpMov.mov") as NSString?
        
        self.selectAsset()
    }
    
    // mark - user event
    
    @IBAction func backNavigationDidTap(_ sender: Any) {
        self.selectAsset()
    }
    
    @IBAction func soundToggleDidTap(_ sender: Any) {
        self.soundToggle()
    }
    
    @IBAction func nextDidTap(_ sender: Any) {
        self.trimVideo()
    }
    
    func trimVideo() {
        self.deleteTepmFile()
        let destinationURL: NSURL = NSURL(fileURLWithPath: self.tempVideoPath as! String)
        
        if (self.asset != nil && self.url != nil) {
            
            self.nextButton.isHidden = true
            
            let preferredPreset = AVAssetExportPresetPassthrough
            let options = [ AVURLAssetPreferPreciseDurationAndTimingKey: true ]
            let sourceAsset = AVURLAsset(url: self.url!, options: options)
            let compatiblePresets = AVAssetExportSession.exportPresets(compatibleWith: sourceAsset)
            
            if compatiblePresets.contains(AVAssetExportPresetMediumQuality) {
                
                let composition = AVMutableComposition()
                // destination track source
                let videoCompTrack = composition.addMutableTrack(withMediaType: AVMediaTypeVideo, preferredTrackID: CMPersistentTrackID())
                let audioCompTrack = composition.addMutableTrack(withMediaType: AVMediaTypeAudio, preferredTrackID: CMPersistentTrackID())
                
                // pointer to first track of source
                let assetVideoTrack: AVAssetTrack = sourceAsset.tracks(withMediaType: AVMediaTypeVideo).first! as AVAssetTrack
                let assetAudioTrack: AVAssetTrack = sourceAsset.tracks(withMediaType: AVMediaTypeAudio).first! as AVAssetTrack
                
                let start: CMTime       = CMTimeMakeWithSeconds(Float64(self.startTime), sourceAsset.duration.timescale)
                let duration: CMTime    = CMTimeMakeWithSeconds(Float64(self.stopTime-self.startTime), sourceAsset.duration.timescale)
                let timeRangeForCurrentSlice = CMTimeRangeMake(start, duration)
                
                // insert video, audio track into composition
                do {
                    try videoCompTrack.insertTimeRange(timeRangeForCurrentSlice, of: assetVideoTrack, at: kCMTimeZero)
                    if self.isSoundAble {
                        try audioCompTrack.insertTimeRange(timeRangeForCurrentSlice, of: assetAudioTrack, at: kCMTimeZero)
                    }
                } catch {
                    print("trimVideo() insertTimeRange error")
                }
                
                // Export by passthrough preset and compsiton with video, audio
                self.exportSession = AVAssetExportSession(asset: composition, presetName: preferredPreset)
                self.exportSession?.outputURL = destinationURL as URL
                self.exportSession?.outputFileType = AVFileTypeQuickTimeMovie
                self.exportSession?.shouldOptimizeForNetworkUse = true
                self.exportSession?.timeRange = timeRangeForCurrentSlice
                self.exportSession?.exportAsynchronously(completionHandler: { () -> Void in
                    switch self.exportSession!.status {
                    case .failed:
                        print("Export failed")
                        print(self.exportSession?.error?.localizedDescription as Any)
                    case .cancelled:
                        print("Export canceled")
                    default:
                        print("Export success")
                        // copy asset to Photo Libraries
                        DispatchQueue.main.async(execute: {
                            let movieUrl: NSURL = NSURL(fileURLWithPath: self.tempVideoPath as! String)
                            UISaveVideoAtPathToSavedPhotosAlbum(movieUrl.relativePath!, self, #selector(PetPolarVideoTrimmerViewController.video(videoPath:didFinishSavingWithError:contextInfo:)), nil)
                        })
                    }
                })
            }
        }
    }
    
    func deleteTepmFile() {
        let url: NSURL = NSURL(fileURLWithPath: self.tempVideoPath as! String)
        let fm = FileManager.default
        let exist = fm.fileExists(atPath: url.path!)
        if exist {
            do {
                try fm.removeItem(at: url as URL)
            } catch {
                print("file romeve error")
            }
        } else {
            print("no file by that name")
        }
        
        self.nextButton.isHidden = false
        
    }
    
    func video(videoPath: NSString, didFinishSavingWithError error: NSError?, contextInfo info: AnyObject) {
        var title = ""
        var message = ""
        if (error != nil) {
            title = "Failed !"
            message = "Video Saving Failed"
        } else {
            title = "Success !"
            message = "Saved To Photo Album"
        }
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.cancel, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
}

extension PetPolarVideoTrimmerViewController: UIImagePickerControllerDelegate {
    
    func selectAsset() {
        let myImagePickerController = UIImagePickerController()
        myImagePickerController.sourceType = .photoLibrary
        myImagePickerController.mediaTypes = [kUTTypeMovie as NSString as String]
        myImagePickerController.allowsEditing = false
        myImagePickerController.delegate = self
        self.present(myImagePickerController, animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        picker.dismiss(animated: true, completion: nil)
        let url = info[UIImagePickerControllerMediaURL] as! URL
        self.url = url
        self.asset = AVAsset(url: url)
        self.setupTrimmerView(url: url)
    }
    
    func setupTrimmerView(url: URL) {
        print("setupTrimmerView() url: \(url)")
        
        // setup video previewer
        self.playerLayer?.removeFromSuperlayer()
        let item: AVPlayerItem = AVPlayerItem(asset: self.asset!)
        self.player = AVPlayer(playerItem: item)
        self.playerLayer = AVPlayerLayer(player: self.player)
        self.playerLayer?.frame = CGRect(x: 0, y: 0, width: self.videoPreviewView.frame.width, height: self.videoPreviewView.frame.height)
        self.playerLayer?.videoGravity = AVLayerVideoGravityResizeAspectFill
        self.player?.actionAtItemEnd = AVPlayerActionAtItemEnd.none
        DispatchQueue.main.async {
            self.videoPreviewView.layer.addSublayer(self.playerLayer!)
        }
        self.player?.play()
        
        // setup video previwer gesture play/pause toggle
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(PetPolarVideoTrimmerViewController.tapOnVideoLayer))
        self.videoPreviewView.addGestureRecognizer(tap)
        
        self.videoPlaybackPosition = 0.0
        self.startTime = 0.0
        self.stopTime = 15.0
        self.soundToggle()
        self.tapOnVideoLayer()
        
        // set properties for trimmer view
        self.trimmerLayer.removeFromSuperview()
        self.trimmerLayer.frame = CGRect(x: 0, y: 0, width: self.trimmerView.frame.width, height: self.trimmerView.frame.height)
        self.trimmerLayer.themeColor = UIColor.lightGray
        self.trimmerLayer.trackerColor = UIColor.white
        self.trimmerLayer.thumbWidth = 15.0
        self.trimmerLayer.asset = self.asset
        self.trimmerLayer.showsRulerView = true
        self.trimmerLayer.isHidden = false
        self.trimmerLayer.minLength = 3.0
        self.trimmerLayer.maxLength = 15.0
        self.trimmerLayer.delegate = self
        
        // important: reset subviews
        self.trimmerLayer.resetSubviews()
        self.trimmerLayer.backgroundColor = UIColor.gray
        
        self.trimmerView.addSubview(self.trimmerLayer)
        
    }
    
}

extension PetPolarVideoTrimmerViewController: UINavigationControllerDelegate {
    
}

extension PetPolarVideoTrimmerViewController: ICGVideoTrimmerDelegate {
    
    // mark - ICGVideoTrimmerDelegate
    
    func trimmerView(_ trimmerView: ICGVideoTrimmerView!, didChangeLeftPosition startTime: CGFloat, rightPosition endTime: CGFloat) {
        if startTime != self.startTime {
            // Move the left position to rearrange the bar
            self.seekVideoToPos(pos: startTime)
        }
        self.startTime = startTime
        self.stopTime = endTime
    }
}

extension PetPolarVideoTrimmerViewController: PetPolarVideoTrimmerVideoPlayerDelegate {
    
    func soundToggle() {
        if self.isSoundAble {
            self.player?.volume = 0.0
            self.muteButton.setTitle("Unmute", for: UIControlState.normal)
        } else {
            self.player?.volume = 1.0
            self.muteButton.setTitle("Mute", for: UIControlState.normal)
        }
        self.isSoundAble = !self.isSoundAble
    }
    
    func tapOnVideoLayer() {
        if self.isPlaying {
            self.player?.pause()
            self.stopPlaybackTimeChecker()
        } else {
            self.player?.play()
            self.startPlaybackTimeChecker()
        }
        self.isPlaying = !self.isPlaying
        self.trimmerLayer.hideTracker(!isPlaying)
    }
    
    func stopPlaybackTimeChecker() {
        if (self.playbackTimeCheckerTimer != nil) {
            self.playbackTimeCheckerTimer?.invalidate()
            self.playbackTimeCheckerTimer = nil
        }
    }
    
    func startPlaybackTimeChecker() {
        self.playbackTimeCheckerTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(PetPolarVideoTrimmerViewController.onPlaybackTimeCheckerTimer), userInfo: nil, repeats: true)
    }
    
    // mark - PlaybackTimeCheckerTimer
    
    func onPlaybackTimeCheckerTimer() {
        let currentPlayingTime = CGFloat(CMTimeGetSeconds(self.player!.currentTime()))
        self.videoPlaybackPosition = currentPlayingTime
        
        if self.videoPlaybackPosition >= self.startTime && self.videoPlaybackPosition < self.stopTime {
            self.trimmerLayer.seek(toTime: currentPlayingTime)
        } else if self.videoPlaybackPosition >= self.stopTime {
            self.seekVideoToPos(pos: self.startTime)
        }
    }
    
    func seekVideoToPos(pos: CGFloat) {
        print("seekVideoToPos() pos: \(pos)")
        self.videoPlaybackPosition = pos
        let time: CMTime = CMTimeMakeWithSeconds(Float64(pos), self.player!.currentTime().timescale)
        
        self.player?.seek(to: time, toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimeZero)
        self.trimmerLayer.seek(toTime: self.startTime)
    }
    
}
