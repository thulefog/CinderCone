//
//  DrawableTextureViewController.swift
//
//  Created by John Matthew Weston on 10/9/18.
//  Copyright © 2018 John Matthew Weston. All rights reserved.
//

import Foundation

import UIKit
import Metal
import MetalKit
import QuartzCore


class DrawableTextureViewController: UIViewController, MTKViewDelegate {
    
    private var _drawableTextureView: MTKView!
    
    // Properties
    private var _device = MTLCreateSystemDefaultDevice()
    var _layer: CAMetalLayer! = nil
    var _renderPipelineState: MTLRenderPipelineState! = nil
    var _commandQueue: MTLCommandQueue! = nil
    
    var _displayLink: CADisplayLink! = nil
    /// A semaphore we use to syncronize drawing code.
    fileprivate let _semaphore = DispatchSemaphore(value: 1)
    
    public var _texture: MTLTexture?
    
    private var _frameIncrementPointer = 0
    
    var timer: Timer?
    
    private func initializeView() {
        
        _drawableTextureView = MTKView(frame: view.bounds, device: _device)
        _drawableTextureView.delegate = self
        _drawableTextureView.framebufferOnly = true
        _drawableTextureView.colorPixelFormat = .bgra8Unorm
        _drawableTextureView.contentScaleFactor = UIScreen.main.scale
        _drawableTextureView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        _drawableTextureView.preferredFramesPerSecond = 48
        view.insertSubview(_drawableTextureView, at: 0)
        
        // Set the CAMetalLayer
        _layer = CAMetalLayer()
        _layer.device = _device
        _layer.pixelFormat = .bgra8Unorm
        _layer.framebufferOnly = true
        _layer.frame = view.layer.frame
        view.layer.addSublayer(_layer)
        
        //OPEN: considered a separate DrawableTextureViewDelegate, just extended this class
        _drawableTextureView.delegate = self
    }

    func readSingleFrameTexture() {
        
        let path = Bundle.main.path(forResource: "doppler-us", ofType: "jpg")
        print( "readSingleFrameTexture: Loading image to texture from path \(path) for frame increment \(_frameIncrementPointer)" )
        
        let textureLoader = MTKTextureLoader(device: _device!)
        _texture = try! textureLoader.newTexture(URL: URL(fileURLWithPath: path!), options: nil)
    }
    
    func readTexture() {
/*
        let frameSequenceRepository = FrameSequenceRepository.instance
        let path = frameSequenceRepository._frameInstanceSet[ _frameIncrementPointer+1]?.path

        if let device = _device,
           let path = path {
            print( "readTexture: Loading image to texture from path \(path) for frame increment \(_frameIncrementPointer)" )
            
            let textureLoader = MTKTextureLoader(device: device)
            _texture = try! textureLoader.newTexture(URL: URL(fileURLWithPath: path), options: nil)
            
            if( _frameIncrementPointer == frameSequenceRepository.count-1 )
            {
                _frameIncrementPointer = 0
            }
            else
            {
                _frameIncrementPointer+=1
            }
        }
 */
    }
    
    override public func loadView() {
        super.loadView()
        
        assert(_device != nil, "Failed creating a default system Metal device. Please, make sure Metal is available on your hardware.")
        
        readTexture()
        initializeView()
        initializeRenderPipelineState()
    }

