//
//  ParticleRenderer.swift
//  Shader Test
//
//  Created by Edward Sanchez on 10/17/25.
//

import Metal
import MetalKit
import simd

struct ParticleUniforms {
    var spread: Float
    var inherit_emitter_velocity_ratio: Float
    var initial_linear_velocity_min: Float
    var initial_linear_velocity_max: Float
    var orbit_velocity_min: Float
    var orbit_velocity_max: Float
    var radial_velocity_min: Float
    var radial_velocity_max: Float
    var linear_accel_min: Float
    var linear_accel_max: Float
    var radial_accel_min: Float
    var radial_accel_max: Float
    var tangent_accel_min: Float
    var tangent_accel_max: Float
    var damping_min: Float
    var damping_max: Float
    var scale_min: Float
    var scale_max: Float
    var lifetime_randomness: Float
    var emission_shape_offset: SIMD3<Float>
    var emission_shape_scale: SIMD3<Float>
    var emission_box_extents: SIMD3<Float>
    var emitter_velocity: SIMD3<Float>
    var emission_transform: simd_float4x4
    var delta_time: Float
    var amount_ratio: Float
    var random_seed: UInt32
    var restart_position: Bool
    var restart_velocity: Bool
    var restart_custom: Bool
    var restart_rot_scale: Bool
    var interpolate_to_end: Float
}

class ParticleRenderer: NSObject, MTKViewDelegate {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    
    private var particleStartPipeline: MTLComputePipelineState?
    private var particleProcessPipeline: MTLComputePipelineState?
    private var renderPipelineState: MTLRenderPipelineState?
    
    private var particleBuffer: MTLBuffer?
    private var vertexBuffer: MTLBuffer?
    private var spriteTexture: MTLTexture?
    
    private let particleCount = 10000
    var uniforms: ParticleUniforms
    
    var currentTime: Float = 0.0
    var isAnimating: Bool = false
    var lastUpdateTime: Date?
    
    init?(metalView: MTKView) {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else {
            return nil
        }
        
        self.device = device
        self.commandQueue = commandQueue
        
        // Initialize uniforms with default values
        self.uniforms = ParticleUniforms(
            spread: 45.0,
            inherit_emitter_velocity_ratio: 0.0,
            initial_linear_velocity_min: 50.0,
            initial_linear_velocity_max: 100.0,
            orbit_velocity_min: 0.0,
            orbit_velocity_max: 0.0,
            radial_velocity_min: 0.0,
            radial_velocity_max: 0.0,
            linear_accel_min: 0.0,
            linear_accel_max: 0.0,
            radial_accel_min: 0.0,
            radial_accel_max: 0.0,
            tangent_accel_min: 0.0,
            tangent_accel_max: 0.0,
            damping_min: 0.0,
            damping_max: 0.0,
            scale_min: 5.0,
            scale_max: 10.0,
            lifetime_randomness: 0.5,
            emission_shape_offset: SIMD3<Float>(0, 0, 0),
            emission_shape_scale: SIMD3<Float>(1, 1, 1),
            emission_box_extents: SIMD3<Float>(50, 50, 0),
            emitter_velocity: SIMD3<Float>(0, 0, 0),
            emission_transform: matrix_identity_float4x4,
            delta_time: 0.016,
            amount_ratio: 1.0,
            random_seed: 0,
            restart_position: true,
            restart_velocity: true,
            restart_custom: true,
            restart_rot_scale: true,
            interpolate_to_end: 0.0
        )
        
        super.init()
        
        metalView.device = device
        metalView.delegate = self
        metalView.clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        
        setupMetal()
        createBuffers()
        createSpriteTexture()
    }
    
    private func setupMetal() {
        guard let library = device.makeDefaultLibrary() else {
            print("Failed to create Metal library")
            return
        }
        
        // Create compute pipelines
        do {
            if let startFunction = library.makeFunction(name: "particle_start") {
                particleStartPipeline = try device.makeComputePipelineState(function: startFunction)
            }
            
            if let processFunction = library.makeFunction(name: "particle_process") {
                particleProcessPipeline = try device.makeComputePipelineState(function: processFunction)
            }
        } catch {
            print("Failed to create compute pipelines: \(error)")
        }
        
        // Create render pipeline with vertex descriptor
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = library.makeFunction(name: "particle_vertex")
        pipelineDescriptor.fragmentFunction = library.makeFunction(name: "particle_fragment")
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        // Set up vertex descriptor for quad vertices
        let vertexDescriptor = MTLVertexDescriptor()
        // Position attribute (float2) at index 0
        vertexDescriptor.attributes[0].format = .float2
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 2  // Buffer index for vertex data
        // TexCoord attribute (float2) at index 1
        vertexDescriptor.attributes[1].format = .float2
        vertexDescriptor.attributes[1].offset = MemoryLayout<Float>.stride * 2
        vertexDescriptor.attributes[1].bufferIndex = 2
        // Layout for buffer 2 (quad vertices)
        vertexDescriptor.layouts[2].stride = MemoryLayout<Float>.stride * 4  // 4 floats per vertex
        vertexDescriptor.layouts[2].stepRate = 1
        vertexDescriptor.layouts[2].stepFunction = .perVertex
        
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
        
        // Enable blending for particle rendering
        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        
        do {
            renderPipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("Failed to create render pipeline: \(error)")
        }
    }
    
