//
//  ViewController.swift
//  EZLiveStream
//
//  Created by 施治昂 on 11/5/23.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {
    private var capture : Capture?
    private var compressionSession : VideoEncoder?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        self.capture = Capture()
        self.capture!.delegate = self
        
        let startBtn = UIButton(frame: CGRect(x: 30, y: 60, width: 100, height: 30))
        startBtn.setTitle("开始", for: .normal)
        startBtn.addTarget(self, action: #selector(startCapture), for: .touchUpInside)
        startBtn.backgroundColor = .green
        view.addSubview(startBtn)
        
        let stopBtn = UIButton(frame: CGRect(x: 230, y: 60, width: 100, height: 30))
        stopBtn.setTitle("停止", for: .normal)
        stopBtn.addTarget(self, action: #selector(stopCapture), for: .touchUpInside)
        stopBtn.backgroundColor = .red
        view.addSubview(stopBtn)
        
        capture!.previewLayer!.frame = CGRectMake(30, 160, 300, 280)
        view.layer.addSublayer(capture!.previewLayer!)
        
        self.compressionSession = VideoEncoder()
    }
    
    @objc
    func startCapture() {
        self.capture?.start()
    }
    
    @objc
    func stopCapture() {
        self.capture?.stop()
    }
}

extension ViewController : CaptureDelegate {
    func videoCapture(didOutput sampleBuffer: CMSampleBuffer) {
        print(sampleBuffer)
        self.compressionSession?.encode(imageBuffer: CMSampleBufferGetImageBuffer(sampleBuffer)!)
    }
}
