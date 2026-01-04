//
//  MetalCameraView.swift
//  CinderCone
//
//  Created by John Matthew Weston on 12/12/25.
//


import MetalKit
import AVFoundation
import CoreML
import Vision

 
// MARK: - Compute Pipeline Protocol

protocol TextureProcessor {
    func process(input: MTLTexture, commandBuffer: MTLCommandBuffer) -> MTLTexture
}

// MARK: Video Recorder

class VideoRecorder {
    
    enum State {
        case idle
        case recording
        case finishing
    }
    
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var textureCache: CVMetalTextureCache?
    
    private var startTime: CMTime?
    private let recordingQueue = DispatchQueue(label: "video.recording")
    
    private(set) var state: State = .idle
    private(set) var outputURL: URL?
    
    var onStateChanged: ((State) -> Void)?
    
    init(device: MTLDevice) {
        self.device = device
        self.commandQueue = device.makeCommandQueue()!
        
        var cache: CVMetalTextureCache?
        CVMetalTextureCacheCreate(nil, nil, device, nil, &cache)
        self.textureCache = cache
    }
    
    // MARK: - Recording Control
    
    func startRecording(width: Int, height: Int, to url: URL? = nil) throws {
        guard state == .idle else { return }
        
        let outputURL = url ?? defaultOutputURL()
        self.outputURL = outputURL
        
        // Remove existing file
        try? FileManager.default.removeItem(at: outputURL)
        
        // Setup writer
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: width * height * 4,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ]
        
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        input.expectsMediaDataInRealTime = true
        input.transform = .identity
        
        let sourceAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]
        
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: sourceAttributes
        )
        
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
        
        self.assetWriter = writer
        self.videoInput = input
        self.pixelBufferAdaptor = adaptor
        self.startTime = nil
        
        state = .recording
        onStateChanged?(.recording)
    }
    
    func stopRecording() async -> URL? {
        guard state == .recording else { return nil }
        
        state = .finishing
        onStateChanged?(.finishing)
        
        videoInput?.markAsFinished()
        await assetWriter?.finishWriting()
        
        let url = outputURL
        
        // Cleanup
        assetWriter = nil
        videoInput = nil
        pixelBufferAdaptor = nil
        startTime = nil
        
        state = .idle
        onStateChanged?(.idle)
        
        return url
    }
    
    // MARK: - Frame Writing
    
    func writeFrame(_ texture: MTLTexture, timestamp: CMTime? = nil) {
        guard state == .recording,
              let input = videoInput,
              let adaptor = pixelBufferAdaptor,
              let pool = adaptor.pixelBufferPool,
              input.isReadyForMoreMediaData else {
            return
        }
        
        recordingQueue.async { [weak self] in
            self?.writeFrameSync(texture, timestamp: timestamp, adaptor: adaptor, pool: pool)
        }
    }
    
    private func writeFrameSync(_ texture: MTLTexture,
                                 timestamp: CMTime?,
                                 adaptor: AVAssetWriterInputPixelBufferAdaptor,
                                 pool: CVPixelBufferPool) {
        // Calculate presentation time
        let now = CMClockGetTime(CMClockGetHostTimeClock())
        if startTime == nil {
            startTime = now
        }
        let presentationTime = timestamp ?? CMTimeSubtract(now, startTime!)
        
        // Create pixel buffer
        var pixelBuffer: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer) == kCVReturnSuccess,
              let buffer = pixelBuffer else {
            return
        }
        
        // Copy texture to pixel buffer using GPU
        copyTextureToPixelBuffer(texture, pixelBuffer: buffer)
        
        // Append
        adaptor.append(buffer, withPresentationTime: presentationTime)
    }
    
    private func copyTextureToPixelBuffer(_ texture: MTLTexture, pixelBuffer: CVPixelBuffer) {
        guard let cache = textureCache else { return }
        
        var cvTexture: CVMetalTexture?
        let status = CVMetalTextureCacheCreateTextureFromImage(
            nil, cache, pixelBuffer, nil,
            .bgra8Unorm,
            texture.width, texture.height, 0,
            &cvTexture
        )
        
        guard status == kCVReturnSuccess,
              let cvTex = cvTexture,
              let destTexture = CVMetalTextureGetTexture(cvTex),
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let blit = commandBuffer.makeBlitCommandEncoder() else {
            return
        }
        
        blit.copy(
            from: texture,
            sourceSlice: 0, sourceLevel: 0,
            sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
            sourceSize: MTLSize(width: texture.width, height: texture.height, depth: 1),
            to: destTexture,
            destinationSlice: 0, destinationLevel: 0,
            destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0)
        )
        
        blit.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
    
    private func defaultOutputURL() -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let filename = "recording_\(formatter.string(from: Date())).mp4"
        return FileManager.default.temporaryDirectory.appendingPathComponent(filename)
    }
}

// MARK: - CoreML Processor

