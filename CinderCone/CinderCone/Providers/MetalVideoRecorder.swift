//
//  MetalVideoRecorder.swift
//
//  Created by John Matthew Weston on 9/10/25.
//

import UIKit
import AVFoundation

/*
 - initialize MetalVideoRecorder
 - call startRecording()
 - add a scheduled handler to the command buffer containing your rendering commands
 - call writeFrame (after you end encoding, but before presenting the drawable or committing the buffer):

 let texture = currentDrawable.texture
 commandBuffer.addCompletedHandler { commandBuffer in
     self.recorder.writeFrame(forTexture: texture)
 }

 Cross References:
 
 https://stackoverflow.com/questions/43838089/capture-metal-mtkview-as-movie-in-realtime/43860229#43860229
 https://developer.apple.com/metal/sample-code/
 */

extension MTLTexture {
    var image: UIImage? {
        guard var ciImage = CIImage(mtlTexture: self) else { return nil }
        let transform = CGAffineTransformMake(1, 0, 0, -1, 0, ciImage.extent.size.height)
        ciImage = ciImage.transformed(by: transform)
        guard let cgImage = CIContext().createCGImage(ciImage, from: ciImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
    
class MetalVideoRecorder {
    var isRecording = false
    var recordingStartTime = TimeInterval(0)

    private var assetWriter: AVAssetWriter
    private var assetWriterVideoInput: AVAssetWriterInput
    private var assetWriterPixelBufferInput: AVAssetWriterInputPixelBufferAdaptor

    init?(outputURL url: URL, size: CGSize) {
        do {
          assetWriter = try AVAssetWriter(outputURL: url, fileType: AVFileType.m4v)
        } catch {
            return nil
        }

      let outputSettings: [String: Any] = [ AVVideoCodecKey : AVVideoCodecType.h264,
            AVVideoWidthKey : size.width,
            AVVideoHeightKey : size.height ]

      assetWriterVideoInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: outputSettings)
        assetWriterVideoInput.expectsMediaDataInRealTime = true

        let sourcePixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String : kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String : size.width,
            kCVPixelBufferHeightKey as String : size.height ]

        assetWriterPixelBufferInput = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: assetWriterVideoInput,
                                                                           sourcePixelBufferAttributes: sourcePixelBufferAttributes)

        assetWriter.add(assetWriterVideoInput)
    }

    func startRecording() {
        assetWriter.startWriting()
      assetWriter.startSession(atSourceTime: CMTime.zero)

        recordingStartTime = CACurrentMediaTime()
        isRecording = true
    }

    func endRecording(_ completionHandler: @escaping () -> ()) {
        isRecording = false

        assetWriterVideoInput.markAsFinished()
        
        // TODO: debug
        assetWriter.finishWriting(completionHandler: completionHandler)
    }

    func writeFrame(forTexture texture: MTLTexture) {
        if !isRecording {
            return
        }

        while !assetWriterVideoInput.isReadyForMoreMediaData {}

        guard let pixelBufferPool = assetWriterPixelBufferInput.pixelBufferPool else {
            print("Pixel buffer asset writer input did not have a pixel buffer pool available; cannot retrieve frame")
            return
        }

        var maybePixelBuffer: CVPixelBuffer? = nil
        let status  = CVPixelBufferPoolCreatePixelBuffer(nil, pixelBufferPool, &maybePixelBuffer)
        if status != kCVReturnSuccess {
            print("Could not get pixel buffer from asset writer input; dropping frame...")
            return
        }

        guard let pixelBuffer = maybePixelBuffer else { return }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        let pixelBufferBytes = CVPixelBufferGetBaseAddress(pixelBuffer)!

        // Use the bytes per row value from the pixel buffer since its stride may be rounded up to be 16-byte aligned
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let region = MTLRegionMake2D(0, 0, texture.width, texture.height)

        texture.getBytes(pixelBufferBytes, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)

        let frameTime = CACurrentMediaTime() - recordingStartTime
        let presentationTime = CMTimeMakeWithSeconds(frameTime, preferredTimescale:   240)
        assetWriterPixelBufferInput.append(pixelBuffer, withPresentationTime: presentationTime)

        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
    
        // You need to release memory allocated to pixelBuffer
        //CVPixelBufferRelease(pixelBuffer)
    }
}

