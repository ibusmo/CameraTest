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

class PetPolarVideoTrimmerViewController: UIViewController {
    
    @IBOutlet weak var videoPreviewView: UIView!
    @IBOutlet weak var trimmerView: UIView!
    
    @IBOutlet weak var trimModeButton: UIButton!
    @IBOutlet weak var coverModeButton: UIButton!
    
    // Video Player
    let isPlaying: Bool = false
    var player: AVPlayer?
    var playerItem: AVPlayerItem?
    var playerLayer: AVPlayerLayer?
    var playbackTimeCheckerTimer: Timer?
    var videoPlaybackPosition: CGFloat = 0.0
    
    var tempVideoPath: NSString?
    
    // mark - tempolary asset
    var asset: AVAsset?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.tempVideoPath = NSTemporaryDirectory().appending("tmpMov.mov") as NSString?
    }
    
    func selectAsset() {
        let myImagePickerController = UIImagePickerController()
        myImagePickerController.sourceType = .photoLibrary
        myImagePickerController.mediaTypes = [kUTTypeMovie as NSString as String]
        myImagePickerController.allowsEditing = false
        myImagePickerController.delegate = self
        self.present(myImagePickerController, animated: true, completion: nil)
    }
    
    
}

extension PetPolarVideoTrimmerViewController: UIImagePickerControllerDelegate {
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        picker.dismiss(animated: true, completion: nil)
        
        let url = info[UIImagePickerControllerMediaType] as! NSString
        self.asset = AVAsset(url: url)
    }
    
}

extension PetPolarVideoTrimmerViewController: UINavigationControllerDelegate {
    
}
