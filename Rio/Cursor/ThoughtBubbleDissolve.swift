//
// ThoughtBubbleDissolve.swift
// Rio
//
// SwiftUI wrapper for the ThoughtBubbleDissolve shader effect.
//

import SwiftUI

// MARK: - Parameters

/// Parameters for controlling the thought bubble dissolve effect.
struct ThoughtBubbleDissolveParams {
    /// Animation progress from 0 (start) to 1 (complete dissolution)
    var progress: CGFloat = 0.5
    
    /// Base size of circular particles in pixels
    var particleSize: CGFloat = 8.0
    
    /// Random variation in particle sizes (0 to 1)
    var sizeVariation: CGFloat = 0.5
    
    /// Overall movement speed multiplier
    var speed: CGFloat = 100.0
    
    /// Wind direction (x, y components)
    var wind: CGPoint = CGPoint(x: 0.5, y: -0.3)
    
    /// Intensity of swirling, turbulent motion (0 to 1)
    var turbulence: CGFloat = 0.7
    
    /// Initial explosion force from center
    var burstStrength: CGFloat = 40.0
    
    /// How quickly particles fade out (higher = faster)
    var fadeSpeed: CGFloat = 2.0
    
    /// Downward gravitational pull
    var gravity: CGFloat = 0.3
    
    init() {}
}

// MARK: - View Extension

extension View {
    /// Applies the thought bubble dissolve effect to this view.
    ///
    /// The view will dissolve into circular particles that gently explode
    /// and disperse like a soap bubble bursting or vapor cloud.
    ///
    /// - Parameters:
    ///   - params: The dissolve effect parameters.
    ///   - time: Current time for animated turbulence.
    ///   - size: The size of the view.
    /// - Returns: A view with the dissolve effect applied.
    func thoughtBubbleDissolve(
        _ params: ThoughtBubbleDissolveParams,
        time: TimeInterval = 0,
        size: CGSize
    ) -> some View {
        let shader = Shader(
            function: ShaderFunction(library: .default, name: "thoughtBubbleDissolve"),
            arguments: [
                .float(Float(params.progress)),
                .float(Float(time)),
                .float(Float(params.particleSize)),
                .float(Float(params.sizeVariation)),
                .float(Float(params.speed)),
                .float(Float(params.wind.x)),
                .float(Float(params.wind.y)),
                .float(Float(params.turbulence)),
                .float(Float(params.burstStrength)),
                .float(Float(params.fadeSpeed)),
                .float(Float(params.gravity)),
                .float(Float(size.width)),
                .float(Float(size.height))
            ]
        )
        
        // Large maxSampleOffset to allow particles to travel far beyond original bounds
        let maxOffset = CGSize(
            width: max(400, params.speed * 4 + params.burstStrength * 4),
            height: max(400, params.speed * 4 + params.burstStrength * 4)
        )
        
        return self.layerEffect(shader, maxSampleOffset: maxOffset)
    }
}

// MARK: - Demo View

struct ThoughtBubbleDissolveDemo: View {
    @State private var params = ThoughtBubbleDissolveParams()
    @State private var isAnimating = false
    @State private var showBubble = true
    @State private var manualMode = false
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Thought Bubble Dissolve")
                .font(.title)
                .fontWeight(.bold)
            
            // Preview area
            ZStack {
                // Checkered background to show transparency
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.gray.opacity(0.1), Color.gray.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                if showBubble {
                    GeometryReader { geometry in
                        TimelineView(.animation) { timeline in
                            let time = timeline.date.timeIntervalSinceReferenceDate
                            
                            VStack {
                                Circle()
                                    .fill(Color.white)
                                    .padding((50))
                            }
//                                .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
                                .thoughtBubbleDissolve(
                                    params,
                                    time: time,
                                    size: geometry.size
                                )
                        }
                    }
                } else {
                    Text("Press Reset")
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 300, height: 300)
            .border(Color.gray.opacity(0.3), width: 1)
            
            // Controls
            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    Button(action: reset) {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                            .frame(minWidth: 100)
                    }
                    .buttonStyle(.bordered)
                    .disabled(showBubble && !isAnimating && !manualMode)
                    
                    Button(action: animate) {
                        Label("Dissolve", systemImage: "sparkles")
                            .frame(minWidth: 100)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!showBubble || isAnimating || manualMode)
                }
                