    private func initializeRenderPipelineState() {
        guard let
            device = _device,
            let library = _device!.makeDefaultLibrary()
            else { return }
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.sampleCount = 1
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.depthAttachmentPixelFormat = .invalid
        
        /**
         *  Vertex function to map the texture to the view controller's view
         */
        pipelineDescriptor.vertexFunction = library.makeFunction(name: "mapTextureDrawable")
        /**
         *  Fragment function to display texture's pixels in the area bounded by vertices of `mapTexture` shader
         */
        pipelineDescriptor.fragmentFunction = library.makeFunction(name: "displayTextureDrawable")
        
        do {
            try _renderPipelineState = _device!.makeRenderPipelineState(descriptor: pipelineDescriptor)
        }
        catch {
            assertionFailure("Failed creating a render state pipeline. Can't render the texture without one.")
            return
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view, typically from a nib.

        // Set the Timer
        _displayLink = CADisplayLink(target: self, selector: #selector(step))
        _displayLink.add(to: RunLoop.main, forMode: RunLoop.Mode.default)
        
        print( "CADisplayLink: duration \(_displayLink.duration) " )
        
        /*
        // Disable the automatic, timed drawing updates.
        _drawableTextureView.isPaused = true
        _drawableTextureView.enableSetNeedsDisplay = true
        
        // Create a timer to trigger a new frame every 0.5 seconds.
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self!._drawableTextureView.setNeedsDisplay()
            }
        }*/
    }
    
    @objc func step(displaylink: CADisplayLink) {
        print(displaylink.timestamp)
        autoreleasepool {
            self.drawInMTKView(view: _drawableTextureView )
            readTexture()
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    //MAKR: MTKViewDelegate
    
    public func drawInMTKView(view: MTKView) {
        guard
            var texture = _texture,
            let device = _device
            else { return }
        
        /// The rendering goes here.
        let commandBuffer = _device!.makeCommandQueue()!.makeCommandBuffer()
        
        guard let
            currentRenderPassDescriptor = _drawableTextureView.currentRenderPassDescriptor,
            let currentDrawable = _drawableTextureView.currentDrawable,
            let renderPipelineState = _renderPipelineState
            else { return }
        
        let encoder = commandBuffer!.makeRenderCommandEncoder(descriptor: currentRenderPassDescriptor)!
        encoder.pushDebugGroup("RenderFrame")
        encoder.setRenderPipelineState(renderPipelineState)
        print( "drawInMTKView: setting fragment texture..." )
        encoder.setFragmentTexture(texture, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: 1)
        encoder.popDebugGroup()
        encoder.endEncoding()
    
        
        commandBuffer!.present(currentDrawable)
        commandBuffer!.commit()
        
    }
    
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        NSLog("MTKView drawable size will change to \(size)")
    }
    
    public func draw(in: MTKView) {
        _ = _semaphore.wait(timeout: DispatchTime.distantFuture)
        
        autoreleasepool {
            guard
                var texture = _texture,
                let device = _device,
                let commandBuffer = _commandQueue?.makeCommandBuffer()
                else {
                    _ = _semaphore.signal()
                    return
            }
            
            didRenderTexture( texture, withCommandBuffer: commandBuffer, device: device)
            render(texture: texture, withCommandBuffer: commandBuffer, device: device)
        }
    }
    
    /**
     Renders texture into the `UIViewController`'s view.
     
     - parameter texture:       Texture to be rendered
     - parameter commandBuffer: Command buffer we will use for drawing
     */
    private func render(texture: MTLTexture, withCommandBuffer commandBuffer: MTLCommandBuffer, device: MTLDevice) {
        guard
            let currentRenderPassDescriptor = _drawableTextureView.currentRenderPassDescriptor,
            let currentDrawable = _drawableTextureView.currentDrawable,
            let renderPipelineState = _renderPipelineState,
            let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: currentRenderPassDescriptor)
            else {
                _semaphore.signal()
                return
        }
        
        encoder.pushDebugGroup("RenderFrame")
        encoder.setRenderPipelineState(renderPipelineState)
        encoder.setFragmentTexture(texture, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: 1)
        encoder.popDebugGroup()
        encoder.endEncoding()
        
        commandBuffer.addScheduledHandler { [weak self] (buffer) in
            guard let unwrappedSelf = self else { return }
            
            unwrappedSelf.didRenderTexture(texture, withCommandBuffer: buffer, device: device)
            unwrappedSelf._semaphore.signal()
        }
        commandBuffer.present(currentDrawable)
        commandBuffer.commit()
    }
    
    /**
     This method is called after rendering view's content.
     
     - parameter texture:       Texture that was drawn
     - parameter commandBuffer: Command buffer we used for drawing
     - parameter device:        Metal device
     */
    open func didRenderTexture(_ texture: MTLTexture, withCommandBuffer commandBuffer: MTLCommandBuffer, device: MTLDevice) {
        /**
         * Override if neccessary
         */
    }
}

// END - MARK: - MTKViewDelegate and rendering
