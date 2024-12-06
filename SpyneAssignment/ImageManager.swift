//
//  ImageManager.swift
//  SpyneAssignment
//
//  Created by Arav Khandelwal on 03/12/24.
//

import UIKit
import AVFoundation

class ImageCaptureManager: NSObject {
    private var captureSession: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private weak var viewController: UIViewController?
    
    // Completion handler for captured image
    var onImageCaptured: ((UIImage) -> Void)?

    init(viewController: UIViewController) {
        self.viewController = viewController
        super.init()
    }

    func setupCameraPreview(in view: UIView) {
        captureSession = AVCaptureSession()
        guard let captureSession = captureSession else { return }
        
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .photo

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            print("Camera setup failed.")
            return
        }

        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }

        photoOutput = AVCapturePhotoOutput()
        if let photoOutput = photoOutput, captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.videoGravity = .resizeAspectFill
        previewLayer?.frame = view.bounds
        if let previewLayer = previewLayer {
            view.layer.addSublayer(previewLayer)
        }

        captureSession.commitConfiguration()
        captureSession.startRunning()
    }

    func captureImage() {
        guard let photoOutput = photoOutput else { return }
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func stopSession() {
        captureSession?.stopRunning()
    }
}

extension ImageCaptureManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Error capturing photo: \(error.localizedDescription)")
            return
        }
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            print("Failed to process captured image.")
            return
        }
        onImageCaptured?(image)
    }
}