                Toggle("Manual Control (test parameters)", isOn: $manualMode)
                    .toggleStyle(.switch)
                    .onChange(of: manualMode) { _, newValue in
                        if newValue {
                            isAnimating = false
                            showBubble = true
                        }
                    }
            }
            
            // Parameter controls
            ScrollView {
                VStack(spacing: 20) {
                    // Particle Settings
                    GroupBox("Particle Settings") {
                        VStack(spacing: 12) {
                            SliderRow(
                                title: "Particle Size",
                                value: $params.particleSize,
                                range: 0.5...20,
                                format: "%.1f px"
                            )
                            
                            SliderRow(
                                title: "Size Variation",
                                value: $params.sizeVariation,
                                range: 0...1,
                                format: "%.2f"
                            )
                        }
                    }
                    
                    // Motion Settings
                    GroupBox("Motion Settings") {
                        VStack(spacing: 12) {
                            SliderRow(
                                title: "Speed",
                                value: $params.speed,
                                range: 20...300,
                                format: "%.0f"
                            )
                            
                            SliderRow(
                                title: "Burst Strength",
                                value: $params.burstStrength,
                                range: 0...100,
                                format: "%.0f"
                            )
                            
                            SliderRow(
                                title: "Turbulence",
                                value: $params.turbulence,
                                range: 0...2,
                                format: "%.2f"
                            )
                            
                            SliderRow(
                                title: "Gravity",
                                value: $params.gravity,
                                range: 0...1,
                                format: "%.2f"
                            )
                        }
                    }
                    
                    // Wind Settings
                    GroupBox("Wind Settings") {
                        VStack(spacing: 12) {
                            SliderRow(
                                title: "Wind X",
                                value: Binding(
                                    get: { params.wind.x },
                                    set: { params.wind.x = $0 }
                                ),
                                range: -1...1,
                                format: "%.2f"
                            )
                            
                            SliderRow(
                                title: "Wind Y",
                                value: Binding(
                                    get: { params.wind.y },
                                    set: { params.wind.y = $0 }
                                ),
                                range: -1...1,
                                format: "%.2f"
                            )
                        }
                    }
                    
                    // Appearance Settings
                    GroupBox("Appearance Settings") {
                        VStack(spacing: 12) {
                            SliderRow(
                                title: "Fade Speed",
                                value: $params.fadeSpeed,
                                range: 0.5...4,
                                format: "%.2f"
                            )
                            
                            SliderRow(
                                title: "Progress",
                                value: $params.progress,
                                range: 0...1,
                                format: "%.2f"
                            )
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding()
    }
    
    private func reset() {
        isAnimating = false
        params.progress = 0.5
        showBubble = true
        manualMode = false
    }
    
    private func animate() {
        guard !isAnimating && !manualMode else { return }
        isAnimating = true
        
        // Reset to 0 first, then animate to 1.0
        params.progress = 0
        
        withAnimation(.easeInOut(duration: 2.5)) {
            params.progress = 1.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            showBubble = false
            isAnimating = false
        }
    }
}

// MARK: - Helper Views

struct SliderRow: View {
    let title: String
    @Binding var value: CGFloat
    let range: ClosedRange<CGFloat>
    let format: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(String(format: format, value))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundColor(.primary)
            }
            
            Slider(value: $value, in: range)
                .tint(.blue)
        }
    }
}

// MARK: - Preview

#Preview {
    ThoughtBubbleDissolveDemo()
}