/// Result from ML inference
struct MLInferenceResult {
    let classifications: [Classification]
    let boundingBoxes: [BoundingBox]
    let segmentationMask: MTLTexture?
    let confidence: Float
    var inferenceTime: TimeInterval
    
    struct Classification {
        let label: String
        let confidence: Float
    }
    
    struct BoundingBox {
        let label: String
        let confidence: Float
        let rect: CGRect  // Normalized 0-1
    }
    
    static let empty = MLInferenceResult(
        classifications: [],
        boundingBoxes: [],
        segmentationMask: nil,
        confidence: 0,
        inferenceTime: 0
    )
}

/// Protocol for ML result rendering
protocol MLResultRenderer {
    func render(result: MLInferenceResult, onto texture: MTLTexture, commandBuffer: MTLCommandBuffer) -> MTLTexture
}

/// CoreML-based texture processor with inference callback
class CoreMLProcessor: TextureProcessor {
    
    private let device: MTLDevice
    private let model: VNCoreMLModel
    private var request: VNCoreMLRequest!
    
    private var latestResult: MLInferenceResult = .empty
    private let resultLock = NSLock()
    
    private var resultRenderer: MLResultRenderer?
    
    /// Called on each inference with the result
    var onInferenceComplete: ((MLInferenceResult) -> Void)?
    
    /// Process every Nth frame (1 = every frame)
    var inferenceInterval: Int = 1
    private var frameCount = 0
    
    init?(device: MTLDevice, modelURL: URL, renderer: MLResultRenderer? = nil) {
        self.device = device
        self.resultRenderer = renderer
        
        do {
            let config = MLModelConfiguration()
            config.computeUnits = .all
            
            let mlModel = try MLModel(contentsOf: modelURL, configuration: config)
            self.model = try VNCoreMLModel(for: mlModel)
        } catch {
            print("Failed to load CoreML model: \(error)")
            return nil
        }
        
        setupRequest()
    }
    
    /// Initialize with a compiled MLModel directly
    init?(device: MTLDevice, mlModel: MLModel, renderer: MLResultRenderer? = nil) {
        self.device = device
        self.resultRenderer = renderer
        
        do {
            self.model = try VNCoreMLModel(for: mlModel)
        } catch {
            print("Failed to create VNCoreMLModel: \(error)")
            return nil
        }
        
        setupRequest()
    }
    
    private func setupRequest() {
        request = VNCoreMLRequest(model: model) { [weak self] request, error in
            self?.processResults(request.results, error: error)
        }
        request.imageCropAndScaleOption = .scaleFill
    }
    
    func process(input: MTLTexture, commandBuffer: MTLCommandBuffer) -> MTLTexture {
        frameCount += 1
        
        // Run inference at specified interval
        if frameCount % inferenceInterval == 0 {
            runInference(on: input)
        }
        
        // Render results onto texture if renderer is available
        if let renderer = resultRenderer {
            resultLock.lock()
            let result = latestResult
            resultLock.unlock()
            
            return renderer.render(result: result, onto: input, commandBuffer: commandBuffer)
        }
        
        return input
    }
    
    private func runInference(on texture: MTLTexture) {
        let startTime = CACurrentMediaTime()
        
        // Convert texture to CVPixelBuffer for Vision
        guard let pixelBuffer = textureToPixelBuffer(texture) else { return }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        
        // Run asynchronously to not block render thread
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            try? handler.perform([self?.request].compactMap { $0 })
            
            let inferenceTime = CACurrentMediaTime() - startTime
            self?.resultLock.lock()
            self?.latestResult.inferenceTime = inferenceTime
            self?.resultLock.unlock()
        }
    }
    
    
    // NOTE:
    // - this reflects a bias towards inital YOLOv3 where bounding box is an output
    // - for MobileNet, the inference output will be a classification with confidence, no box
    // - for MedSAM2, a bounding box would be an input to guide segmentation forward pass
    
    private func processResults(_ results: [Any]?, error: Error?) {
        guard error == nil, let results = results else { return }
        
        var inferenceResult = MLInferenceResult.empty
        
        // Handle different result types
        if let classifications = results as? [VNClassificationObservation] {
            inferenceResult = MLInferenceResult(
                classifications: classifications.prefix(5).map {
                    MLInferenceResult.Classification(label: $0.identifier, confidence: $0.confidence)
                },
                boundingBoxes: [],
                segmentationMask: nil,
                confidence: classifications.first?.confidence ?? 0,
                inferenceTime: latestResult.inferenceTime
            )
        } else if let detections = results as? [VNRecognizedObjectObservation] {
            inferenceResult = MLInferenceResult(
                classifications: [],
                boundingBoxes: detections.map { detection in
                    MLInferenceResult.BoundingBox(
                        label: detection.labels.first?.identifier ?? "unknown",
                        confidence: detection.confidence,
                        rect: detection.boundingBox
                    )
                },
                segmentationMask: nil,
                confidence: detections.first?.confidence ?? 0,
                inferenceTime: latestResult.inferenceTime
            )
        }
        
        resultLock.lock()
        latestResult = inferenceResult
        resultLock.unlock()
        
        DispatchQueue.main.async { [weak self] in
            self?.onInferenceComplete?(inferenceResult)
        }
    }
    
    private func textureToPixelBuffer(_ texture: MTLTexture) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferMetalCompatibilityKey as String: true,
            kCVPixelBufferCGImageCompatibilityKey as String: true
        ]
        
        CVPixelBufferCreate(
            nil,
            texture.width,
            texture.height,
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &pixelBuffer
        )
        
        guard let buffer = pixelBuffer else { return nil }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(buffer) else { return nil }
        
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let region = MTLRegionMake2D(0, 0, texture.width, texture.height)
        
        texture.getBytes(baseAddress, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
        
        return buffer
    }
}

