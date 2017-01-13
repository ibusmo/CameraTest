//
//  PetPolarCameraVideoViewController.swift
//  CameraView
//
//  Created by Cpt. Omsub Sukkhee on 1/9/17.
//  Copyright © 2017 omsubusmo. All rights reserved.
//

import UIKit
import AVFoundation

class PetPolarCameraVideoViewController: UIViewController {
    
    var captureSession = AVCaptureSession()
    var sessionOutput = AVCaptureStillImageOutput()
    var previewLayer = AVCaptureVideoPreviewLayer()
    
    @IBOutlet weak var cameraView: UIView!

    override func viewWillAppear(_ animated: Bool) {
        
        if let devices = AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo) {
            for device in devices {
                
                print("device: \(device)")
        
                if (device as! AVCaptureDevice).position == AVCaptureDevicePosition.back {
                    
                    do {
                        let input = try AVCaptureDeviceInput(device: device as! AVCaptureDevice)
                        
                        captureSession.sessionPreset = AVCaptureSessionPresetMedium
                        
                        if captureSession.canAddInput(input) {
                            
                            captureSession.addInput(input)
                            sessionOutput.outputSettings = [AVVideoCodecKey: AVVideoCodecJPEG]
                            
                            if captureSession.canAddOutput(sessionOutput) {
                                
                                captureSession.addOutput(sessionOutput)
                                captureSession.startRunning()
                                
                                previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
                                previewLayer.videoGravity = AVLayerVideoGravityResizeAspect
                                previewLayer.connection.videoOrientation = AVCaptureVideoOrientation.portrait
                                
                                cameraView.layer.addSublayer(previewLayer)
                                
                                previewLayer.position = CGPoint(x: self.cameraView.frame.width / 2, y: self.cameraView.frame.height / 2)
                                previewLayer.bounds = self.cameraView.bounds
                                
                            }
                            
                        }
                        
                    }
                    catch {
                        print("Error")
                    }
                    
                }
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    @IBAction func TakePhoto(_ sender: Any) {
        
        print("TakePhoto()")
        
        if let videoConnection = sessionOutput.connection(withMediaType: AVMediaTypeVideo) {
            
            sessionOutput.captureStillImageAsynchronously(from: videoConnection, completionHandler: { (buffer, error) in
                
                let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(buffer)
                UIImageWriteToSavedPhotosAlbum(UIImage(data: imageData!)!, nil, nil, nil)
                
            })
            
        }
        
    }
    
}
