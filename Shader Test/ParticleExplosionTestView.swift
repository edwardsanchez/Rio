//
//  ParticleExplosionTestView.swift
//  Shader Test
//
//  Created by Edward Sanchez on 10/17/25.
//

import SwiftUI
import MetalKit

struct MetalView: NSViewRepresentable {
    let renderer: ParticleRenderer
    
    func makeNSView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = renderer.device
        mtkView.delegate = renderer
        mtkView.clearColor = MTLClearColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 1.0)
        mtkView.enableSetNeedsDisplay = false
        mtkView.isPaused = false
        
        // Initialize particles after setup
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            renderer.initializeParticles()
        }
        
        return mtkView
    }
    
    func updateNSView(_ nsView: MTKView, context: Context) {
        // Update happens through renderer
    }
}

struct ParticleExplosionTestView: View {
    @State private var renderer: ParticleRenderer?
    
    // Velocity parameters
    @State private var spread: Float = 45.0
    @State private var inheritVelocityRatio: Float = 0.0
    @State private var initialVelocityMin: Float = 50.0
    @State private var initialVelocityMax: Float = 100.0
    @State private var orbitVelocityMin: Float = 0.0
    @State private var orbitVelocityMax: Float = 0.0
    @State private var radialVelocityMin: Float = 0.0
    @State private var radialVelocityMax: Float = 0.0
    
    // Acceleration parameters
    @State private var linearAccelMin: Float = 0.0
    @State private var linearAccelMax: Float = 0.0
    @State private var radialAccelMin: Float = 0.0
    @State private var radialAccelMax: Float = 0.0
    @State private var tangentAccelMin: Float = 0.0
    @State private var tangentAccelMax: Float = 0.0
    @State private var dampingMin: Float = 0.0
    @State private var dampingMax: Float = 0.0
    
    // Display parameters
    @State private var scaleMin: Float = 5.0
    @State private var scaleMax: Float = 10.0
    @State private var lifetimeRandomness: Float = 0.5
    @State private var amountRatio: Float = 1.0
    
    // Emission shape parameters
    @State private var emissionOffsetX: Float = 0.0
    @State private var emissionOffsetY: Float = 0.0
    @State private var emissionOffsetZ: Float = 0.0
    @State private var emissionScaleX: Float = 1.0
    @State private var emissionScaleY: Float = 1.0
    @State private var emissionScaleZ: Float = 1.0
    @State private var emissionExtentX: Float = 50.0
    @State private var emissionExtentY: Float = 50.0
    @State private var emissionExtentZ: Float = 0.0
    
    // Emitter parameters
    @State private var emitterVelocityX: Float = 0.0
    @State private var emitterVelocityY: Float = 0.0
    @State private var emitterVelocityZ: Float = 0.0
    
    // Restart options
    @State private var restartPosition: Bool = true
    @State private var restartVelocity: Bool = true
    @State private var restartCustom: Bool = true
    @State private var restartRotScale: Bool = true
    
    // Animation control
    @State private var currentTime: Float = 0.0
    @State private var isAnimating: Bool = false
    @State private var interpolateToEnd: Float = 0.0
    
