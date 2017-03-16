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

enum EditMode {
    case start, trim, cover
}

protocol PetPolarVideoTrimmerVideoPlayerDelegate {}
protocol PetPolarVideoTrimmerViewControllerDelegate {
    func trimmerDismissViewController()
}

class PetPolarVideoTrimmerViewController: UIViewController {
    
    var delegate: PetPolarVideoTrimmerViewControllerDelegate?
    
    // navigation view controller
    @IBOutlet weak var backNavigationButton: UIButton!
    @IBOutlet weak var muteButton: UIButton!
    @IBOutlet weak var nextButton: UIButton!
    // video view controller
    @IBOutlet weak var videoPreviewView: UIView!
    @IBOutlet weak var trimmerActionView: UIView!
    @IBOutlet weak var trimmerView: UIView!
    // cover view controller
    @IBOutlet weak var coverActionView: UIView!
    @IBOutlet weak var coverCollectionView: UICollectionView!
    @IBOutlet weak var coverBarView: UIView!
    @IBOutlet weak var coverPointButton: UIButton!
    // button view controller
    @IBOutlet weak var trimModeButton: UIButton!
    @IBOutlet weak var coverModeButton: UIButton!
    @IBOutlet weak var trimmerModeUnderView: UIView!
    @IBOutlet weak var coverModeUnderView: UIView!
    
    // Trimmer Layer
    var trimmerLayer = ICGVideoTrimmerView()
    
    // Edit mode
    var editMode: EditMode = .start
    
    // Trimer setting
    let minLength: CGFloat = 3.0
    let maxLength: CGFloat = 15.0
    
    // Video Player
    var isPlaying: Bool = false
    var isSoundAble: Bool = false
    var player: AVPlayer?
    var playerItem: AVPlayerItem?
    var playerLayer: AVPlayerLayer?
    var playerLayerCover: AVPlayerLayer?
    var playbackTimeCheckerTimer: Timer?
    var videoPlaybackPosition: CGFloat = 0.0
    var startTime: CGFloat = 0.0
    var stopTime: CGFloat = 0.0
    var duration: CGFloat = 0.0
    // Video Player Cover
    var coverAtPercent: CGFloat = 0.0
    var coverAtTime: CGFloat = 0.0
    
    // cover image
    var numberOfSampleCover: Int = 0
    var sampleCovers = [UIImage]()
    var coverImage: UIImage?
    
