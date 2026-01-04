//
//  MetalTextureViewport.swift
//
//  Created by John Matthew Weston on 12/12/25.
//

import SwiftUI
import MetalKit
import UniformTypeIdentifiers

// MARK: Metal Texture Viewport (outer)

// MetalTextureViewport > MetalTextureView > TextureDisplayView

struct MetalTextureViewport: View {
    @State private var texture: MTLTexture?
    @State private var selectedFileURL: URL?
    @State private var showingFilePicker = false
    
    var body: some View {
        MetalTextureView(texture: texture)
            .onAppear { loadTexture() }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button("Open File") {
                            showingFilePicker = true
                        }
                    } label: {
                        Label("toolbar", systemImage: "mountain.2")
                    }
                } // toolbaritem
                if let url = selectedFileURL {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Clear") {
                            selectedFileURL = nil
                            loadTexture()
                        }
                    }
                }
            } // toolbar
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [
                    UTType(filenameExtension: "jpg")!,
                    UTType(filenameExtension: "png")!
                ],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        selectedFileURL = url
                        loadTexture()
                    }
                case .failure(let error):
                    print("Failed to select file: \(error.localizedDescription)")
                }
            }
    }
       
    private func loadTexture() {
        var url : URL?
        guard let device = MTLCreateSystemDefaultDevice(),
              let defaultURL = Bundle.main.url(forResource: "cardona-nz-cow", withExtension: "jpg") else {
            print( "\(#function): Unable to locate requested URL for texture to load" )
            return
        }
                
        if let userSelectedURL = selectedFileURL {
            url = selectedFileURL
        } else {
            url = defaultURL
        }
        
        // this addresses an artifact where loading a file from a URL the user chose using .fileImporter would quietly fail
        // start security scope
        guard ((url?.startAccessingSecurityScopedResource()) != nil) else {
            // log a message, but there should be clearer feedback a more durable way to handle no permission
            print("\(#function): Error: unable to start security scope for URL: \(url)")
            return
        }
        defer { url?.stopAccessingSecurityScopedResource() }

        print( "\(#function): URL requested for texture to load: \(url)" )
        do {
            let loader = MTKTextureLoader(device: device)
            texture = try? loader.newTexture(URL: url!.absoluteURL, options: [
                .SRGB: false,
                .generateMipmaps: false
            ])
            print( "\(#function): Texture: {w,h}: \(texture?.width) / \(texture?.height)" )
        } catch {
            print( "\(#function): Error loading texture: \(error)" )
       }

        return
    }

}

// MARK: - Aspect Ratio Handling

enum AspectRatioMode {
    case fit       // Letterbox/pillarbox to fit entirely
    case fill      // Crop to fill the view
    case stretch   // Distort to fill
}

// MARK: UI Binding Representable (middle)

#if os(iOS)
typealias ViewRepresentable = UIViewRepresentable
#else
typealias ViewRepresentable = NSViewRepresentable
#endif

struct MetalTextureView: ViewRepresentable {
    let texture: MTLTexture?
    
    func makeNSView(context: Context) -> TextureDisplayView {
        let device = MTLCreateSystemDefaultDevice()!
        let view = TextureDisplayView(frame: .zero, device: device)!
        return view
    }
    
    func updateNSView(_ view: TextureDisplayView, context: Context) {
        view.displayTexture = texture
    }
    
    #if os(iOS)
    func makeUIView(context: Context) -> TextureDisplayView {
        makeView(context: context)
    }

    func updateUIView(_ view: TextureDisplayView, context: Context) {
        updateView(view, context: context)
    }
    #else
    func makeNSView(context: Context) -> TextureDisplayView {
        makeView()
    }

    func updateNSView(_ view: TextureDisplayView, context: Context) {
        updateView(view)
    }
    #endif

    func makeView(context: Context) -> TextureDisplayView {
        print("\(#function): Texture: \(texture).")
        let device = MTLCreateSystemDefaultDevice()!
        let view = TextureDisplayView(frame: .zero, device: device)!
        //NB: texture unset, so vertex reset not triggered, yet
        view.aspectRatioMode = .fit
        return view
    }
    
    func updateView(_ view: TextureDisplayView, context: Context) {
        print("\(#function): Texture: \(texture).")
        view.displayTexture = texture
        view.aspectRatioMode = .fit
    }
}

// MARK: Texture Display View (inner)

class TextureDisplayView: MTKView {
    