    var body: some View {
        HStack(spacing: 0) {
            // Left side - Controls
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Particle Explosion Shader")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    // Time control
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Animation Control")
                            .font(.headline)
                        
                        HStack {
                            Button(isAnimating ? "Pause" : "Play") {
                                isAnimating.toggle()
                                renderer?.isAnimating = isAnimating
                                if isAnimating {
                                    renderer?.lastUpdateTime = Date()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            
                            Button("Reset") {
                                currentTime = 0.0
                                renderer?.currentTime = 0.0
                                renderer?.reset()
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        HStack {
                            Text("Time:")
                                .frame(width: 60, alignment: .leading)
                            Slider(value: $currentTime, in: 0...2) { editing in
                                if !editing {
                                    updateTime()
                                }
                            }
                            Text(String(format: "%.2f", currentTime))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 40, alignment: .trailing)
                        }
                    }
                    
                    Divider()
                    
                    // Velocity section
                    DisclosureGroup("Velocity") {
                        VStack(alignment: .leading, spacing: 12) {
                            parameterSlider("Spread", value: $spread, range: 0...360, binding: updateVelocity)
                            
                            parameterSlider("Inherit Velocity", value: $inheritVelocityRatio, range: 0...1, binding: updateVelocity)
                            
                            parameterTextField("Initial Min", value: $initialVelocityMin, binding: updateVelocity)
                            parameterTextField("Initial Max", value: $initialVelocityMax, binding: updateVelocity)
                            
                            parameterTextField("Orbit Min", value: $orbitVelocityMin, binding: updateVelocity)
                            parameterTextField("Orbit Max", value: $orbitVelocityMax, binding: updateVelocity)
                            
                            parameterTextField("Radial Min", value: $radialVelocityMin, binding: updateVelocity)
                            parameterTextField("Radial Max", value: $radialVelocityMax, binding: updateVelocity)
                        }
                        .padding(.leading)
                    }
                    
                    Divider()
                    
                    // Acceleration section
                    DisclosureGroup("Acceleration") {
                        VStack(alignment: .leading, spacing: 12) {
                            parameterTextField("Linear Min", value: $linearAccelMin, binding: updateAcceleration)
                            parameterTextField("Linear Max", value: $linearAccelMax, binding: updateAcceleration)
                            
                            parameterTextField("Radial Min", value: $radialAccelMin, binding: updateAcceleration)
                            parameterTextField("Radial Max", value: $radialAccelMax, binding: updateAcceleration)
                            
                            parameterTextField("Tangent Min", value: $tangentAccelMin, binding: updateAcceleration)
                            parameterTextField("Tangent Max", value: $tangentAccelMax, binding: updateAcceleration)
                            
                            parameterTextField("Damping Min", value: $dampingMin, binding: updateAcceleration)
                            parameterTextField("Damping Max", value: $dampingMax, binding: updateAcceleration)
                        }
                        .padding(.leading)
                    }
                    
                    Divider()
                    
                    // Display section
                    DisclosureGroup("Display") {
                        VStack(alignment: .leading, spacing: 12) {
                            parameterTextField("Scale Min", value: $scaleMin, binding: updateDisplay)
                            parameterTextField("Scale Max", value: $scaleMax, binding: updateDisplay)
                            
                            parameterSlider("Lifetime Random", value: $lifetimeRandomness, range: 0...1, binding: updateDisplay)
                            parameterSlider("Amount Ratio", value: $amountRatio, range: 0...1, binding: updateDisplay)
                        }
                        .padding(.leading)
                    }
                    
                    Divider()
                    
                    // Emission Shape section
                    DisclosureGroup("Emission Shape") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Offset")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            parameterTextField("X", value: $emissionOffsetX, binding: updateEmissionShape)
                            parameterTextField("Y", value: $emissionOffsetY, binding: updateEmissionShape)
                            parameterTextField("Z", value: $emissionOffsetZ, binding: updateEmissionShape)
                            
                            Text("Scale")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding(.top, 8)
                            parameterTextField("X", value: $emissionScaleX, binding: updateEmissionShape)
                            parameterTextField("Y", value: $emissionScaleY, binding: updateEmissionShape)
                            parameterTextField("Z", value: $emissionScaleZ, binding: updateEmissionShape)
                            
                            Text("Extents")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding(.top, 8)
                            parameterTextField("X", value: $emissionExtentX, binding: updateEmissionShape)
                            parameterTextField("Y", value: $emissionExtentY, binding: updateEmissionShape)
                            parameterTextField("Z", value: $emissionExtentZ, binding: updateEmissionShape)
                        }
                        .padding(.leading)
                    }
                    
                    Divider()
                    
                    // Emitter section
                    DisclosureGroup("Emitter Velocity") {
                        VStack(alignment: .leading, spacing: 12) {
                            parameterTextField("X", value: $emitterVelocityX, binding: updateEmitter)
                            parameterTextField("Y", value: $emitterVelocityY, binding: updateEmitter)
                            parameterTextField("Z", value: $emitterVelocityZ, binding: updateEmitter)
                        }
                        .padding(.leading)
                    }
                    
                    Divider()
                    
                    // Restart Options section
                    DisclosureGroup("Restart Options") {
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("Restart Position", isOn: $restartPosition)
                                .onChange(of: restartPosition) { updateRestart() }
                            Toggle("Restart Velocity", isOn: $restartVelocity)
                                .onChange(of: restartVelocity) { updateRestart() }
                            Toggle("Restart Custom", isOn: $restartCustom)
                                .onChange(of: restartCustom) { updateRestart() }
                            Toggle("Restart Rotation/Scale", isOn: $restartRotScale)
                                .onChange(of: restartRotScale) { updateRestart() }
                        }
                        .padding(.leading)
                    }
                    
                    Divider()
                    
                    // Advanced
                    DisclosureGroup("Advanced") {
                        VStack(alignment: .leading, spacing: 12) {
                            parameterSlider("Interpolate to End", value: $interpolateToEnd, range: 0...1) {
                                renderer?.uniforms.interpolate_to_end = interpolateToEnd
                            }
                        }
                        .padding(.leading)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .frame(width: 350)
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            // Right side - Metal Preview
            VStack {
                if let renderer = renderer {
                    MetalView(renderer: renderer)
                } else {
                    Text("Initializing Metal...")
                        .foregroundStyle(.secondary)
                        .onAppear {
                            initializeRenderer()
                        }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .textBackgroundColor))
        }
    }
    
