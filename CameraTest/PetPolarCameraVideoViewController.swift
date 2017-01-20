//
//  PetPolarCameraVideoViewController.swift
//  CameraView
//
//  Created by Cpt. Omsub Sukkhee on 1/9/17.
//  Copyright © 2017 omsubusmo. All rights reserved.
//

import UIKit
import AVFoundation

enum CameraMode {
    case photo, video
}

protocol CameraVideoSetup {
    
}

class PetPolarCameraVideoViewController: UIViewController {
    
    var cameraMode: CameraMode = .video
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
    
    @IBOutlet weak var cameraView: UIView!

    override func viewWillAppear(_ animated: Bool) {
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.startCamera()
    }
    
    // MARK: - camera
    
    func startCamera() {
        if (self.cameraSetup == true) {
            return
        }
        
        self.setupCameraDevices()
        if (!self.setupInput()) {
            return
        }
        self.setupOutput()
        self.setupCaptureSession()
        self.setupPreviewLayer()
        self.updateCameraConnection()
        self.toggleFlash()
        
        self.captureSession?.startRunning()
        
        self.cameraSetup = true
    }

    
    
    
    
    
    
    
    
    
    @IBAction func TakePhoto(_ sender: Any) {
        switch self.cameraMode {
        case .photo:
            self.takePhotoToLibary()
        case .video:
            self.toggleRecordVideo()
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
    
    func toggleRecordVideo(){
        if !self.isRecording {
            self.recordVideo()
            self.toggleFlash()
            self.isRecording = true
        } else {
            self.stopRecordVideo()
            self.toggleFlash()
            self.isRecording = false
        }
    }
    
    func stopRecordVideo() {
        print("stopRecordVideo()")
        
        self.videoOutput?.stopRecording()
    }
    
    func recordVideo() {
        print("recordVideo() start")
        
        let fileName = "mysavefile.mp4";
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let filePathUrl = documentsURL.appendingPathComponent(fileName)
        
        print("recordVideo() path: \(filePathUrl)")
        
        self.videoOutput?.startRecording(toOutputFileURL: filePathUrl, recordingDelegate: self)
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
                    self.audio = device as? AVCaptureDevice
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
        
        self.cameraCurrent = self.cameraBack
        
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
                self.inputAudio = try AVCaptureDeviceInput(device: self.audio)
            }
            
            if (self.inputBack != nil) {
                self.inputCurrent = self.inputBack
            } else if (self.inputFront != nil) {
                self.inputCurrent = self.inputFront
            }
            
        } catch {
            return false
        }
        
        return true
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
            self.captureSession?.addInput(self.inputAudio)
        }
        
        switch self.cameraMode {
        case .photo:
            self.captureSession?.sessionPreset = AVCaptureSessionPresetHigh
            if (self.captureSession?.canAddOutput(self.imageOutput))! {
                self.captureSession?.addOutput(self.imageOutput)
            }
            
        case .video:
            self.captureSession?.sessionPreset = AVCaptureSessionPresetHigh
            if (self.captureSession?.canAddOutput(self.videoOutput))! {
                self.captureSession?.addOutput(self.videoOutput)
            }
        }
        
    }
    
    func setupPreviewLayer() {
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        
        previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
        previewLayer.connection.videoOrientation = AVCaptureVideoOrientation.portrait
        
        cameraView.layer.addSublayer(previewLayer)
        
        previewLayer.position = CGPoint(x: self.cameraView.frame.width / 2, y: self.cameraView.frame.height / 2)
        previewLayer.bounds = self.cameraView.bounds
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
    
    func changeFlashMode() -> Bool {
        do {
            self.captureSession?.beginConfiguration()
            try self.cameraCurrent?.lockForConfiguration()
        
            if (flashMode == true) {
                if (self.cameraCurrent?.isFlashModeSupported(AVCaptureFlashMode.off) == true) {
                    self.cameraCurrent?.flashMode = AVCaptureFlashMode.off
                    self.flashMode = false
                }
            } else {
                if (self.cameraCurrent?.isFlashModeSupported(AVCaptureFlashMode.on) == true) {
                    self.cameraCurrent?.flashMode = AVCaptureFlashMode.on
                    self.flashMode = true
                }
            }
            
            self.cameraCurrent?.unlockForConfiguration()
            self.captureSession?.commitConfiguration()
            
        } catch let error as NSError {
            print("changeFlashMode(): \(error)")
        }
        
        return self.flashMode
    }
    
    func toggleFlash() {
        switch cameraMode {
        case .photo:
            self.changeFlashMode()
            
        case .video:
            if let device = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo), device.hasTorch {
                do {
                    try device.lockForConfiguration()
                    let torchOn = !device.isTorchActive
                    try device.setTorchModeOnWithLevel(1.0)
                    device.torchMode = torchOn ? .on : .off
                    device.unlockForConfiguration()
                } catch {
                    print("error")
                }
            }
            
        }
    }
    
}