    private var commandQueue: MTLCommandQueue!
    private var renderPipelineState: MTLRenderPipelineState!
    private var samplerState: MTLSamplerState!
    private var vertexBuffer: MTLBuffer!
    private var isGrayscaleBuffer: MTLBuffer!
    private let textureLock = NSLock()
    
    enum AspectRatioMode {
        case fit      // Letterbox/pillarbox to fit entire texture
        case fill     // Crop to fill entire view
        case stretch  // Stretch to fill (ignores aspect ratio)
    }
    
    enum DrawingMode {
        case onDemand    // Draw only when texture changes
        case continuous  // Draw every frame (for video/animation)
    }
    
    var aspectRatioMode: AspectRatioMode = .fit {
        didSet { updateVertexBuffer() }
    }
    
    var drawingMode: DrawingMode = .onDemand {
        didSet { updateDrawingMode() }
    }
    
    // NB: fold in lock to ensure thread-safe texture access at set (update) time
    private var _displayTexture: MTLTexture?
    var displayTexture: MTLTexture? {
        get {
            textureLock.lock()
            defer { textureLock.unlock() }
            return _displayTexture
        }
        set {
            textureLock.lock()
            _displayTexture = newValue
            textureLock.unlock()
            
            DispatchQueue.main.async { [weak self] in
                self?.updateGrayscaleFlag()
                self?.updateVertexBuffer()
            }
        }
    }
    
    // MARK: - Initialization
    