// MARK: - Bounding Box Renderer

class BoundingBoxRenderer: MLResultRenderer {
    
    private let device: MTLDevice
    private let pipelineState: MTLRenderPipelineState
    
    var boxColor: SIMD4<Float> = SIMD4(0, 1, 0, 1)  // Green
    var lineWidth: Float = 3.0
    var showLabels: Bool = true
    
    init(device: MTLDevice) {
        self.device = device
        
        let shaderSource = """
        #include <metal_stdlib>
        using namespace metal;
        
        struct VertexOut {
            float4 position [[position]];
            float4 color;
        };
        
        vertex VertexOut box_vertex(const device float2* vertices [[buffer(0)]],
                                    constant float4& color [[buffer(1)]],
                                    uint vid [[vertex_id]]) {
            VertexOut out;
            out.position = float4(vertices[vid], 0, 1);
            out.color = color;
            return out;
        }
        
        fragment float4 box_fragment(VertexOut in [[stage_in]]) {
            return in.color;
        }
        """
        
        let library = try! device.makeLibrary(source: shaderSource, options: nil)
        
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "box_vertex")
        descriptor.fragmentFunction = library.makeFunction(name: "box_fragment")
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        
        pipelineState = try! device.makeRenderPipelineState(descriptor: descriptor)
    }
    
    func render(result: MLInferenceResult, onto texture: MTLTexture, commandBuffer: MTLCommandBuffer) -> MTLTexture {
        guard !result.boundingBoxes.isEmpty else { return texture }
        
        // Create output texture
        let outputDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: texture.pixelFormat,
            width: texture.width,
            height: texture.height,
            mipmapped: false
        )
        outputDescriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
        
        let output = device.makeTexture(descriptor: outputDescriptor)!
        
        // Copy input to output first
        if let blit = commandBuffer.makeBlitCommandEncoder() {
            blit.copy(from: texture, to: output)
            blit.endEncoding()
        }
        
        // Draw boxes
        let renderDescriptor = MTLRenderPassDescriptor()
        renderDescriptor.colorAttachments[0].texture = output
        renderDescriptor.colorAttachments[0].loadAction = .load
        renderDescriptor.colorAttachments[0].storeAction = .store
        
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderDescriptor) else {
            return texture
        }
        
        encoder.setRenderPipelineState(pipelineState)
        
        if( result.boundingBoxes.count == 0 ) {
            print( "Inference result has no bounding boxes - verify model input and outputs" )
        }
        
        for box in result.boundingBoxes {
            drawBox(box.rect, encoder: encoder, textureSize: CGSize(width: texture.width, height: texture.height))
        }
        
        encoder.endEncoding()
        
        return output
    }
    
    private func drawBox(_ rect: CGRect, encoder: MTLRenderCommandEncoder, textureSize: CGSize) {
        // Convert normalized rect to clip space (-1 to 1)
        // Vision coordinates: origin bottom-left, y-up
        // Metal clip space: origin center, y-up
        let minX = Float(rect.minX) * 2 - 1
        let maxX = Float(rect.maxX) * 2 - 1
        let minY = Float(rect.minY) * 2 - 1
        let maxY = Float(rect.maxY) * 2 - 1
        
        // Box vertices (line strip)
        var vertices: [SIMD2<Float>] = [
            SIMD2(minX, minY),
            SIMD2(maxX, minY),
            SIMD2(maxX, maxY),
            SIMD2(minX, maxY),
            SIMD2(minX, minY)
        ]
        
        var color = boxColor
        
        encoder.setVertexBytes(&vertices, length: MemoryLayout<SIMD2<Float>>.stride * vertices.count, index: 0)
        encoder.setVertexBytes(&color, length: MemoryLayout<SIMD4<Float>>.size, index: 1)
        encoder.drawPrimitives(type: .lineStrip, vertexStart: 0, vertexCount: vertices.count)
    }
}

// MARK: - MetalCameraView (inner) - includes ML Inference Pipeline plus Recording

class MetalCameraView: MTKView, MTKViewDelegate {
    
    // MARK: - Public Properties
    
    var aspectRatioMode: AspectRatioMode = .fit {
        didSet { updateVertexBuffer() }
    }
    
