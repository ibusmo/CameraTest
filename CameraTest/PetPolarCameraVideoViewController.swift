//
//  PetPolarCameraVideoViewController.swift
//  CameraView
//
//  Created by Cpt. Omsub Sukkhee on 1/9/17.
//  Copyright © 2017 omsubusmo. All rights reserved.
//

import UIKit
import AVFoundation

enum BottomButtonMode {
    case lib, photo, video
}
enum CameraMode {
    case photo, video
}
enum CameraInput {
    case front, back
}

protocol CameraVideoFocusSetup {}
protocol CameraVideoSetup {}
protocol PetPolarCameraVideoViewControllerDelegate {
    func cameraDismissViewController()
}

class PetPolarCameraVideoViewController: UIViewController {
    
    var delegate: PetPolarCameraVideoViewControllerDelegate?
    
    // Flag & Mode
    var cameraMode: CameraMode = .video
    var cameraInput: CameraInput = .back
    var isRecording = false
    var cameraSetup = false
    var flashMode = false
    
    var cameraCurrent: AVCaptureDevice?
    var cameraFront: AVCaptureDevice?
    var cameraBack: AVCaptureDevice?
    var audio: AVCaptureDevice?
    
    var inputCurrent: AVCaptureDeviceInput?
    var inputFront: AVCaptureDeviceInput?
    var inputBack: AVCaptureDeviceInput?
    var inputAudio: AVCaptureDeviceInput?
    
    var imageOutput: AVCaptureStillImageOutput?
    var imageConnection: AVCaptureConnection?
    
    var videoOutput: AVCaptureMovieFileOutput?
    var videoConnection: AVCaptureConnection?
    
    var captureSession: AVCaptureSession?
    
    var previewLayer = AVCaptureVideoPreviewLayer()
    
    // View Conroller
    var trimmerViewController: PetPolarVideoTrimmerViewController?
    
    // Header
    @IBOutlet weak var headerView: UIView!
    @IBOutlet weak var closeButton: UIButton!
    // Preview
    @IBOutlet weak var previewView: UIView!
    @IBOutlet weak var optionView: UIView!
    @IBOutlet weak var gridButton: UIButton!
    @IBOutlet weak var flashButton: UIButton!
    @IBOutlet weak var swapButton: UIButton!
    // Action
    @IBOutlet weak var actionView: UIView!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var captureButton: UIButton!
    // Bottom
    @IBOutlet weak var bottomView: UIView!
    @IBOutlet weak var libraryButton: UIButton!
    @IBOutlet weak var photoButton: UIButton!
    @IBOutlet weak var videoButton: UIButton!
    @IBOutlet weak var libraryUnderView: UIView!
    @IBOutlet weak var photoUnderView: UIView!
    @IBOutlet weak var videoUnderVIew: UIView!
    
    override func viewWillAppear(_ animated: Bool) {
        print("PetPolarCameraVideoViewController: viewWillAppear")
        UIApplication.shared.setStatusBarHidden(true, with: UIStatusBarAnimation.fade)
    }
    