    private func createBuffers() {
        // Create particle buffer (large enough for all particle data)
        // Each particle needs space for position, velocity, color, custom, transform, active, lifetime, seed
        let particleSize = MemoryLayout<SIMD4<Float>>.stride * 6 + // position, velocity, color, custom, transform (4x4)
                          MemoryLayout<Bool>.stride +
                          MemoryLayout<Float>.stride +
                          MemoryLayout<UInt32>.stride
        
        particleBuffer = device.makeBuffer(length: particleSize * particleCount, options: .storageModePrivate)
        
        // Create vertex buffer for a quad
        let vertices: [Float] = [
            -1.0, -1.0, 0.0, 0.0,  // position, texCoord
             1.0, -1.0, 1.0, 0.0,
            -1.0,  1.0, 0.0, 1.0,
             1.0, -1.0, 1.0, 0.0,
             1.0,  1.0, 1.0, 1.0,
            -1.0,  1.0, 0.0, 1.0
        ]
        
        vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Float>.stride, options: [])
    }
    
    private func createSpriteTexture() {
        // Create a texture with a circle gradient for particle sprites
        let size = 64
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: size,
            height: size,
            mipmapped: false
        )
        textureDescriptor.usage = [.shaderRead, .shaderWrite]
        
        guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
            print("Failed to create sprite texture")
            return
        }
        
        // Generate circle data
        var pixelData = [UInt8](repeating: 0, count: size * size * 4)
        let center = Float(size) / 2.0
        let radius = Float(size) / 2.0
        
        for y in 0..<size {
            for x in 0..<size {
                let dx = Float(x) - center
                let dy = Float(y) - center
                let distance = sqrt(dx * dx + dy * dy)
                
                let alpha: UInt8
                if distance <= radius {
                    // Smooth edge with antialiasing
                    let edgeSoftness: Float = 2.0
                    let normalizedDist = distance / radius
                    let edgeFactor = max(0, min(1, (1.0 - normalizedDist) * edgeSoftness))
                    alpha = UInt8(edgeFactor * 255)
                } else {
                    alpha = 0
                }
                
                let index = (y * size + x) * 4
                pixelData[index] = 255     // R
                pixelData[index + 1] = 255 // G
                pixelData[index + 2] = 255 // B
                pixelData[index + 3] = alpha // A
            }
        }
        
        let region = MTLRegionMake2D(0, 0, size, size)
        texture.replace(region: region, mipmapLevel: 0, withBytes: pixelData, bytesPerRow: size * 4)
        
        spriteTexture = texture
    }
    
    func initializeParticles() {
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder(),
              let pipeline = particleStartPipeline,
              let particleBuffer = particleBuffer,
              let spriteTexture = spriteTexture else {
            return
        }
        
        var uniforms = self.uniforms
        uniforms.random_seed = UInt32.random(in: 0...UInt32.max)
        
        computeEncoder.setComputePipelineState(pipeline)
        computeEncoder.setBuffer(particleBuffer, offset: 0, index: 0)
        computeEncoder.setBytes(&uniforms, length: MemoryLayout<ParticleUniforms>.stride, index: 1)
        computeEncoder.setTexture(spriteTexture, index: 0)
        
        let threadgroupSize = MTLSize(width: 256, height: 1, depth: 1)
        let threadgroups = MTLSize(
            width: (particleCount + threadgroupSize.width - 1) / threadgroupSize.width,
            height: 1,
            depth: 1
        )
        
        computeEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadgroupSize)
        computeEncoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
    
    func updateParticles() {
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder(),
              let pipeline = particleProcessPipeline,
              let particleBuffer = particleBuffer else {
            return
        }
        
        var uniforms = self.uniforms
        
        computeEncoder.setComputePipelineState(pipeline)
        computeEncoder.setBuffer(particleBuffer, offset: 0, index: 0)
        computeEncoder.setBytes(&uniforms, length: MemoryLayout<ParticleUniforms>.stride, index: 1)
        
        let threadgroupSize = MTLSize(width: 256, height: 1, depth: 1)
        let threadgroups = MTLSize(
            width: (particleCount + threadgroupSize.width - 1) / threadgroupSize.width,
            height: 1,
            depth: 1
        )
        
        computeEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadgroupSize)
        computeEncoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
    
    // MARK: - MTKViewDelegate
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Handle resize if needed
    }
    
    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            return
        }
        
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        
        guard let renderPipeline = renderPipelineState,
              let particleBuffer = particleBuffer,
              let vertexBuffer = vertexBuffer,
              let spriteTexture = spriteTexture else {
            renderEncoder.endEncoding()
            return
        }
        
        // Update time if animating
        if isAnimating {
            let now = Date()
            if let lastTime = lastUpdateTime {
                let deltaTime = Float(now.timeIntervalSince(lastTime))
                currentTime += deltaTime
                uniforms.delta_time = deltaTime
                updateParticles()
            }
            lastUpdateTime = now
        }
        
        // Create view projection matrix
        let viewSize = view.drawableSize
        let aspect = Float(viewSize.width / viewSize.height)
        let scale: Float = 2.0 / Float(min(viewSize.width, viewSize.height))
        var viewProjection = matrix_identity_float4x4
        viewProjection.columns.0.x = scale / aspect
        viewProjection.columns.1.y = scale
        
        renderEncoder.setRenderPipelineState(renderPipeline)
        renderEncoder.setVertexBuffer(particleBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBytes(&viewProjection, length: MemoryLayout<simd_float4x4>.stride, index: 1)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 2)
        renderEncoder.setFragmentTexture(spriteTexture, index: 0)
        
        // Draw particles as instanced quads
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6, instanceCount: particleCount)
        
        renderEncoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    func reset() {
        currentTime = 0.0
        lastUpdateTime = nil
        initializeParticles()
    }
}