    var displayTexture: MTLTexture? {
        didSet { updateVertexBuffer() }
    }
    
    var textureProcessor: TextureProcessor?
    var onFrameRendered: ((MTLTexture) -> Void)?
    
    /// Video recorder instance
    private(set) var recorder: VideoRecorder?
    var isRecording: Bool { recorder?.state == .recording }
    
    /// Latest ML inference result
    private(set) var latestMLResult: MLInferenceResult = .empty
    var onMLResult: ((MLInferenceResult) -> Void)?
    
    // MARK: - Private Properties
    
    private var commandQueue: MTLCommandQueue!
    private var renderPipelineState: MTLRenderPipelineState!
    private var samplerState: MTLSamplerState!
    private var vertexBuffer: MTLBuffer!
    
    private var cameraManager: CameraManager?
    
    // MARK: - Initialization
    
    override init(frame: CGRect, device: MTLDevice?) {
        super.init(frame: frame, device: device ?? MTLCreateSystemDefaultDevice())
        commonInit()
    }
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
        device = MTLCreateSystemDefaultDevice()
        commonInit()
    }
    
    private func commonInit() {
        guard let device else { return }
        
        commandQueue = device.makeCommandQueue()
        recorder = VideoRecorder(device: device)
        
        colorPixelFormat = .bgra8Unorm
        delegate = self
        
        isPaused = false
        enableSetNeedsDisplay = false
        preferredFramesPerSecond = 60
        
        setupPipeline()
        setupSampler()
        updateVertexBuffer()
    }
    
    // MARK: - Camera Control
    
    func startCamera(position: AVCaptureDevice.Position = .back) {
        cameraManager = CameraManager(device: device!)
        cameraManager?.onTextureReady = { [weak self] texture in
            self?.displayTexture = texture
        }
        cameraManager?.start(position: position)
    }
    
    func stopCamera() {
        cameraManager?.stop()
        cameraManager = nil
    }
    
    // MARK: - Recording Control
    
    func startRecording() throws {
        guard let texture = displayTexture else { return }
        try recorder?.startRecording(width: texture.width, height: texture.height)
    }
    
    func stopRecording() async -> URL? {
        return await recorder?.stopRecording()
    }
    
    // MARK: - CoreML Setup
    
    func setupMLProcessor(modelURL: URL, inferenceInterval: Int = 2) {
        let boxRenderer = BoundingBoxRenderer(device: device!)
        
        guard let processor = CoreMLProcessor(
            device: device!,
            modelURL: modelURL,
            renderer: boxRenderer
        ) else {
            print("Failed to create ML processor")
            return
        }
        
        processor.inferenceInterval = inferenceInterval
        processor.onInferenceComplete = { [weak self] result in
            self?.latestMLResult = result
            self?.onMLResult?(result)
        }
        
        self.textureProcessor = processor
    }
    
    // MARK: - Pipeline Setup
    
    private func setupPipeline() {
        let shaderSource = """
        #include <metal_stdlib>
        using namespace metal;
        
        struct Vertex {
            float2 position;
            float2 texCoord;
        };
        
        struct VertexOut {
            float4 position [[position]];
            float2 texCoord;
        };
        
        vertex VertexOut vertex_main(const device Vertex* vertices [[buffer(0)]],
                                     uint vertexID [[vertex_id]]) {
            VertexOut out;
            out.position = float4(vertices[vertexID].position, 0, 1);
            out.texCoord = vertices[vertexID].texCoord;
            return out;
        }
        
        fragment float4 fragment_main(VertexOut in [[stage_in]],
                                      texture2d<float> texture [[texture(0)]],
                                      sampler textureSampler [[sampler(0)]]) {
            return texture.sample(textureSampler, in.texCoord);
        }
        """
        
        guard let library = try? device?.makeLibrary(source: shaderSource, options: nil) else {
            fatalError("Failed to create shader library")
        }
        
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "vertex_main")
        descriptor.fragmentFunction = library.makeFunction(name: "fragment_main")
        descriptor.colorAttachments[0].pixelFormat = colorPixelFormat
        
        renderPipelineState = try! device?.makeRenderPipelineState(descriptor: descriptor)
    }
    
    private func setupSampler() {
        let descriptor = MTLSamplerDescriptor()
        descriptor.minFilter = .linear
        descriptor.magFilter = .linear
        descriptor.sAddressMode = .clampToEdge
        descriptor.tAddressMode = .clampToEdge
        samplerState = device?.makeSamplerState(descriptor: descriptor)
    }
    
    private func updateVertexBuffer() {
        let viewAspect = drawableSize.width / drawableSize.height
        let textureAspect: CGFloat
        
        if let texture = displayTexture {
            textureAspect = CGFloat(texture.width) / CGFloat(texture.height)
        } else {
            textureAspect = 16.0 / 9.0
        }
        
        var scaleX: Float = 1.0
        var scaleY: Float = 1.0
        
        switch aspectRatioMode {
        case .fit:
            if viewAspect > textureAspect {
                scaleX = Float(textureAspect / viewAspect)
            } else {
                scaleY = Float(viewAspect / textureAspect)
            }
        case .fill:
            if viewAspect > textureAspect {
                scaleY = Float(viewAspect / textureAspect)
            } else {
                scaleX = Float(textureAspect / viewAspect)
            }
        case .stretch:
            break
        }
        
        struct Vertex {
            var position: SIMD2<Float>
            var texCoord: SIMD2<Float>
        }
        
        let vertices: [Vertex] = [
            Vertex(position: SIMD2(-scaleX, -scaleY), texCoord: SIMD2(0, 1)),
            Vertex(position: SIMD2( scaleX, -scaleY), texCoord: SIMD2(1, 1)),
            Vertex(position: SIMD2(-scaleX,  scaleY), texCoord: SIMD2(0, 0)),
            Vertex(position: SIMD2( scaleX,  scaleY), texCoord: SIMD2(1, 0)),
        ]
        
        vertexBuffer = device?.makeBuffer(
            bytes: vertices,
            length: MemoryLayout<Vertex>.stride * vertices.count,
            options: .storageModeShared
        )
    }
    
    // MARK: - MTKViewDelegate
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        updateVertexBuffer()
    }
    
    func draw(in view: MTKView) {
        guard var texture = displayTexture,
              let drawable = currentDrawable,
              let descriptor = currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            return
        }
        
        // Apply processing
        if let processor = textureProcessor {
            texture = processor.process(input: texture, commandBuffer: commandBuffer)
        }
        
        // Record if active
        if isRecording {
            recorder?.writeFrame(texture)
        }
        
        // Render to screen
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            return
        }
        
        encoder.setRenderPipelineState(renderPipelineState)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.setFragmentTexture(texture, index: 0)
        encoder.setFragmentSamplerState(samplerState, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()
        
        commandBuffer.present(drawable)
        
        let finalTexture = texture
        commandBuffer.addCompletedHandler { [weak self] _ in
            self?.onFrameRendered?(finalTexture)
        }
        
        commandBuffer.commit()
    }
}

