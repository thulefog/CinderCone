//
//  GenericClassificationProvider.swift
//
//  Created by John Matthew Weston on 9/24/25.
//


import UIKit
import CoreML
import Vision
import AVFoundation

class GenericClassificationProvider {
    private var model: VNCoreMLModel?
    
    init() {
        loadModel()
    }
    
    // MARK: - Model Loading
    func loadModel(modelName: String? = nil) {
        guard let modelURL = Bundle.main.url(forResource: modelName, withExtension: "mlmodelc") else {
            print("Error: Could not find model file")
            return
        }
        
        do {
            let mlModel = try MLModel(contentsOf: modelURL)
            self.model = try VNCoreMLModel(for: mlModel)
            print("Model loaded successfully")
        } catch {
            print("Error loading model: \(error)")
        }
    }
    
    // MARK: - Image Processing
    func processImage(_ image: UIImage, completion: @escaping (Result<[VNClassificationObservation], Error>) -> Void) {
        guard let model = self.model else {
            completion(.failure(ProcessingError.modelNotLoaded as! Error))
            return
        }
        
        guard let cgImage = image.cgImage else {
            completion(.failure(ProcessingError.invalidImage as! Error))
            return
        }
        
        let request = VNCoreMLRequest(model: model) { request, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let results = request.results as? [VNClassificationObservation] else {
                completion(.failure(ProcessingError.invalidResults as! Error))
                return
            }
            
            completion(.success(results))
        }
        
        // Configure request properties if needed
        request.imageCropAndScaleOption = .centerCrop
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Alternative: Direct MLModel Usage
    func processImageDirect(_ image: UIImage, completion: @escaping (Result<MLFeatureProvider, Error>) -> Void) {
        guard let modelURL = Bundle.main.url(forResource: "YourModel", withExtension: "mlmodelc") else {
            completion(.failure(ProcessingError.modelNotFound as! Error))
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let model = try MLModel(contentsOf: modelURL)
                
                // Convert UIImage to CVPixelBuffer
                guard let pixelBuffer = self.createPixelBuffer(from: image, targetSize: CGSize(width: 224, height: 224)) else {
                    completion(.failure(ProcessingError.pixelBufferCreationFailed as! Error))
                    return
                }
                
                // Create input feature provider
                let input = try MLDictionaryFeatureProvider(dictionary: ["image": MLFeatureValue(pixelBuffer: pixelBuffer)])
                
                // Make prediction
                let output = try model.prediction(from: input)
                
                DispatchQueue.main.async {
                    completion(.success(output))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    private func createPixelBuffer(from image: UIImage, targetSize: CGSize) -> CVPixelBuffer? {
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue
        ] as CFDictionary
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                       Int(targetSize.width),
                                       Int(targetSize.height),
                                       kCVPixelFormatType_32ARGB,
                                       attrs,
                                       &pixelBuffer)
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        defer { CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0)) }
        
        let pixelData = CVPixelBufferGetBaseAddress(buffer)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        
        guard let context = CGContext(data: pixelData,
                                    width: Int(targetSize.width),
                                    height: Int(targetSize.height),
                                    bitsPerComponent: 8,
                                    bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                    space: rgbColorSpace,
                                    bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) else {
            return nil
        }
        
        context.translateBy(x: 0, y: targetSize.height)
        context.scaleBy(x: 1.0, y: -1.0)
        
        UIGraphicsPushContext(context)
        image.draw(in: CGRect(x: 0, y: 0, width: targetSize.width, height: targetSize.height))
        UIGraphicsPopContext()
        
        return buffer
    }
}

// MARK: - Error Types
enum ProcessingError: Error { //LocalError {
    case modelNotLoaded
    case modelNotFound
    case invalidImage
    case invalidResults
    case pixelBufferCreationFailed
    
    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "CoreML model is not loaded"
        case .modelNotFound:
            return "Model file not found in bundle"
        case .invalidImage:
            return "Invalid image provided"
        case .invalidResults:
            return "Invalid prediction results"
        case .pixelBufferCreationFailed:
            return "Failed to create pixel buffer from image"
        }
    }
}

// MARK: - Usage Example
class ViewController: UIViewController {
    private let processor = GenericClassificationProvider()
    
    @IBAction func processImageTapped(_ sender: UIButton) {
        guard let image = UIImage(named: "test_image") else { return }
        
        // Using Vision framework (recommended)
        processor.processImage(image) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let observations):
                    self?.displayResults(observations)
                case .failure(let error):
                    self?.showError(error)
                }
            }
        }
        
        // Alternative: Direct MLModel usage
        processor.processImageDirect(image) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let output):
                    self?.handleDirectOutput(output)
                case .failure(let error):
                    self?.showError(error)
                }
            }
        }
    }
    
    private func displayResults(_ observations: [VNClassificationObservation]) {
        let topResults = observations.prefix(5)
        for observation in topResults {
            print("Label: \(observation.identifier), Confidence: \(observation.confidence)")
        }
    }
    
    private func handleDirectOutput(_ output: MLFeatureProvider) {
        // Handle the raw MLFeatureProvider output
        // This depends on your specific model's output format
        print("Model output: \(output)")
    }
    
    private func showError(_ error: Error) {
        print("Error: \(error.localizedDescription)")
        // Show error to user
    }
}
