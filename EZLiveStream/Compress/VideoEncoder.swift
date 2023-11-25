//
//  CompressHandler.swift
//  EZLiveStream
//
//  Created by 施治昂 on 11/12/23.
//

import VideoToolbox
import Foundation

// https://www.jianshu.com/p/0d18f04e524d
class VideoEncoder {
    var compressionSessionRef : VTCompressionSession?
    
    private var encodeOutputDataCallback: @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, OSStatus, VTEncodeInfoFlags, CMSampleBuffer?) -> Void = {
        (outputCallbackRefCon, sourceFrameRefCon, status, infoFlags, sampleBuffer) in
        guard status == noErr, let sampleBuffer = sampleBuffer, let outputCallbackRefCon = outputCallbackRefCon, CMSampleBufferDataIsReady(sampleBuffer), infoFlags == VTEncodeInfoFlags.frameDropped  else {
            print("解码失败")
            return
        }
        let encoder = outputCallbackRefCon
        let header: [UInt8] = [0x00, 0x00, 0x00, 0x01]
        let headerData = Data(bytes: header, count: header.count)
        let attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false)
        let keyFrameFlag = Unmanaged<CFDictionary>.fromOpaque(CFArrayGetValueAtIndex(attachmentsArray!, 0))
        let isKeyFrame = !CFDictionaryContainsKey(keyFrameFlag.takeUnretainedValue(), Unmanaged.passUnretained(kCMSampleAttachmentKey_NotSync).toOpaque())
        if isKeyFrame {
            print("VEVideoEncoder::编码了一个关键帧")
            let formatDescriptionRef = CMSampleBufferGetFormatDescription(sampleBuffer)
            
            // 关键帧需要加上SPS、PPS信息
            var sParameterSetSize: size_t = 0, sParameterSetCount: size_t = 0
            var sParameterSet: UnsafePointer<UInt8>?
            let spsStatus = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(formatDescriptionRef!, parameterSetIndex: 0, parameterSetPointerOut: &sParameterSet, parameterSetSizeOut: &sParameterSetSize, parameterSetCountOut: &sParameterSetCount, nalUnitHeaderLengthOut: nil)
            
            var pParameterSetSize: size_t = 0, pParameterSetCount: size_t = 0
            var pParameterSet: UnsafePointer<UInt8>?
            let ppsStatus = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(formatDescriptionRef!, parameterSetIndex: 1, parameterSetPointerOut: &pParameterSet, parameterSetSizeOut: &pParameterSetSize, parameterSetCountOut: &pParameterSetCount, nalUnitHeaderLengthOut: nil)

            if spsStatus == noErr && ppsStatus == noErr {
                let sps = Data(bytes: sParameterSet!, count: sParameterSetSize)
                let pps = Data(bytes: pParameterSet!, count: pParameterSetSize)
                
                var spsData = Data()
                spsData.append(headerData)
                spsData.append(sps)
                
//                if let delegate = encoder.delegate as? VideoEncodeOutputDataCallbackDelegate {
//                    delegate.videoEncodeOutputDataCallback(spsData, isKeyFrame: isKeyFrame)
//                }
                
                var ppsData = Data()
                ppsData.append(headerData)
                ppsData.append(pps)
                
//                if let delegate = encoder.delegate as? VideoEncodeOutputDataCallbackDelegate {
//                    delegate.videoEncodeOutputDataCallback(ppsData, isKeyFrame: isKeyFrame)
//                }
            }
        }
    }
    
    init() {
        var status = VTCompressionSessionCreate(allocator: nil, width: 180, height: 320, codecType: kCMVideoCodecType_H264, encoderSpecification: nil, imageBufferAttributes: nil, compressedDataAllocator: nil, outputCallback: encodeOutputDataCallback, refcon: nil, compressionSessionOut: &compressionSessionRef)
        assert(status == 0, "初始化编码器失败")
        // 设置码率 512kps
        status = VTSessionSetProperty(compressionSessionRef!, key: kVTCompressionPropertyKey_AverageBitRate, value: 512 * 1024 as AnyObject)
        assert(status == 0, "设置编码器属性 kVTCompressionPropertyKey_AverageBitRate 失败")
        // 设置ProfileLevel（画质）为BP3.1
        status = VTSessionSetProperty(compressionSessionRef!, key: kVTCompressionPropertyKey_ProfileLevel, value: kVTProfileLevel_H264_Baseline_3_1)
        assert(status == 0, "设置编码器属性 kVTCompressionPropertyKey_ProfileLevel 失败")
        // 设置实时编码输出（避免延迟）
        status = VTSessionSetProperty(compressionSessionRef!, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanTrue)
        assert(status == 0, "设置编码器属性 kVTCompressionPropertyKey_RealTime 失败")
        // 设置是否产生B帧
        status = VTSessionSetProperty(compressionSessionRef!, key: kVTCompressionPropertyKey_AllowFrameReordering, value: kCFBooleanFalse)
        assert(status == 0, "设置编码器属性 kVTCompressionPropertyKey_AllowFrameReordering 失败")
        // 设置最大I帧间隔 15帧*240秒 = 3600帧，也就是每个3600帧产生一个I帧
        status = VTSessionSetProperty(compressionSessionRef!, key: kVTCompressionPropertyKey_MaxKeyFrameInterval, value: 15 * 240 as AnyObject)
        assert(status == 0, "设置编码器属性 kVTCompressionPropertyKey_MaxKeyFrameInterval 失败")
        // 配置I帧的持续时间，240秒遍一个I帧
        status = VTSessionSetProperty(compressionSessionRef!, key: kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration, value: 240 as AnyObject)
        assert(status == 0, "设置编码器属性 kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration 失败")
        // 编码器准备编码
        status = VTCompressionSessionPrepareToEncodeFrames(compressionSessionRef!)
        assert(status == 0, "编码器准备编码失败")
    }
    
    public func stopVideoEncode() -> Bool {
        guard let compressionSessionRef = compressionSessionRef else { return false }
        let status = VTCompressionSessionCompleteFrames(compressionSessionRef, untilPresentationTimeStamp: CMTime.invalid)
        assert(status == noErr, "编码器停止失败，错误吗：\(status)")
        
        return status == noErr
    }
    
    @discardableResult
    public func encode(imageBuffer: CVImageBuffer) -> Bool {
        guard let compressionSessionRef = compressionSessionRef else { return false }
        let status = VTCompressionSessionEncodeFrame(compressionSessionRef, imageBuffer: imageBuffer, presentationTimeStamp: CMTime.invalid, duration: CMTime.invalid, frameProperties: nil, infoFlagsOut: nil) { status, flags, sampleBuffer in
            print("Compression EncodeFrame Callback: \(status) | \(sampleBuffer!)")
        }
        if status != noErr {
            return false
        }
        
        return true
    }
}