// MARK: - Camera Manager

class CameraManager: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    private let device: MTLDevice
    private let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let processingQueue = DispatchQueue(label: "camera.processing")
    
    private var textureCache: CVMetalTextureCache?
    
    var onTextureReady: ((MTLTexture) -> Void)?
    
    init(device: MTLDevice) {
        self.device = device
        super.init()
        
        CVMetalTextureCacheCreate(nil, nil, device, nil, &textureCache)
    }
    
    func start(position: AVCaptureDevice.Position) {
        session.beginConfiguration()
        session.sessionPreset = .hd1920x1080
        
        // Find camera
        guard let camera = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: position
        ) else {
            print("Camera not available")
            return
        }
        
        // Add input
        guard let input = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(input) else {
            return
        }
        session.addInput(input)
        
        // Configure output
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.setSampleBufferDelegate(self, queue: processingQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        
        guard session.canAddOutput(videoOutput) else { return }
        session.addOutput(videoOutput)
        
        // Set orientation
        if let connection = videoOutput.connection(with: .video) {
            #if os(iOS)
            connection.videoRotationAngle = 90
            #endif
        }
        
        session.commitConfiguration()
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.startRunning()
        }
    }
    
    func stop() {
        session.stopRunning()
    }
    
    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
    
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let cache = textureCache else {
            return
        }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        var cvTexture: CVMetalTexture?
        let status = CVMetalTextureCacheCreateTextureFromImage(
            nil,
            cache,
            pixelBuffer,
            nil,
            .bgra8Unorm,
            width,
            height,
            0,
            &cvTexture
        )
        
        guard status == kCVReturnSuccess,
              let cvTex = cvTexture,
              let texture = CVMetalTextureGetTexture(cvTex) else {
            return
        }
        
        DispatchQueue.main.async {
            self.onTextureReady?(texture)
        }
    }
}

// MARK: - Example Compute Processors

/// Grayscale conversion processor
class GrayscaleProcessor: TextureProcessor {
    
    private let device: MTLDevice
    private let pipelineState: MTLComputePipelineState
    
    init(device: MTLDevice) {
        self.device = device
        
        let shaderSource = """
        #include <metal_stdlib>
        using namespace metal;
        
        kernel void grayscale(texture2d<float, access::read> input [[texture(0)]],
                              texture2d<float, access::write> output [[texture(1)]],
                              uint2 gid [[thread_position_in_grid]]) {
            if (gid.x >= input.get_width() || gid.y >= input.get_height()) return;
            
            float4 color = input.read(gid);
            float gray = dot(color.rgb, float3(0.299, 0.587, 0.114));
            output.write(float4(gray, gray, gray, color.a), gid);
        }
        """
        
        let library = try! device.makeLibrary(source: shaderSource, options: nil)
        let function = library.makeFunction(name: "grayscale")!
        pipelineState = try! device.makeComputePipelineState(function: function)
    }
    
