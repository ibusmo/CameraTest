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
protocol PetPolarCameraVideoViewControllerDelegate {
    func dismissViewController()
}

class PetPolarVideoTrimmerViewController: UIViewController {
    
    var delegate: PetPolarCameraVideoViewControllerDelegate?
    
    @IBOutlet weak var backNavigationButton: UIButton!
    @IBOutlet weak var muteButton: UIButton!
    @IBOutlet weak var nextButton: UIButton!
    
    @IBOutlet weak var videoPreviewView: UIView!
    @IBOutlet weak var trimmerView: UIView!
    
    @IBOutlet weak var trimModeButton: UIButton!
    @IBOutlet weak var coverModeButton: UIButton!
    
    // Trimmer Layer
    var trimmerLayer = ICGVideoTrimmerView()
    
    // Trimer setting
    let minLength: CGFloat = 3.0
    let maxLength: CGFloat = 15.0
    
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
    var duration: CGFloat = 0.0
    
    // mark - source asset
    var asset: AVAsset?
    var url: URL?
    // mark - tempolary asset
    let tempVideoPath: String = NSTemporaryDirectory().appending("tmpMov.mov") as String
    var exportSession: AVAssetExportSession?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // let sound able to play in iPhone silent mode
        try! AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback, with: [])
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
    
    @IBAction func trimDidTap(_ sender: Any) {
        self.dismissViewController()
    }
    
    func dismissViewController() {
        self.setVideoState(status: false)
        self.player = nil
        self.playerItem = nil
        self.playerLayer = nil
        self.dismiss(animated: true, completion: {
            print("PetPolarVideoTrimmerViewController: delegate")
            self.delegate?.dismissViewController()
        })
    }
    
    func trimVideo() {
        self.deleteTepmFile()
        let destinationURL: NSURL = NSURL(fileURLWithPath: self.tempVideoPath)
        
        if let url = self.url, let asset = self.asset {
            
            print("trimVideo() start \(self.tempVideoPath)")
            self.nextButton.isHidden = true
            
            let preferredPreset = AVAssetExportPresetPassthrough
            let options = [ AVURLAssetPreferPreciseDurationAndTimingKey: true ]
            let sourceAsset = AVURLAsset(url: url, options: options)
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
//                self.exportSession?.timeRange = timeRangeForCurrentSlice
                self.exportSession?.exportAsynchronously(completionHandler: { () -> Void in
                    
                    print("trimVideo() finish")
                    self.nextButton.isHidden = false
                    
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
                            let movieUrl: NSURL = NSURL(fileURLWithPath: self.tempVideoPath)
                            UISaveVideoAtPathToSavedPhotosAlbum(movieUrl.relativePath!, self, #selector(PetPolarVideoTrimmerViewController.video(videoPath:didFinishSavingWithError:contextInfo:)), nil)
                        })
                    }
                })
            } else {
                print("trimVideo() cannot trim cause url, asset nil")
            }
        }
    }
    
    func deleteTepmFile() {
        let url: NSURL = NSURL(fileURLWithPath: self.tempVideoPath)
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
        if let url = self.url, let asset = self.asset {
            // setup video previewer
            self.playerLayer?.removeFromSuperlayer()
            let item: AVPlayerItem = AVPlayerItem(asset: asset)
            self.player = AVPlayer(playerItem: item)
            self.playerLayer = AVPlayerLayer(player: self.player)
            self.playerLayer?.frame = CGRect(x: 0, y: 0, width: self.videoPreviewView.frame.width, height: self.videoPreviewView.frame.height)
            self.playerLayer?.videoGravity = AVLayerVideoGravityResizeAspectFill
            self.player?.actionAtItemEnd = AVPlayerActionAtItemEnd.none
            DispatchQueue.main.async {
                self.videoPreviewView.layer.addSublayer(self.playerLayer!)
            }
            // setup video previwer gesture play/pause toggle
            let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(PetPolarVideoTrimmerViewController.tapOnVideoLayer))
            self.videoPreviewView.addGestureRecognizer(tap)
            
            // set up video player, additional
            self.duration = CGFloat(CMTimeGetSeconds(self.player!.currentItem!.asset.duration))
            self.videoPlaybackPosition = 0.0
            self.startTime = 0.0
            self.stopTime = self.duration < self.maxLength ? self.duration : self.maxLength
            self.setSoundState(status: true)
            self.setVideoState(status: true)
            
            // set properties for trimmer view
            self.trimmerLayer.removeFromSuperview()
            self.trimmerLayer.frame = CGRect(x: 0, y: 0, width: self.trimmerView.frame.width, height: self.trimmerView.frame.height)
            self.trimmerLayer.themeColor = UIColor.lightGray
            self.trimmerLayer.trackerColor = UIColor.white
            self.trimmerLayer.thumbWidth = 15.0
            self.trimmerLayer.asset = asset
            self.trimmerLayer.showsRulerView = true
            self.trimmerLayer.isHidden = false
            self.trimmerLayer.minLength = self.duration < self.minLength ? self.duration : self.minLength
            self.trimmerLayer.maxLength = self.duration < self.maxLength ? self.duration : self.maxLength
            self.trimmerLayer.delegate = self
            
            // important: reset subviews
            self.trimmerLayer.resetSubviews()
            
            self.trimmerView.addSubview(self.trimmerLayer)
            
            print("duration:\(duration)")
            print("startTime:\(self.startTime) stopTime:\(self.stopTime)")
            print("minLength:\(self.minLength) maxLength:\(self.maxLength)")
            print("minLength:\(self.trimmerLayer.minLength) maxLength:\(self.trimmerLayer.maxLength)")
        } else {
            print("setupTrimmerView() cannot setup trimmer view cause url, asset nil")
        }
    }
    
}