    override func viewDidLoad() {
        print("PetPolarCameraVideoViewController: viewDidLoad")
        super.viewDidLoad()
        self.startCamera()
        
        self.captureButton.addTarget(self, action: #selector(PetPolarCameraVideoViewController.captureCamera), for: UIControlEvents.touchUpInside)
        self.flashButton.addTarget(self, action: #selector(PetPolarCameraVideoViewController.toggleFlash), for: UIControlEvents.touchUpInside)
        self.swapButton.addTarget(self, action: #selector(PetPolarCameraVideoViewController.swapCamrea), for: UIControlEvents.touchUpInside)
        self.libraryButton.addTarget(self, action: #selector(PetPolarCameraVideoViewController.library), for: UIControlEvents.touchUpInside)
        self.photoButton.addTarget(self, action: #selector(PetPolarCameraVideoViewController.setCameraToPhotoMode), for: UIControlEvents.touchUpInside)
        self.videoButton.addTarget(self, action: #selector(PetPolarCameraVideoViewController.setCameraToVideoMode), for: UIControlEvents.touchUpInside)
        
        self.setCameraToVideoMode()
    }
    
    // MARK: - camera
    
    func reStartCamera() {
        print("reStartCamera()")
        self.cameraSetup = false
        self.startCamera()
    }
    
    func startCamera() {
        print("startCamera()")
        if !self.cameraSetup {
            self.setupCameraDevices()
            if self.setupInput() && self.selectInput(cameraInput: self.cameraInput) {
                self.setupOutput()
                self.setupCaptureSession()
                self.setupPreviewLayer()
                self.updateCameraConnection()
                self.setFlash(status: false)
                
                self.captureSession?.startRunning()
                self.cameraSetup = true
            }
        }
    }
    
    func library() {
        self.setupBottomView(mode: .lib)
        
        self.trimmerViewController = PetPolarVideoTrimmerViewController(nibName: "PetPolarVideoTrimmerViewController", bundle: nil)
        self.trimmerViewController?.delegate = self
        self.present(self.trimmerViewController!, animated: true, completion: nil)
    }
    
    func setCameraToPhotoMode() {
        self.setupBottomView(mode: .photo)
        
        self.cameraMode = .photo
        self.reStartCamera()
    }
    
    func setCameraToVideoMode() {
        self.setupBottomView(mode: .video)
        
        self.cameraMode = .video
        self.reStartCamera()
    }
    
    func setupBottomView(mode: BottomButtonMode) {
        self.libraryButton.setTitleColor(UIColor.white, for: UIControlState.normal)
        self.libraryButton.setTitleColor(UIColor.white, for: UIControlState.highlighted)
        self.libraryUnderView.isHidden = true
        self.photoButton.setTitleColor(UIColor.white, for: UIControlState.normal)
        self.photoButton.setTitleColor(UIColor.white, for: UIControlState.highlighted)
        self.photoUnderView.isHidden = true
        self.videoButton.setTitleColor(UIColor.white, for: UIControlState.normal)
        self.videoButton.setTitleColor(UIColor.white, for: UIControlState.highlighted)
        self.videoUnderVIew.isHidden = true
        
        switch mode {
        case .lib:
            self.libraryButton.setTitleColor(UIColor.blue, for: UIControlState.normal)
            self.libraryButton.setTitleColor(UIColor.blue, for: UIControlState.highlighted)
            self.libraryUnderView.isHidden = false
            break
        case .photo:
            self.photoButton.setTitleColor(UIColor.blue, for: UIControlState.normal)
            self.photoButton.setTitleColor(UIColor.blue, for: UIControlState.highlighted)
            self.photoUnderView.isHidden = false
            break
        case .video:
            self.videoButton.setTitleColor(UIColor.blue, for: UIControlState.normal)
            self.videoButton.setTitleColor(UIColor.blue, for: UIControlState.highlighted)
            self.videoUnderVIew.isHidden = false
            break
        }
    }
    
    func captureCamera() {
        switch self.cameraMode {
        case .photo:
            self.takePhotoToLibary()
        case .video:
            self.toggleRecordVideo()
        }
    }
    
    func swapCamrea() {
        print("swapCameraDidTap from \(self.cameraInput)")
        if self.cameraInput == .back {
            self.cameraInput = .front
        } else {
            self.cameraInput = .back
        }
        print("swapCameraDidTap to \(self.cameraInput)")
        self.reStartCamera()
    }
    
    func toggleRecordVideo(){
        print("toggleRecordVideo() self.cameraInput: \(self.cameraInput)")
        if !self.isRecording {
            self.satrtRecordVideo()
            self.isRecording = true
            self.swapButton.isHidden = true
            self.gridButton.isHidden = true
            if self.cameraInput == .back {
                self.flashButton.isHidden = true
            }
            self.captureButton.backgroundColor = UIColor.red
        } else {
            self.stopRecordVideo()
            self.isRecording = false
            self.swapButton.isHidden = false
            self.gridButton.isHidden = false
            if self.cameraInput == .back {
                self.flashButton.isHidden = false
            }
            self.captureButton.backgroundColor = UIColor.clear
        }
    }
    
    func takePhotoToLibary() {
        print("TakePhoto()")
        self.imageOutput?.captureStillImageAsynchronously(from: self.imageConnection, completionHandler: { (buffer, error) in
            if error != nil {
                print("TakePhoto() error")
            } else {
                print("TakePhoto() success")
                let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(buffer)
                UIImageWriteToSavedPhotosAlbum(UIImage(data: imageData!)!, nil, nil, nil)
            }
        })
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let point: CGPoint = touchPercent(touch: touches.first! as UITouch)
        if (self.previewView.frame.contains(point)) {
            self.focusAtPoint(point: point)
        }
    }
    
    func closeViewController() {
        UIApplication.shared.setStatusBarHidden(false, with: UIStatusBarAnimation.fade)
        self.dismiss(animated: true, completion: {
            print("PetPolarCameraVideoViewController: delegate")
            self.delegate?.cameraDismissViewController()
        })
    }

}

extension PetPolarCameraVideoViewController: AVCaptureFileOutputRecordingDelegate {
    
    public func capture(_ captureOutput: AVCaptureFileOutput!, didFinishRecordingToOutputFileAt outputFileURL: URL!, fromConnections connections: [Any]!, error: Error!) {
        print("didFinishRecordingToOutputFileAt() capture did finish")
        
        print("didFinishRecordingToOutputFileAt() captureOutput: \(captureOutput)")
        print("didFinishRecordingToOutputFileAt() outputFileURL: \(outputFileURL)")
        
        if error != nil {
            print("didFinishRecordingToOutputFileAt() capture did finish error: \(error)")
        } else {
            if UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(outputFileURL.relativePath) {
                print("didFinishRecordingToOutputFileAt() Save to PhotosAlbum success")
                UISaveVideoAtPathToSavedPhotosAlbum(outputFileURL.relativePath, nil, nil, nil)
            } else {
                print("didFinishRecordingToOutputFileAt() Save to PhotosAlbum fail")
            }
        }
    }
    
}

extension PetPolarCameraVideoViewController: CameraVideoSetup {
    
    func setupCameraDevices() {
        
        if let devices = AVCaptureDevice.devices() {
            for device in devices as [AnyObject] {
                if (device.hasMediaType(AVMediaTypeVideo)) {
                    if(device.position == AVCaptureDevicePosition.back) {
                        self.cameraBack = device as? AVCaptureDevice
                    } else if (device.position == AVCaptureDevicePosition.front) {
                        self.cameraFront = device as? AVCaptureDevice
                    }
                }
                if (device.hasMediaType(AVMediaTypeAudio)) {
                    print("setupCameraDevices() this is AVCaptureDevice")
                    self.audio = device as? AVCaptureDevice
                } else {
                    print("setupCameraDevices() this is not AVCaptureDevice")
                }
            }
        }
        do {
            try cameraBack?.lockForConfiguration()
            if ((cameraBack != nil) && (cameraBack?.isWhiteBalanceModeSupported(AVCaptureWhiteBalanceMode.continuousAutoWhiteBalance)) != nil) {
                cameraBack?.whiteBalanceMode = AVCaptureWhiteBalanceMode.continuousAutoWhiteBalance
            }
            if ((cameraBack != nil) && (cameraBack?.isExposureModeSupported(AVCaptureExposureMode.continuousAutoExposure) != nil)) {
                cameraBack?.exposureMode = AVCaptureExposureMode.continuousAutoExposure
            }
            cameraBack?.unlockForConfiguration()
        } catch {
            print("Error: cameraBack?.lockForConfiguration()")
        }
        do {
            try cameraFront?.lockForConfiguration()
            if ((cameraFront != nil) && (cameraFront?.isWhiteBalanceModeSupported(AVCaptureWhiteBalanceMode.continuousAutoWhiteBalance)) != nil) {
                cameraFront?.whiteBalanceMode = AVCaptureWhiteBalanceMode.continuousAutoWhiteBalance
            }
            if ((cameraFront != nil) && (cameraFront?.isExposureModeSupported(AVCaptureExposureMode.continuousAutoExposure) != nil)) {
                cameraFront?.exposureMode = AVCaptureExposureMode.continuousAutoExposure
            }
            cameraFront?.unlockForConfiguration()
        } catch {
            print("Error: cameraFront?.lockForConfiguration()")
        }
    }
    
    func setupInput() -> Bool {
        do {
            if (self.cameraFront != nil) {
                self.inputFront = try AVCaptureDeviceInput(device: self.cameraFront)
            }
            if (self.cameraBack != nil) {
                self.inputBack = try AVCaptureDeviceInput(device: self.cameraBack)
            }
            if(self.audio != nil){
                print("setupInput() audio input is ready")
                self.inputAudio = try AVCaptureDeviceInput(device: self.audio)
            } else {
                print("setupInput() audio input is not ready")
            }
        } catch {
            return false
        }
        return true
    }
    
    func selectInput(cameraInput: CameraInput) -> Bool {
        if (cameraInput == .front && self.cameraFront != nil && self.inputFront != nil) {
            self.cameraCurrent = self.cameraFront
            self.inputCurrent = self.inputFront
            self.cameraInput = .front
            return true
        } else if (self.cameraBack != nil && self.inputBack != nil) {
            self.cameraCurrent = self.cameraBack
            self.inputCurrent = self.inputBack
            self.cameraInput = .back
            return true
        } else {
            return false
        }
    }
    
    func setupOutput() {
        self.setupImageOutput()
        self.setupVideoOutput()
    }
    
    func setupImageOutput() {
        self.imageOutput = AVCaptureStillImageOutput()
        let outputSettings = [AVVideoCodecKey: AVVideoCodecJPEG]
        self.imageOutput?.outputSettings = outputSettings
    }
    
    func setupVideoOutput() {
        self.videoOutput = AVCaptureMovieFileOutput()
    }
    
    func setupCaptureSession() {
        self.captureSession = AVCaptureSession()
        
        if (self.captureSession?.canAddInput(self.inputCurrent))! {
            self.captureSession?.addInput(self.inputCurrent)
        }
        if (self.captureSession?.canAddInput(self.inputAudio))! {
            print("setupCaptureSession() captureSession was added by inputAudio")
            self.captureSession?.addInput(self.inputAudio)
        } else {
            print("setupCaptureSession() captureSession could not added by inputAudio")
        }
        
        switch self.cameraMode {
        case .photo:
            self.captureSession?.sessionPreset = AVCaptureSessionPresetMedium
            if (self.captureSession?.canAddOutput(self.imageOutput))! {
                self.captureSession?.addOutput(self.imageOutput)
            }
            
        case .video:
            self.captureSession?.sessionPreset = AVCaptureSessionPresetMedium
            if (self.captureSession?.canAddOutput(self.videoOutput))! {
                self.captureSession?.addOutput(self.videoOutput)
            }
        }
        
    }
    
    func setupPreviewLayer() {
        self.previewLayer.removeFromSuperlayer()
        self.previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        
        self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
        self.previewLayer.connection.videoOrientation = AVCaptureVideoOrientation.portrait
        
        self.previewLayer.position = CGPoint(x: self.previewView.frame.width / 2, y: self.previewView.frame.height / 2)
        self.previewLayer.bounds = self.previewView.bounds
        
        self.previewView.layer.addSublayer(self.previewLayer)
        self.previewView.bringSubview(toFront: self.optionView)
    }
    
    func updateCameraConnection() {
        // Image
        for connection in self.imageOutput!.connections as [AnyObject] {
            for port in connection.inputPorts! as [AnyObject] {
                if (port.mediaType == AVMediaTypeVideo) {
                    self.imageConnection = connection as? AVCaptureConnection
                }
            }
        }
        // Video
        
    }
    
    func toggleFlash() {
        self.flashMode = !self.flashMode
        
        if (self.cameraInput == .back) {
            self.setFlash(status: self.flashMode)
        } else if (self.cameraInput == .front) {
            self.flashMode = false
        }
        print("toggleFlash to \(self.flashMode)")
    }
    
    func setFlash(status: Bool) {
        self.flashMode = status
        if (self.cameraInput == .back) {
            self.flashButton.isHidden = false
            switch cameraMode {
            case .photo:
                self.setCameraFlashMode(status: self.flashMode)
            case .video:
                self.setVideoFlashMode(status: self.flashMode)
            }
            if (status) {
                self.flashButton.setImage(UIImage(named: "nflash_on_white"), for: UIControlState.normal)
            } else {
                self.flashButton.setImage(UIImage(named: "nflash_off"), for: UIControlState.normal)
            }
        } else if (self.cameraInput == .front) {
            self.flashMode = false
            self.flashButton.isHidden = true
        }
        print("setFlash to \(self.flashMode)")
    }
    
    func setCameraFlashMode(status: Bool) {
        print("setCameraFlashMode \(status)")
        do {
            self.captureSession?.beginConfiguration()
            try self.cameraCurrent?.lockForConfiguration()
            
            if (status == false) {
                if (self.cameraCurrent?.isFlashModeSupported(AVCaptureFlashMode.off) == true) {
                    self.cameraCurrent?.flashMode = AVCaptureFlashMode.off
                }
            } else if (status == true) {
                if (self.cameraCurrent?.isFlashModeSupported(AVCaptureFlashMode.on) == true) {
                    self.cameraCurrent?.flashMode = AVCaptureFlashMode.on
                }
            }
            self.cameraCurrent?.unlockForConfiguration()
            self.captureSession?.commitConfiguration()
        } catch let error as NSError {
            print("changeFlashMode(): \(error)")
        }
    }
    
    func setVideoFlashMode(status: Bool) {
        print("setVideoFlashMode \(status)")
        if let device = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo), device.hasTorch {
            if (self.cameraCurrent?.isFlashAvailable)! {
                do {
                    try device.lockForConfiguration()
                    
                    if (status == false) {
                        device.torchMode = .off
                    } else if (status == true) {
                        device.torchMode = .on
                        try device.setTorchModeOnWithLevel(1.0)
                    }
                    
                    device.unlockForConfiguration()
                } catch {
                    print("error")
                }
            } else {
                print("changeVideoFlashMode flash not support with this camera")
            }
        }
    }
    
    func satrtRecordVideo() {
        print("recordVideo() start")
        
        let fileName = "mysavefile.mp4";
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let filePathUrl = documentsURL.appendingPathComponent(fileName)
        
        print("recordVideo() path: \(filePathUrl)")
        
        self.videoOutput?.startRecording(toOutputFileURL: filePathUrl, recordingDelegate: self)
    }
    
    func stopRecordVideo() {
        print("stopRecordVideo()")
        self.videoOutput?.stopRecording()
    }
    
}

extension PetPolarCameraVideoViewController: CameraVideoFocusSetup {
    
    func touchPercent(touch : UITouch) -> CGPoint {
        let touchPerX = touch.location(in: self.previewView).x
        let touchPerY = touch.location(in: self.previewView).y
        // Return the populated CGPoint
        return CGPoint(x: touchPerX, y: touchPerY)
    }
    
    func focusAtPoint(point: CGPoint) {
        let device: AVCaptureDevice = self.cameraCurrent!
        do {
            let error = try device.lockForConfiguration()
            
            let exactFocusPoint: CGPoint = self.getPointOfInterest(coor: point)
            print(">>>\(point.x), \(point.y) == \(exactFocusPoint.x), \(exactFocusPoint.y)")
            
            let focusImage = UIImage(named: "focus")
            let focusLayer = CALayer()
            focusLayer.contents = focusImage?.cgImage
            focusLayer.frame = CGRect(x: point.x-(focusImage!.size.width/2), y: point.y-(focusImage!.size.height/2), width: focusImage!.size.width, height: focusImage!.size.height)
            
            let fadeAnim = CABasicAnimation(keyPath: "opacity")
            fadeAnim.duration = 1.0
            fadeAnim.fromValue = NSNumber(value: 1.0)
            fadeAnim.toValue = NSNumber(value: 0.0)
            fadeAnim.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseIn)
            
            focusLayer.add(fadeAnim, forKey: "opacity")
            
            focusLayer.opacity = 0.0
            
            self.previewLayer.addSublayer(focusLayer)
            
            //            focusLayer.removeFromSuperlayer()
            
            if (device.isFocusPointOfInterestSupported == true && device.isFocusModeSupported(AVCaptureFocusMode.autoFocus)) {
                device.focusPointOfInterest = exactFocusPoint
                device.focusMode = AVCaptureFocusMode.autoFocus
            }
            if (device.isExposureModeSupported(AVCaptureExposureMode.continuousAutoExposure)) {
                device.exposurePointOfInterest = exactFocusPoint
            }
            device.unlockForConfiguration()
        } catch {
            print("Error: device.lockForConfiguration() \(error)")
        }
        
    }
    
    func getPointOfInterest(coor: CGPoint) -> CGPoint{
        var pointOfInterest: CGPoint = CGPoint(x: 0.5, y: 0.5)
        let frameSize = self.view.frame.size
        let videoPreviewLayer: AVCaptureVideoPreviewLayer = self.previewLayer
        
        if (videoPreviewLayer.videoGravity == AVLayerVideoGravityResize) {
            pointOfInterest = CGPoint(x: coor.y / frameSize.height, y: 1.0 - (coor.x / frameSize.width))
            print("A")
        } else {
            var cleanAperture: CGRect?
            for port in self.inputCurrent!.ports! {
                if ((port as AnyObject).mediaType == AVMediaTypeVideo) {
                    // TODO: - ios8
                    var desc: CMVideoFormatDescription?
                    if #available(iOS 9.0, *) {
                        desc = (port as AnyObject).formatDescription
                        if desc == nil {
                            return CGPoint(x: 0.0, y: 0.0)
                        }
                    } else {
                        // Fallback on earlier versions
                        return CGPoint(x: 0.0, y: 0.0)
                    }
                    cleanAperture = CMVideoFormatDescriptionGetCleanAperture(desc!, true)
                    let apertureSize: CGSize = cleanAperture!.size
                    let point: CGPoint = coor
                    let apertureRatio: CGFloat = apertureSize.height / apertureSize.width
                    let viewRatio: CGFloat = frameSize.width / frameSize.height
                    var xc: CGFloat = 0.5
                    var yc: CGFloat = 0.5
                    
                    if (videoPreviewLayer.videoGravity == AVLayerVideoGravityResizeAspect) {
                        if (viewRatio > apertureRatio) {
                            var y2: CGFloat = frameSize.height
                            let x2: CGFloat = frameSize.height * apertureRatio
                            let x1: CGFloat = frameSize.width
                            let blackBar = (x1 - x2) / 2
                            if (point.x >= blackBar && point.x <= blackBar + x2) {
                                xc = point.y / 2
                                yc = 1.0 - ((point.x - blackBar) / x2)
                            }
                        } else {
                            let y2: CGFloat = frameSize.width
                            let y1: CGFloat = frameSize.height
                            let x2: CGFloat = frameSize.width
                            let blackBar = (y1 - y2) / 2
                            if (point.y >= blackBar && point.y <= blackBar + y2) {
                                xc = ((point.y - blackBar) / y2)
                                yc = 1.0 - (point.x / x2)
                            }
                        }
                    } else if (videoPreviewLayer.videoGravity == AVLayerVideoGravityResizeAspectFill) {
                        if (viewRatio > apertureRatio) {
                            let y2: CGFloat = apertureSize.width * (frameSize.width / apertureSize.height)
                            xc = (point.y + ((y2 - frameSize.height) / 2)) / y2
                            yc = (frameSize.width - point.x) / frameSize.width
                        } else {
                            let x2: CGFloat = apertureSize.height * (frameSize.height / apertureSize.width)
                            yc = 1 - ((point.x + ((x2 - frameSize.width) / 2)) / x2)
                            xc = point.y / frameSize.height
                        }
                    }
                    pointOfInterest = CGPoint(x: xc, y: yc)
                    break
                }
            }}
        return pointOfInterest
    }
    
}

extension PetPolarCameraVideoViewController: PetPolarVideoTrimmerViewControllerDelegate {
    
    func trimmerDismissViewController() {
        print("PetPolarCameraVideoViewController: dismissViewController() delegate")
        self.trimmerViewController = nil
        self.setCameraToPhotoMode()
    }
    
}