    func process(input: MTLTexture, commandBuffer: MTLCommandBuffer) -> MTLTexture {
        let outputDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: input.pixelFormat,
            width: input.width,
            height: input.height,
            mipmapped: false
        )
        outputDescriptor.usage = [.shaderRead, .shaderWrite]
        
        let output = device.makeTexture(descriptor: outputDescriptor)!
        
        let encoder = commandBuffer.makeComputeCommandEncoder()!
        encoder.setComputePipelineState(pipelineState)
        encoder.setTexture(input, index: 0)
        encoder.setTexture(output, index: 1)
        
        let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadGroups = MTLSize(
            width: (input.width + 15) / 16,
            height: (input.height + 15) / 16,
            depth: 1
        )
        
        encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        encoder.endEncoding()
        
        return output
    }
}

/// Color adjustment processor with configurable parameters
class ColorAdjustmentProcessor: TextureProcessor {
    
    private let device: MTLDevice
    private let pipelineState: MTLComputePipelineState
    
    var brightness: Float = 0.0  // -1 to 1
    var contrast: Float = 1.0    // 0 to 2
    var saturation: Float = 1.0  // 0 to 2
    
    init(device: MTLDevice) {
        self.device = device
        
        let shaderSource = """
        #include <metal_stdlib>
        using namespace metal;
        
        struct Params {
            float brightness;
            float contrast;
            float saturation;
        };
        
        kernel void colorAdjust(texture2d<float, access::read> input [[texture(0)]],
                                texture2d<float, access::write> output [[texture(1)]],
                                constant Params& params [[buffer(0)]],
                                uint2 gid [[thread_position_in_grid]]) {
            if (gid.x >= input.get_width() || gid.y >= input.get_height()) return;
            
            float4 color = input.read(gid);
            
            // Brightness
            color.rgb += params.brightness;
            
            // Contrast
            color.rgb = (color.rgb - 0.5) * params.contrast + 0.5;
            
            // Saturation
            float gray = dot(color.rgb, float3(0.299, 0.587, 0.114));
            color.rgb = mix(float3(gray), color.rgb, params.saturation);
            
            output.write(saturate(color), gid);
        }
        """
        
        let library = try! device.makeLibrary(source: shaderSource, options: nil)
        let function = library.makeFunction(name: "colorAdjust")!
        pipelineState = try! device.makeComputePipelineState(function: function)
    }
    
    func process(input: MTLTexture, commandBuffer: MTLCommandBuffer) -> MTLTexture {
        let outputDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: input.pixelFormat,
            width: input.width,
            height: input.height,
            mipmapped: false
        )
        outputDescriptor.usage = [.shaderRead, .shaderWrite]
        
        let output = device.makeTexture(descriptor: outputDescriptor)!
        
        var params = (brightness, contrast, saturation)
        
        let encoder = commandBuffer.makeComputeCommandEncoder()!
        encoder.setComputePipelineState(pipelineState)
        encoder.setTexture(input, index: 0)
        encoder.setTexture(output, index: 1)
        encoder.setBytes(&params, length: MemoryLayout.size(ofValue: params), index: 0)
        
        let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadGroups = MTLSize(
            width: (input.width + 15) / 16,
            height: (input.height + 15) / 16,
            depth: 1
        )
        
        encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        encoder.endEncoding()
        
        return output
    }
}

/// Chain multiple processors together
class ProcessorChain: TextureProcessor {
    
    private var processors: [TextureProcessor] = []
    
    func add(_ processor: TextureProcessor) {
        processors.append(processor)
    }
    
    func process(input: MTLTexture, commandBuffer: MTLCommandBuffer) -> MTLTexture {
        var current = input
        for processor in processors {
            current = processor.process(input: current, commandBuffer: commandBuffer)
        }
        return current
    }
}

// MARK: Metal Camera Preview (middle)

/*
#if os(iOS)
typealias ViewRepresentable = UIViewRepresentable
#else
typealias ViewRepresentable = NSViewRepresentable
#endif
*/

struct MetalCameraPreview: ViewRepresentable {
    
    let aspectRatioMode: AspectRatioMode
    let processor: TextureProcessor?
    let onFrame: ((MTLTexture) -> Void)?
    
    init(
        aspectRatioMode: AspectRatioMode = .fit,
        processor: TextureProcessor? = nil,
        onFrame: ((MTLTexture) -> Void)? = nil
    ) {
        self.aspectRatioMode = aspectRatioMode
        self.processor = processor
        self.onFrame = onFrame
    }
    
    #if os(iOS)
    func makeUIView(context: Context) -> MetalCameraView {
        makeView()
    }
    
    func updateUIView(_ view: MetalCameraView, context: Context) {
        updateView(view)
    }
    #else
    func makeNSView(context: Context) -> MetalCameraView {
        makeView()
    }
    
