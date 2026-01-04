//
//  ImageFilterProvider.swift
//
//  Created by John Matthew Weston on 9/29/25.
//

import SwiftUI
import opencv2 //OpenCV

// MARK: - ImageFilterProvider - OpenCV
class ImageFilterProvider {
#if os(macOS)

    static func processImage( image: NSImage, type: ProcessingType) -> NSImage {
        
        // Convert NSImage to OpenCV Mat
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {  fatalError() }
        let mat = Mat(cgImage: cgImage)
        
        // Apply Canny edge detection using OpenCV
        var resultMat = Mat()
        
        switch type {
        case .original:
            return image
        case .blur:
            let grayMat = Mat()
            let medianBlurMat = Mat()
            let blurredMat = Mat()
            
            Imgproc.cvtColor(src: mat, dst: grayMat, code: ColorConversionCodes.COLOR_BGR2GRAY)
            
            // Heuristic Check: Median Blur versus Gaussian Blur
            // NB: Gaussian blur reduces noise
            Imgproc.medianBlur(src: grayMat, dst: medianBlurMat, ksize: 5)
            Imgproc.GaussianBlur(src: grayMat, dst: blurredMat, ksize: Size2i(width: 5, height: 5), sigmaX: 0)
            
            resultMat = blurredMat
            
        case .edges:
            
            let grayMat = Mat()
            let edgeMat = Mat()
            let medianBlurMat = Mat()
            
            // Heuristic Check: Median Blur versus Gaussian Blur
            // NB: Gaussian blur reduces noise
            Imgproc.medianBlur(src: grayMat, dst: medianBlurMat, ksize: 5)
            
            // Apply Canny edge detection: originals: {50.0, 150.0 }
            let minThreshold = 50.0
            let maxThreshold = 150.0
            Imgproc.Canny(image: medianBlurMat, edges: edgeMat, threshold1: minThreshold, threshold2: maxThreshold)
            
            var hierachyMat = Mat()
            var contours : NSMutableArray = []
            Imgproc.findContours(image: edgeMat,contours: contours, hierarchy: hierachyMat, mode: .RETR_EXTERNAL, method: .CHAIN_APPROX_NONE)
            
            print( "CONTOURS: N=\(contours.count): \(contours)" )
            resultMat = edgeMat
            
        case .grayscale:
            let grayMat = Mat()
            Imgproc.cvtColor(src: mat, dst: grayMat, code: ColorConversionCodes.COLOR_BGR2GRAY)
            resultMat = grayMat
            
        case .sharpen:
            print("case: sharpen")
            //let sharpenMat = Mat()
            //Imgproc.sharpen(src: mat, dst: sharpenMat, code: ColorConversionCodes.COLOR_BGR2GRAY)
            //resultImage = sharpenMat.toUIImage()
            
        }
        
        // Convert back to NSImage
        return resultMat.toNSImage()
    }
    
#else // iOS

    static func processImage(_ image: UIImage, type: ProcessingType) -> UIImage? {
         
        var resultImage: UIImage?
        let originalImage = image
        if let cgImage = originalImage.cgImage {
            let mat = Mat(cgImage: cgImage)
            
            switch type {
            case .original:
                return image
            case .blur:
                let grayMat = Mat()
                let medianBlurMat = Mat()
                Imgproc.cvtColor(src: mat, dst: grayMat, code: ColorConversionCodes.COLOR_BGR2GRAY)
                  
                Imgproc.medianBlur(src: grayMat, dst: medianBlurMat, ksize: 5)
                
                // Apply Gaussian blur to reduce noise
                let blurredMat = Mat()
                Imgproc.GaussianBlur(src: grayMat, dst: blurredMat, ksize: Size2i(width: 5, height: 5), sigmaX: 0)
                resultImage = blurredMat.toUIImage()
                
            case .edges:
                
                // MARK: Canny Edge Detect
                let maskMat = Mat()
                let grayMat = Mat()
                let edgeMat = Mat()
                let medianBlurMat = Mat()

                // Convert to grayscale
                Imgproc.cvtColor(src: mat, dst: grayMat, code: ColorConversionCodes.COLOR_BGR2GRAY)
                
                // Heuristic Check: Median Blur versus Gaussian Blur
                // NB: Gaussian blur reduces noise
                Imgproc.medianBlur(src: grayMat, dst: medianBlurMat, ksize: 5)

                let blurredMat = Mat()
                Imgproc.GaussianBlur(src: grayMat, dst: blurredMat, ksize: Size2i(width: 5, height: 5), sigmaX: 0)
                
                // Apply Canny edge detection: originals: {50.0, 150.0 }
                let minThreshold = 50.0
                let maxThreshold = 150.0
                Imgproc.Canny(image: medianBlurMat/*blurredMat*/, edges: edgeMat, threshold1: minThreshold, threshold2: maxThreshold)
                
                var hierachyMat = Mat()
                var contours : NSMutableArray = []
                Imgproc.findContours(image: edgeMat,contours: contours, hierarchy: hierachyMat, mode: .RETR_EXTERNAL, method: .CHAIN_APPROX_NONE)

                print( "CONTOURS: N=\(contours.count): \(contours)" )
                resultImage = edgeMat.toUIImage()

            case .grayscale:
                // Convert to grayscale
                let grayMat = Mat()
                Imgproc.cvtColor(src: mat, dst: grayMat, code: ColorConversionCodes.COLOR_BGR2GRAY)
                resultImage = grayMat.toUIImage()

            case .sharpen:
                print("case: sharpen") 
                //let sharpenMat = Mat()
                //Imgproc.sharpen(src: mat, dst: sharpenMat, code: ColorConversionCodes.COLOR_BGR2GRAY)
                //resultImage = sharpenMat.toUIImage()

            }
        }
        return resultImage ?? image
    }
#endif

}
