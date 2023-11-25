//
//  CaptureDelegate.swift
//  EZLiveStream
//
//  Created by 施治昂 on 11/12/23.
//

import AVFoundation

protocol CaptureDelegate {
    func videoCapture(didOutput sampleBuffer: CMSampleBuffer)
}