    func updateNSView(_ view: MetalCameraView, context: Context) {
        updateView(view)
    }
    #endif
    
    private func makeView() -> MetalCameraView {
        let view = MetalCameraView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        view.aspectRatioMode = aspectRatioMode
        view.textureProcessor = processor
        view.onFrameRendered = onFrame
        view.startCamera(position: .back)
        return view
    }
    
    private func updateView(_ view: MetalCameraView) {
        view.aspectRatioMode = aspectRatioMode
        view.textureProcessor = processor
        view.onFrameRendered = onFrame
    }
}

// MARK: CameraProcessingViewport (outer)

// CameraProcessingViewport > MetalCameraPreview (middle) > MetalCameraView (inner)

struct CameraProcessingViewport: View {
    
    @State private var aspectMode: AspectRatioMode = .fit
    @State private var brightness: Float = 0.0
    @State private var contrast: Float = 1.0
    @State private var saturation: Float = 1.0
    @State private var enableGrayscale = false
    
    private let device = MTLCreateSystemDefaultDevice()!
    
    var body: some View {
        VStack(spacing: 0) {
            MetalCameraPreview(
                aspectRatioMode: aspectMode,
                processor: buildProcessor(),
                onFrame: { texture in
                    // Access each processed frame here
                    // e.g., for recording, ML inference, etc.
                }
            )
            .ignoresSafeArea()
            
            controlPanel
        }
    }
    
    private var controlPanel: some View {
        VStack(spacing: 12) {
            // Aspect ratio picker
            Picker("Aspect", selection: $aspectMode) {
                Text("Fit").tag(AspectRatioMode.fit)
                Text("Fill").tag(AspectRatioMode.fill)
                Text("Stretch").tag(AspectRatioMode.stretch)
            }
            .pickerStyle(.segmented)
            
            Toggle("Grayscale", isOn: $enableGrayscale)
            
            if !enableGrayscale {
                LabeledSlider("Brightness", value: $brightness, range: -1...1)
                LabeledSlider("Contrast", value: $contrast, range: 0...2)
                LabeledSlider("Saturation", value: $saturation, range: 0...2)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }
    
    private func buildProcessor() -> TextureProcessor? {
        if enableGrayscale {
            return GrayscaleProcessor(device: device)
        }
        
        // Only create color processor if values differ from defaults
        if brightness != 0 || contrast != 1 || saturation != 1 {
            let processor = ColorAdjustmentProcessor(device: device)
            processor.brightness = brightness
            processor.contrast = contrast
            processor.saturation = saturation
            return processor
        }
        
        return nil
    }
}

struct LabeledSlider: View {
    let label: String
    @Binding var value: Float
    let range: ClosedRange<Float>
    
    init(_ label: String, value: Binding<Float>, range: ClosedRange<Float>) {
        self.label = label
        self._value = value
        self.range = range
    }
    
    var body: some View {
        HStack {
            Text(label)
                .frame(width: 80, alignment: .leading)
            Slider(value: $value, in: range)
            Text(String(format: "%.2f", value))
                .frame(width: 50)
                .monospacedDigit()
        }
    }
}

import SwiftUI
import PhotosUI


// MARK: CameraMLView (outer)

// CameraMLView (outer) > CameraPreviewView (middle) > MetalCameraView (inner)
// Data Path: Metal Texture - Camera plus ML Inference Pipeline (outer)
// NOTE:
// - MetalCameraView is point of contact to CoreMLProcessor

// VERSUS --> CameraProcessingViewport > MetalCameraPreview (middle) > MetalCameraView (inner)

struct CameraMLView: View {
    
    @State private var isRecording = false
    @State private var recordingTime: TimeInterval = 0
    @State private var mlResult: MLInferenceResult = .empty
    @State private var savedVideoURL: URL?
    @State private var showSaveAlert = false
    
    @State private var aspectMode: AspectRatioMode = .fill
    @State private var inferenceInterval: Double = 2
    
    private let device = MTLCreateSystemDefaultDevice()!
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            // Camera preview
            CameraPreviewView(
                aspectRatioMode: aspectMode,
                inferenceInterval: Int(inferenceInterval),
                isRecording: $isRecording,
                mlResult: $mlResult,
                savedVideoURL: $savedVideoURL
            )
            .ignoresSafeArea()
            
            // Overlay UI
            VStack {
                // Top bar - ML results
                mlResultsBar
                
                Spacer()
                
                // Bottom controls
                controlsPanel
            }
        }
        .alert("Video Saved", isPresented: $showSaveAlert) {
            Button("OK") {}
            if let url = savedVideoURL {
                Button("Share") { shareVideo(url) }
            }
        } message: {
            Text("Recording saved to \(savedVideoURL?.lastPathComponent ?? "file")")
        }
        .onChange(of: savedVideoURL) { _, newValue in
            if newValue != nil {
                showSaveAlert = true
            }
        }
    }
    