    // mark - source asset
    var asset: AVAsset?
    var url: URL?
    // mark - tempolary asset
    let tempVideoPath: String = NSTemporaryDirectory().appending("trimTempExportMoviePath.mp4") as String
    var exportSession: AVAssetExportSession?
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UIApplication.shared.setStatusBarHidden(false, with: UIStatusBarAnimation.fade)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.coverCollectionView.dataSource = self
        self.coverCollectionView.delegate = self
        self.coverCollectionView.register(UINib(nibName: "CoverCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "CoverCollectionViewCell")
        
        self.numberOfSampleCover = Int(ceilf(Float(self.coverCollectionView.frame.width)/60.0))
        
        // let sound able to play in iPhone silent mode
        try! AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback, with: [])
        
        self.trimModeButton.addTarget(self, action: #selector(PetPolarVideoTrimmerViewController.trimmerModeDidTap), for: UIControlEvents.touchUpInside)
        self.coverModeButton.addTarget(self, action: #selector(PetPolarVideoTrimmerViewController.coverModeDidTap), for: UIControlEvents.touchUpInside)
        self.backNavigationButton.addTarget(self, action: #selector(PetPolarVideoTrimmerViewController.closeViewController), for: UIControlEvents.touchUpInside)
        self.muteButton.addTarget(self, action: #selector(PetPolarVideoTrimmerViewController.soundToggle), for: UIControlEvents.touchUpInside)
        self.nextButton.addTarget(self, action: #selector(PetPolarVideoTrimmerViewController.nextFinish), for: UIControlEvents.touchUpInside)
        
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(PetPolarVideoTrimmerViewController.handleLongPress(longPress:)))
        longPress.minimumPressDuration = 0.01
        self.coverPointButton.addGestureRecognizer(longPress)

        self.trimmerModeDidTap()

        self.coverPointButton.layer.borderWidth = 1.0
        self.coverPointButton.layer.borderColor = UIColor.white.cgColor
        self.coverCollectionView.alpha = 0.3
        self.coverCollectionView.layer.borderWidth = 0.5
        self.coverCollectionView.layer.borderColor = UIColor.white.cgColor
        
        if (self.url != nil) {
            self.setupAssetPicker(url: self.url!)
        }
    }
    
    // mark - user event
    
    @IBAction func selectAsset(_ sender: Any) {
        self.selectAsset()
    }
    
    func nextFinish() {
        self.trimVideo()
        self.getCoverImage()
    }
    
    func closeViewController() {
        self.setVideoState(status: false)
        self.player = nil
        self.playerItem = nil
        self.playerLayer = nil
        self.playerLayerCover = nil
        UIApplication.shared.setStatusBarHidden(false, with: UIStatusBarAnimation.fade)
        self.dismiss(animated: true, completion: {
            print("PetPolarVideoTrimmerViewController: delegate")
            self.delegate?.trimmerDismissViewController()
            self.hideLoadingView()
        })
    }

    func showLoadingView() {
        print("showLoadingView() ------------------------------------------------------------------------------------------ BLOCKING VIEW")
    }

    func hideLoadingView() {
        print("hideLoadingView() ------------------------------------------------------------------------------------------ UNBLOCK VIEW")
    }   

    func coverModeDidTap() {
        if self.editMode != .cover && self.isAssetExist() {
            self.editMode = .cover
            self.coverActionView.isHidden = false
            self.trimmerActionView.isHidden = true
            
            self.coverModeButton.setTitleColor(UIColor.blue, for: UIControlState.normal)
            self.coverModeButton.setTitleColor(UIColor.blue, for: UIControlState.highlighted)
            self.trimModeButton.setTitleColor(UIColor.white, for: UIControlState.normal)
            self.trimModeButton.setTitleColor(UIColor.white, for: UIControlState.highlighted)
            
            self.coverModeUnderView.isHidden = false
            self.trimmerModeUnderView.isHidden = true
            
            self.getSampleCoverImages()
            
            self.setVideoState(status: false)
            print("cover at time: \(self.coverAtTime)")
            self.seekVideoToPos(pos: self.coverAtTime)
        }
    }
    
    func trimmerModeDidTap() {
        if self.editMode != .trim {
            self.editMode = .trim
            self.coverActionView.isHidden = true
            self.trimmerActionView.isHidden = false
            
            self.coverModeButton.setTitleColor(UIColor.white, for: UIControlState.normal)
            self.coverModeButton.setTitleColor(UIColor.white, for: UIControlState.highlighted)
            self.trimModeButton.setTitleColor(UIColor.blue, for: UIControlState.normal)
            self.trimModeButton.setTitleColor(UIColor.blue, for: UIControlState.highlighted)
            
            self.coverModeUnderView.isHidden = true
            self.trimmerModeUnderView.isHidden = false
            
            self.setVideoState(status: true)
            print("trimmer start at time: \(self.startTime)")
            self.seekVideoToPos(pos: self.startTime)
        }
    }
    
}

extension PetPolarVideoTrimmerViewController: UIImagePickerControllerDelegate {
    
    func isAssetExist() -> Bool {
        if let _ = self.url, let _ = self.asset {
            return true
        } else {
            return false
        }
    }
    
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
        self.setupAssetPicker(url: url)
    }

    func setupAssetPicker(url: URL) {
        print("setupAssetPicker() url: \(url)")
        self.url = url
        self.asset = AVAsset(url: url)
        self.setupTrimmerView(url: url)
    }
    
    func setupTrimmerView(url: URL) {
        print("setupTrimmerView() url: \(url)")
        if let url = self.url, let asset = self.asset {
            // setup video previewer
            self.playerLayer?.removeFromSuperlayer()
            self.playerLayerCover?.removeFromSuperlayer()
            let item: AVPlayerItem = AVPlayerItem(asset: asset)
            self.player = AVPlayer(playerItem: item)
            self.playerLayer = AVPlayerLayer(player: self.player)
            self.playerLayer?.frame = CGRect(x: 0, y: 0, width: self.videoPreviewView.frame.width, height: self.videoPreviewView.frame.height)
            self.playerLayer?.videoGravity = AVLayerVideoGravityResizeAspectFill
            self.playerLayerCover = AVPlayerLayer(player: self.player)
            self.playerLayerCover?.frame = CGRect(x: 0, y: 0, width: self.coverPointButton.frame.width, height: self.coverPointButton.frame.height)
            self.playerLayerCover?.videoGravity = AVLayerVideoGravityResizeAspectFill
            self.player?.actionAtItemEnd = AVPlayerActionAtItemEnd.none
            DispatchQueue.main.async {
                self.videoPreviewView.layer.addSublayer(self.playerLayer!)
                self.coverPointButton.layer.addSublayer(self.playerLayerCover!)
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
    
    func trimVideo() {
        
        VideoEditor.crop(asset: self.asset!, delegate: self)
        
        return
        
        self.deleteTepmFile()
        let destinationURL: NSURL = NSURL(fileURLWithPath: self.tempVideoPath)
        
        if let url = self.url, let asset = self.asset  {
            
            print("trimVideo() start \(self.tempVideoPath)")
            self.nextButton.isHidden = true
            
            let preferredPreset = AVAssetExportPresetPassthrough
            let options = [ AVURLAssetPreferPreciseDurationAndTimingKey: true ]
            let sourceAsset = AVURLAsset(url: url, options: options)
            let compatiblePresets = AVAssetExportSession.exportPresets(compatibleWith: sourceAsset)
            
            if compatiblePresets.contains(AVAssetExportPresetMediumQuality) {
                
                // setup time range
                let start: CMTime       = CMTimeMakeWithSeconds(Float64(self.startTime), sourceAsset.duration.timescale)
                let duration: CMTime    = CMTimeMakeWithSeconds(Float64(self.stopTime-self.startTime), sourceAsset.duration.timescale)
                let timeRangeForCurrentSlice = CMTimeRangeMake(start, duration)
                
                let composition = AVMutableComposition()
                // destination track source
                let videoCompTrack: AVMutableCompositionTrack = composition.addMutableTrack(withMediaType: AVMediaTypeVideo, preferredTrackID: CMPersistentTrackID())
                let audioCompTrack: AVMutableCompositionTrack = composition.addMutableTrack(withMediaType: AVMediaTypeAudio, preferredTrackID: CMPersistentTrackID())
                
                // pointer to first track of source
                // let assetVideoTrack: AVAssetTrack = sourceAsset.tracks(withMediaType: AVMediaTypeVideo).first! as AVAssetTrack
                // let assetAudioTrack: AVAssetTrack = sourceAsset.tracks(withMediaType: AVMediaTypeAudio).first! as AVAssetTrack
                
                if let assetVideoTrack = sourceAsset.tracks(withMediaType: AVMediaTypeVideo).first {
                    // insert video, audio track into composition
                    do {
                        try videoCompTrack.insertTimeRange(timeRangeForCurrentSlice, of: assetVideoTrack, at: kCMTimeZero)
                        videoCompTrack.preferredTransform = assetVideoTrack.preferredTransform
                    } catch {
                        print("trimVideo() insertTimeRange video error")
                    }
                } else {
                    print("trimeVdieo() not found video track")
                }
                if self.isSoundAble {
                    if let assetAudioTrack = sourceAsset.tracks(withMediaType: AVMediaTypeAudio).first {
                        // insert video, audio track into composition
                        do {
                            try audioCompTrack.insertTimeRange(timeRangeForCurrentSlice, of: assetAudioTrack, at: kCMTimeZero)
                        } catch {
                            print("trimVideo() insertTimeRange audio error")
                        }
                    } else {
                        print("trimeVdieo() not found audio track")
                    }
                }
                
                //OUTPUT VIDEO 1
                // Export by passthrough preset and compsiton with video, audio
                self.exportSession = AVAssetExportSession(asset: composition, presetName: preferredPreset)
                self.exportSession?.outputURL = destinationURL as URL
                self.exportSession?.outputFileType = AVFileTypeQuickTimeMovie
                self.exportSession?.shouldOptimizeForNetworkUse = true

                self.showLoadingView()

                self.exportSession?.exportAsynchronously(completionHandler: { () -> Void in
                    
                    self.hideLoadingView()

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
                            
                            if UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(movieUrl.relativePath!) {
                                UISaveVideoAtPathToSavedPhotosAlbum(
                                    movieUrl.relativePath!,
                                    self,
                                    #selector(PetPolarVideoTrimmerViewController.video(videoPath:didFinishSavingWithError:contextInfo:)),
                                    nil
                                )
                            } else {
                                print("didFinishRecordingToOutputFileAt() Save to PhotosAlbum fail")
                            }
                            
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
                print("file was romeved")
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
            message = "Saving Failed"
        } else {
            title = "Success !"
            message = "Saved To Photo Album"
        }
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.cancel, handler: nil))
        self.present(alert, animated: true, completion: nil)
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
        if (self.editMode == .trim) {
            self.isPlaying = !self.isPlaying
            self.setVideoState(status: self.isPlaying)
        }
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

extension PetPolarVideoTrimmerViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
  
    func handleLongPress(longPress: UILongPressGestureRecognizer) {
        let offsetLeft: CGFloat = self.coverPointButton.frame.width/2
        let offsetRight: CGFloat = self.coverBarView.frame.width - self.coverPointButton.frame.width/2
        let point = longPress.location(in: self.coverBarView)
        switch longPress.state {
            case .began:
                break
            case .ended:
                break
            case .changed:
                if (point.x < offsetLeft) {
                    self.coverPointButton.center.x = offsetLeft
                } else if (point.x > offsetRight) {
                    self.coverPointButton.center.x = offsetRight
                } else {
                    self.coverPointButton.center.x = point.x
                }
                break
            default:
                break
        }
        self.coverAtPercent = (self.coverPointButton.center.x - offsetLeft) / (offsetRight - offsetLeft) * 100
        let currentTime = self.coverAtPercent/100.00 * (self.stopTime-self.startTime)
        self.coverAtTime = self.startTime + currentTime
        print("point: \(point), at: \(self.coverAtPercent) %, currentTime: \(currentTime), videoTime: \(self.coverAtTime)")
        self.seekVideoToPos(pos: self.coverAtTime)
    }
    
    func getCoverImage() {
        if (self.isAssetExist()) {
            do {
                let imgGenerator = AVAssetImageGenerator(asset: self.asset!)
                imgGenerator.appliesPreferredTrackTransform = true
                let cgImage = try imgGenerator.copyCGImage(at: CMTimeMakeWithSeconds(Float64(self.coverAtTime), self.asset!.duration.timescale), actualTime: nil)
                let thumbnail = UIImage(cgImage: cgImage)
                
                // thumbnail here
                self.coverImage = thumbnail
                UIImageWriteToSavedPhotosAlbum(thumbnail, nil, nil, nil)
            } catch let error {
                print("*** Error generating thumbnail: \(error.localizedDescription)")
            }
        }
    }

    func getSampleCoverImages() {
        print("timescale: \(self.asset!.duration.timescale)")
        print("duration: \(self.asset!.duration)")
        print("duration: \(CMTimeGetSeconds(self.asset!.duration))")
        
        if (self.isAssetExist()) {
            self.sampleCovers.removeAll(keepingCapacity: false)
            
            let rangeDivider = (self.stopTime - self.startTime) / CGFloat(self.numberOfSampleCover-1)
            for i in 0..<self.numberOfSampleCover {
                let snapTime = self.startTime + CGFloat(i) * rangeDivider
                print("\(i): \(snapTime)")
                do {
                    let imgGenerator = AVAssetImageGenerator(asset: self.asset!)
                    imgGenerator.appliesPreferredTrackTransform = true
                    let cgImage = try imgGenerator.copyCGImage(at: CMTimeMakeWithSeconds(Float64(snapTime), self.asset!.duration.timescale), actualTime: nil)
                    let thumbnail = UIImage(cgImage: cgImage)
                    
                    // thumbnail here
                    self.sampleCovers.append(thumbnail)
                } catch let error {
                    print("*** Error generating thumbnail: \(error.localizedDescription)")
                }
            }
            self.coverCollectionView.reloadData()
        }
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.sampleCovers.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CoverCollectionViewCell", for: indexPath) as! CoverCollectionViewCell
        cell.sequenceLabel.text = "\(indexPath.item)"
        cell.imageView.image = self.sampleCovers[indexPath.item]
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 60.0, height: 60.0)
    }
    
}

extension PetPolarVideoTrimmerViewController: VideoEditorDelegate {
    
    //OUTPUT VIDEO2 CROPED
    func cropExportOutput(success: Bool, outputFile: URL) {
        print("cropExportOutput() seccess: \(success)")
        self.hideLoadingView()
        
        if (success) {
            
//            DispatchQueue.main.async(execute: {
//                self.nextView(url: outputFile)
//            })
            
//            UISaveVideoAtPathToSavedPhotosAlbum(outputFile.relativePath, self, nil, nil)
            
//                        self.trimmerViewController?.setupAssetPicker(url: outputFile)
//                        self.nextView(url: outputFile)
//                        self.library()
            
                        if UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(outputFile.relativePath) {
//                            UISaveVideoAtPathToSavedPhotosAlbum(
//                                outputFile.relativePath,
//                                self,
//                                #selector(PetPolarCameraVideoViewController.video(videoPath:didFinishSavingWithError:contextInfo:)),
//                                nil
//                            )
                            UISaveVideoAtPathToSavedPhotosAlbum(outputFile.relativePath, self, nil, nil)
            
                        } else {
                            print("didFinishRecordingToOutputFileAt() Save to PhotosAlbum failed")
            
                        }
            
        } else {
        }
    }
    
    func trimExportOutput(success: Bool, outputFile: URL){}
    
//    func video(videoPath: NSString, didFinishSavingWithError error: NSError?, contextInfo info: AnyObject) {
//        self.hideLoadingView()
//        
//        var title = ""
//        var message = ""
//        if (error != nil) {
//            title = "Failed !"
//            message = "Saving Failed"
//        } else {
//            title = "Success !"
//            message = "Saved To Photo Album"
//        }
//        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
//        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.cancel, handler: nil))
//        self.present(alert, animated: true, completion: nil)
//    }
    
}

