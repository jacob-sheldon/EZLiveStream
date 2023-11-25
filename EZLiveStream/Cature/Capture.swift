//
//  Capture.swift
//  EZLiveStream
//
//  Created by 施治昂 on 11/5/23.
//

import Foundation
import AVFoundation

// https://www.jianshu.com/p/eccdcf43d7d2
class Capture {
    var delegate: CaptureDelegate? {
        didSet {
            if let delegate = delegate {
                self.sampleBufferDelegate = VideoDataOutputSampleBufferDelegate(delegate: delegate)
                let queue = DispatchQueue(label: "video.data.output", qos: .default, autoreleaseFrequency: .inherit, target: nil)
                captureVideoDataOutput!.setSampleBufferDelegate(self.sampleBufferDelegate, queue: queue)
            }
        }
    }
    
    private var camera : AVCaptureDevice?
    private var captureDeviceInput : AVCaptureDeviceInput?
    private var captureVideoDataOutput : AVCaptureVideoDataOutput?
    private var captureSession : AVCaptureSession?
    private var captureConnection : AVCaptureConnection?
    
    public var previewLayer : AVCaptureVideoPreviewLayer?
    
    private var sampleBufferDelegate : VideoDataOutputSampleBufferDelegate?
    
    private var isCapturing = false
    
    private func initCaptureDeviceInput() throws -> AVCaptureDeviceInput {
        let session = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .builtInTrueDepthCamera, .builtInDualCamera, .builtInMicrophone], mediaType: .video, position: .front)
        let frontDevices = session.devices.filter { device in device.position == .front }
        self.camera = frontDevices.first
        return try AVCaptureDeviceInput(device: frontDevices.first!)
    }
    
    private func initCaptureOutput() -> AVCaptureVideoDataOutput {
        let captureVideoDataOutput = AVCaptureVideoDataOutput()
        let videoSettings = [kCVPixelBufferPixelFormatTypeKey as String : kCVPixelFormatType_420YpCbCr8BiPlanarFullRange as Any]
        captureVideoDataOutput.videoSettings = videoSettings
        captureVideoDataOutput.alwaysDiscardsLateVideoFrames = true
        
        return captureVideoDataOutput
    }
    
    private func initCaptureSession() -> AVCaptureSession {
        let session = AVCaptureSession()
        // 不使用应用的音频实例，避免被异常挂断
        session.usesApplicationAudioSession = false
        
        if session.canAddInput(self.captureDeviceInput!) {
            session.addInput(self.captureDeviceInput!)
        }
        
        if session.canAddOutput(self.captureVideoDataOutput!) {
            session.addOutput(self.captureVideoDataOutput!)
        }
        
        if session.canSetSessionPreset(.hd1280x720) {
            session.canSetSessionPreset(.hd1280x720)
        }
        
        
        return session
    }
    
    private func initConnection() -> AVCaptureConnection {
        let captureConnection = self.captureVideoDataOutput!.connection(with: .video)!
        captureConnection.videoOrientation = .portrait
        if self.camera!.position == .front, captureConnection.isVideoMirroringSupported {
            captureConnection.isVideoMirrored = true
        }
        
        return captureConnection
    }
    
    private func initPreviewLayer() -> AVCaptureVideoPreviewLayer {
        let layer = AVCaptureVideoPreviewLayer(session: self.captureSession!)
        layer.connection!.videoOrientation = .portrait
        layer.videoGravity = .resizeAspectFill
        
        return layer
    }
    
    init() {
        do {
            self.captureDeviceInput = try initCaptureDeviceInput()
        } catch {
            print("初始化设备信息失败: \(error)")
        }
        self.captureVideoDataOutput = initCaptureOutput()
        self.captureSession = initCaptureSession()
        self.captureConnection = initConnection()
        self.previewLayer = initPreviewLayer()
    }
    
    public func start() {
        DispatchQueue.global().async {
            self.startCaputre()
        }
    }
    
    public func stop() {
        DispatchQueue.global().async {
            self.captureSession!.stopRunning()
        }
    }
    
    @discardableResult
    private func startCaputre() -> Bool {
        if self.isCapturing {
            return false
        }
        
        // 摄像头权限判断
        let authStatus = AVCaptureDevice.authorizationStatus(for: .video)
        if authStatus != .authorized {
            return false
        }
        self.captureSession!.startRunning()
        self.isCapturing = true
        return true
    }
}

fileprivate class VideoDataOutputSampleBufferDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private var delegate : CaptureDelegate
    
    init(delegate: CaptureDelegate) {
        self.delegate = delegate
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        self.delegate.videoCapture(didOutput: sampleBuffer)
    }
    
    func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
    }
}