    private func initializeRenderer() {
        let mtkView = MTKView()
        if let newRenderer = ParticleRenderer(metalView: mtkView) {
            renderer = newRenderer
            syncAllParameters()
        }
    }
    
    private func syncAllParameters() {
        updateVelocity()
        updateAcceleration()
        updateDisplay()
        updateEmissionShape()
        updateEmitter()
        updateRestart()
    }
    
    private func updateVelocity() {
        renderer?.uniforms.spread = spread
        renderer?.uniforms.inherit_emitter_velocity_ratio = inheritVelocityRatio
        renderer?.uniforms.initial_linear_velocity_min = initialVelocityMin
        renderer?.uniforms.initial_linear_velocity_max = initialVelocityMax
        renderer?.uniforms.orbit_velocity_min = orbitVelocityMin
        renderer?.uniforms.orbit_velocity_max = orbitVelocityMax
        renderer?.uniforms.radial_velocity_min = radialVelocityMin
        renderer?.uniforms.radial_velocity_max = radialVelocityMax
    }
    
    private func updateAcceleration() {
        renderer?.uniforms.linear_accel_min = linearAccelMin
        renderer?.uniforms.linear_accel_max = linearAccelMax
        renderer?.uniforms.radial_accel_min = radialAccelMin
        renderer?.uniforms.radial_accel_max = radialAccelMax
        renderer?.uniforms.tangent_accel_min = tangentAccelMin
        renderer?.uniforms.tangent_accel_max = tangentAccelMax
        renderer?.uniforms.damping_min = dampingMin
        renderer?.uniforms.damping_max = dampingMax
    }
    
    private func updateDisplay() {
        renderer?.uniforms.scale_min = scaleMin
        renderer?.uniforms.scale_max = scaleMax
        renderer?.uniforms.lifetime_randomness = lifetimeRandomness
        renderer?.uniforms.amount_ratio = amountRatio
    }
    
    private func updateEmissionShape() {
        renderer?.uniforms.emission_shape_offset = SIMD3<Float>(emissionOffsetX, emissionOffsetY, emissionOffsetZ)
        renderer?.uniforms.emission_shape_scale = SIMD3<Float>(emissionScaleX, emissionScaleY, emissionScaleZ)
        renderer?.uniforms.emission_box_extents = SIMD3<Float>(emissionExtentX, emissionExtentY, emissionExtentZ)
    }
    
    private func updateEmitter() {
        renderer?.uniforms.emitter_velocity = SIMD3<Float>(emitterVelocityX, emitterVelocityY, emitterVelocityZ)
    }
    
    private func updateRestart() {
        renderer?.uniforms.restart_position = restartPosition
        renderer?.uniforms.restart_velocity = restartVelocity
        renderer?.uniforms.restart_custom = restartCustom
        renderer?.uniforms.restart_rot_scale = restartRotScale
    }
    
    private func updateTime() {
        renderer?.currentTime = currentTime
        renderer?.uniforms.delta_time = 0.016
        if !isAnimating {
            renderer?.reset()
            // Simulate up to current time
            let steps = Int(currentTime / 0.016)
            for _ in 0..<steps {
                renderer?.updateParticles()
            }
        }
    }
    
    // Helper views
    private func parameterTextField(_ label: String, value: Binding<Float>, binding: @escaping () -> Void) -> some View {
        HStack {
            Text(label + ":")
                .frame(width: 100, alignment: .leading)
            TextField("", value: value, format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 100)
                .onChange(of: value.wrappedValue) { binding() }
        }
    }
    
    private func parameterSlider(_ label: String, value: Binding<Float>, range: ClosedRange<Float>, binding: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
            HStack {
                Slider(value: value, in: range) { _ in
                    binding()
                }
                Text(String(format: "%.2f", value.wrappedValue))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 50, alignment: .trailing)
            }
        }
    }
}

#Preview {
    ParticleExplosionTestView()
        .frame(width: 1200, height: 800)
}