    init?(frame: CGRect, device: MTLDevice) {
        super.init(frame: frame, device: device)
        commonInit()
    }
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
        self.device = MTLCreateSystemDefaultDevice()
        commonInit()
    }
    
    private func commonInit() {
        guard let device = self.device else { return }
        
        commandQueue = device.makeCommandQueue()
        
        colorPixelFormat = .bgra8Unorm
        framebufferOnly = true
        
        updateDrawingMode()
        setupPipeline()
        setupSampler()
        updateGrayscaleFlag()
        updateVertexBuffer()
    }
    
    private func updateDrawingMode() {
        switch drawingMode {
        case .onDemand:
            enableSetNeedsDisplay = true
            isPaused = true
        case .continuous:
            enableSetNeedsDisplay = false
            isPaused = false
            preferredFramesPerSecond = 60
        }
    }
    
    // MARK: - Texture Update Methods
    
    /// Updates the texture and triggers a redraw
    func updateTexture(_ texture: MTLTexture?) {
        displayTexture = texture
    }
    
    /// Updates texture from a CVPixelBuffer (useful for camera/video frames)
    func updateTexture(from pixelBuffer: CVPixelBuffer, textureCache: CVMetalTextureCache) {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        // Determine pixel format from the pixel buffer
        let pixelFormat: MTLPixelFormat
        let formatType = CVPixelBufferGetPixelFormatType(pixelBuffer)
        
        switch formatType {
        case kCVPixelFormatType_32BGRA:
            pixelFormat = .bgra8Unorm
        case kCVPixelFormatType_OneComponent8:
            pixelFormat = .r8Unorm
        case kCVPixelFormatType_OneComponent16Half:
            pixelFormat = .r16Float
        default:
            pixelFormat = .bgra8Unorm
        }
        
        var cvTexture: CVMetalTexture?
        let status = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            textureCache,
            pixelBuffer,
            nil,
            pixelFormat,
            width,
            height,
            0,
            &cvTexture
        )
        
        if status == kCVReturnSuccess, let cvTexture = cvTexture {
            displayTexture = CVMetalTextureGetTexture(cvTexture)
        }
    }
    
    /// Copies data into the existing texture (avoids texture allocation)
    func updateTextureContents(with data: UnsafeRawPointer, bytesPerRow: Int, region: MTLRegion? = nil) {
        textureLock.lock()
        guard let texture = _displayTexture else {
            textureLock.unlock()
            return
        }
        
        let updateRegion = region ?? MTLRegion(
            origin: MTLOrigin(x: 0, y: 0, z: 0),
            size: MTLSize(width: texture.width, height: texture.height, depth: 1)
        )
        
        texture.replace(region: updateRegion, mipmapLevel: 0, withBytes: data, bytesPerRow: bytesPerRow)
        textureLock.unlock()
        
        DispatchQueue.main.async { [weak self] in
            self?.setNeedsDisplay()
        }
    }
    
    /// Forces an immediate redraw without changing texture
    func refresh() {
        DispatchQueue.main.async { [weak self] in
            self?.setNeedsDisplay()
        }
    }
    
    // MARK: - Grayscale Detection
    
    /// Detects single-channel formats and sets flag to broadcast R to RGB in shader
    private func updateGrayscaleFlag() {
        var isGrayscale: Bool = false
        
        textureLock.lock()
        if let texture = _displayTexture {
            let format = texture.pixelFormat
            isGrayscale = (format == .r8Unorm ||
                           format == .r8Snorm ||
                           format == .r16Unorm ||
                           format == .r16Float ||
                           format == .r32Float)
        }
        textureLock.unlock()
        
        isGrayscaleBuffer = device?.makeBuffer(
            bytes: &isGrayscale,
            length: MemoryLayout<Bool>.size,
            options: .storageModeShared
        )
    }
    
    // MARK: - Pipeline Setup
    
    // setupPipeline: set up the texture painting step, taking in account the vertices and color channels
    // NOTE: The vertex_passthrough step is key to ensure the correct (requested) aspect ratio is applied instead of (always) stretching
    
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
        
        vertex VertexOut vertex_passthrough(const device Vertex* vertices [[buffer(0)]],
                                            uint vertexID [[vertex_id]]) {
            VertexOut out;
            out.position = float4(vertices[vertexID].position, 0, 1);
            out.texCoord = vertices[vertexID].texCoord;
            return out;
        }
        
        fragment float4 fragment_texture(VertexOut in [[stage_in]],
                                         texture2d<float> texture [[texture(0)]],
                                         sampler textureSampler [[sampler(0)]],
                                         constant bool &isGrayscale [[buffer(0)]]) {
            float4 color = texture.sample(textureSampler, in.texCoord);
            if (isGrayscale) {
                // address artifact in grayscale case: broadcast red channel to all RGB
                return float4(color.r, color.r, color.r, 1.0);
            }
            return color;
        }
        """
        
        guard let device = self.device,
              let library = try? device.makeLibrary(source: shaderSource, options: nil) else {
            fatalError("Failed to create shader library")
        }
        
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "vertex_passthrough")
        descriptor.fragmentFunction = library.makeFunction(name: "fragment_texture")
        descriptor.colorAttachments[0].pixelFormat = colorPixelFormat
        
        renderPipelineState = try! device.makeRenderPipelineState(descriptor: descriptor)
    }
    
    private func setupSampler() {
        let descriptor = MTLSamplerDescriptor()
        descriptor.minFilter = .linear
        descriptor.magFilter = .linear
        descriptor.sAddressMode = .clampToEdge
        descriptor.tAddressMode = .clampToEdge
        samplerState = device?.makeSamplerState(descriptor: descriptor)
    }
    
    // MARK: - Layout
    
    #if os(macOS)
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        updateVertexBuffer()
    }
    #else
    override func layoutSubviews() {
        super.layoutSubviews()
        updateVertexBuffer()
    }
    #endif
    
    // MARK: - Drawing
    
    override func draw(_ rect: CGRect) {
        textureLock.lock()
        let texture = _displayTexture
        textureLock.unlock()
        
        guard let texture = texture,
              let drawable = currentDrawable,
              let descriptor = currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            return
        }
        
        encoder.setRenderPipelineState(renderPipelineState)
        
        // NB: Bind vertex buffer
               //     This is key to make sure the determined vertex location is applied
               //     Considers texture to draw against drawable view/area, and aspect ratios for each
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        
        encoder.setFragmentTexture(texture, index: 0)
        encoder.setFragmentSamplerState(samplerState, index: 0)
        
        //NOTE: Addresses display artifact with grayscale image, a red tint w/o correction
        encoder.setFragmentBuffer(isGrayscaleBuffer, offset: 0, index: 0)
        
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    // MARK: - Vertex Buffer (Aspect Ratio)
    
    private func updateVertexBuffer() {
        guard drawableSize.width > 0, drawableSize.height > 0 else { return }
        
        let viewAspect = drawableSize.width / drawableSize.height
        let textureAspect: CGFloat
        
        textureLock.lock()
        if let texture = _displayTexture {
            textureAspect = CGFloat(texture.width) / CGFloat(texture.height)
        } else {
            textureAspect = 16.0 / 9.0
        }
        textureLock.unlock()
        
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
        
        print( "\(#function): View Aspect: \(drawableSize.width)/\(drawableSize.height) / Texture Aspect: \(textureAspect)" )
        print( "\(#function): Display Texture: \(displayTexture)" )
        print( "\(#function): Vertices: \(vertices)" )
        setNeedsDisplay()
    }
}