    private var mlResultsBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !mlResult.classifications.isEmpty {
                ForEach(mlResult.classifications.prefix(3), id: \.label) { classification in
                    HStack {
                        Text(classification.label)
                            .fontWeight(.medium)
                        Spacer()
                        Text("\(Int(classification.confidence * 100))%")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            if !mlResult.boundingBoxes.isEmpty {
                Text("\(mlResult.boundingBoxes.count) objects detected")
                ForEach(mlResult.boundingBoxes.prefix(5), id: \.label) { box in
                    Text("• \(box.label): \(Int(box.confidence * 100))%")
                        .font(.caption)
                }
            }
            
            if mlResult.inferenceTime > 0 {
                Text("Inference: \(String(format: "%.1f", mlResult.inferenceTime * 1000))ms")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding()
    }
    
    private var controlsPanel: some View {
        VStack(spacing: 16) {
            // Recording indicator
            if isRecording {
                HStack {
                    Circle()
                        .fill(.red)
                        .frame(width: 12, height: 12)
                    Text(formatTime(recordingTime))
                        .monospacedDigit()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
                .onReceive(timer) { _ in
                    if isRecording { recordingTime += 0.1 }
                }
            }
            
            HStack(spacing: 32) {
                // Aspect ratio toggle
                Button {
                    aspectMode = aspectMode == .fit ? .fill : .fit
                } label: {
                    Image(systemName: aspectMode == .fit ? "rectangle.arrowtriangle.2.inward" : "rectangle.arrowtriangle.2.outward")
                        .font(.title2)
                }
                
                // Record button
                Button {
                    isRecording.toggle()
                    if !isRecording {
                        recordingTime = 0
                    }
                } label: {
                    ZStack {
                        Circle()
                            .strokeBorder(.white, lineWidth: 4)
                            .frame(width: 72, height: 72)
                        
                        if isRecording {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(.red)
                                .frame(width: 28, height: 28)
                        } else {
                            Circle()
                                .fill(.red)
                                .frame(width: 56, height: 56)
                        }
                    }
                }
                
                // Inference rate
                Menu {
                    ForEach([1, 2, 4, 8], id: \.self) { interval in
                        Button("Every \(interval) frame\(interval > 1 ? "s" : "")") {
                            inferenceInterval = Double(interval)
                        }
                    }
                } label: {
                    Image(systemName: "brain")
                        .font(.title2)
                }
            }
            .foregroundStyle(.white)
        }
        .padding(.bottom, 32)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let tenths = Int((time.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d:%02d.%d", minutes, seconds, tenths)
    }
    
    private func shareVideo(_ url: URL) {
        #if os(iOS)
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
        #endif
    }
}

// MARK: - Camera Preview Representable (middle)

// NOTE: contact point for ML model wire up
struct CameraPreviewView: ViewRepresentable {
    
    let aspectRatioMode: AspectRatioMode
    let inferenceInterval: Int
    @Binding var isRecording: Bool
    @Binding var mlResult: MLInferenceResult
    @Binding var savedVideoURL: URL?
    
    #if os(iOS)
    func makeUIView(context: Context) -> MetalCameraView { makeView(context: context) }
    func updateUIView(_ view: MetalCameraView, context: Context) { updateView(view, context: context) }
    #else
    func makeNSView(context: Context) -> MetalCameraView { makeView(context: context) }
    func updateNSView(_ view: MetalCameraView, context: Context) { updateView(view, context: context) }
    #endif
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func makeView(context: Context) -> MetalCameraView {
        let view = MetalCameraView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        view.aspectRatioMode = aspectRatioMode
        
        // Setup ML - use your model URL here
        // Example: YOLOv3, MobileNet, etc.
        
        if let modelURL = Bundle.main.url(forResource: "MobileNet", withExtension: "mlmodelc") {
        //if let modelURL = Bundle.main.url(forResource: "YOLOv3", withExtension: "mlmodelc") {
            view.setupMLProcessor(modelURL: modelURL, inferenceInterval: inferenceInterval)
        } else {
            print("Problem loading model from bundle")
        }
        
        view.onMLResult = { result in
            DispatchQueue.main.async {
                mlResult = result
            }
        }
        
        view.startCamera(position: .back)
        context.coordinator.view = view
        
        return view
    }
    
    private func updateView(_ view: MetalCameraView, context: Context) {
        view.aspectRatioMode = aspectRatioMode
        
        // Update inference interval
        if let processor = view.textureProcessor as? CoreMLProcessor {
            processor.inferenceInterval = inferenceInterval
        }
        
        // Handle recording state changes
        if isRecording && !view.isRecording {
            try? view.startRecording()
        } else if !isRecording && view.isRecording {
            Task {
                if let url = await view.stopRecording() {
                    await MainActor.run {
                        savedVideoURL = url
                    }
                }
            }
        }
    }
    
    class Coordinator {
        var parent: CameraPreviewView
        weak var view: MetalCameraView?
        
        init(_ parent: CameraPreviewView) {
            self.parent = parent
        }
    }
}