extension PetPolarVideoTrimmerViewController: UINavigationControllerDelegate {
    
}

extension PetPolarVideoTrimmerViewController: ICGVideoTrimmerDelegate {
    
    // mark - ICGVideoTrimmerDelegate
    
    func trimmerView(_ trimmerView: ICGVideoTrimmerView!, didChangeLeftPosition startTime: CGFloat, rightPosition endTime: CGFloat) {
        print("trimmerView didChangeLeftPosition \(startTime) \(endTime)")
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
        self.isSoundAble = !self.isSoundAble
        self.setSoundState(status: self.isSoundAble)
    }
    
    func setSoundState(status: Bool) {
        self.isSoundAble = status
        if (status == true) {
            self.player?.volume = 1.0
            self.muteButton.setTitle("Mute", for: UIControlState.normal)
            
        } else if (status == false) {
            self.player?.volume = 0.0
            self.muteButton.setTitle("Unmute", for: UIControlState.normal)
        }
    }
    
    func tapOnVideoLayer() {
        self.isPlaying = !self.isPlaying
        self.setVideoState(status: self.isPlaying)
    }
    
    func setVideoState(status: Bool) {
        self.isPlaying = status
        if (status == true) {
            self.player?.play()
            self.startPlaybackTimeChecker()
        } else if (status == false) {
            self.player?.pause()
            self.stopPlaybackTimeChecker()
        }
        self.trimmerLayer.hideTracker(!status)
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
        if let player = self.player {
            let currentPlayingTime = CGFloat(CMTimeGetSeconds(player.currentTime()))
            self.videoPlaybackPosition = currentPlayingTime
            
            if self.videoPlaybackPosition >= self.startTime && self.videoPlaybackPosition < self.stopTime {
                self.trimmerLayer.seek(toTime: currentPlayingTime)
            } else if self.videoPlaybackPosition >= self.stopTime {
                self.seekVideoToPos(pos: self.startTime)
            }
        }
    }
    
    func seekVideoToPos(pos: CGFloat) {
//        print("seekVideoToPos() pos: \(pos)")
        if let player = self.player {
            self.videoPlaybackPosition = pos
            let time: CMTime = CMTimeMakeWithSeconds(Float64(pos), player.currentTime().timescale)
            
            self.player?.seek(to: time, toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimeZero)
            self.trimmerLayer.seek(toTime: self.startTime)
        }
    }
    
}
