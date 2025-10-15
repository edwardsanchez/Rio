import SwiftUI

// MARK: - Vapor Dissolve Parameters
struct VaporDissolveParameters {
    var particleSize: Float = 8.0
    var particleSpeed: Float = 1.0
    var particleLifetime: Float = 1.5
    var sizeRandomness: Float = 0.3
    var windDirection: CGPoint = CGPoint(x: 0.7, y: -0.3)
    var windStrength: Float = 1.0
    var turbulenceIntensity: Float = 1.0
    var dispersalRadius: Float = 2.0
    var fadeOutSpeed: Float = 1.5
    var rotationSpeed: Float = 1.0
    var gravityInfluence: Float = 0.2
    var edgeSoftness: Float = 0.8
    var particleDensity: Float = 1.0
    var noiseScale: Float = 0.01
    var burstIntensity: Float = 0.5
    var burstCenter: CGPoint = CGPoint(x: 0.5, y: 0.5)
    var spiralIntensity: Float = 0.3
    var temperatureVariation: Float = 0.5
}

// MARK: - View Modifier
struct VaporDissolveModifier: ViewModifier {
    let startDate: Date
    @State private var progress: Float = 0
    let duration: TimeInterval
    let parameters: VaporDissolveParameters
    let onComplete: (() -> Void)?
    
    init(
        isDissolving: Bool,
        duration: TimeInterval = 2.0,
        parameters: VaporDissolveParameters = VaporDissolveParameters(),
        onComplete: (() -> Void)? = nil
    ) {
        self.startDate = isDissolving ? Date() : .distantFuture
        self.duration = duration
        self.parameters = parameters
        self.onComplete = onComplete
    }
    
    func body(content: Content) -> some View {
        GeometryReader { geometry in
            let size = geometry.size
            TimelineView(.animation) { context in
                content
                    .layerEffect(
                        Shader(
                            function: ShaderFunction(library: .default, name: "vaporDissolve"),
                            arguments: [
                                .float(Float(context.date.timeIntervalSince1970)),
                                .float(progress),
                                .float(parameters.particleSize),
                                .float(parameters.particleSpeed),
                                .float(parameters.particleLifetime),
                                .float(parameters.sizeRandomness),
                                .float(Float(parameters.windDirection.x)),
                                .float(Float(parameters.windDirection.y)),
                                .float(parameters.windStrength),
                                .float(parameters.turbulenceIntensity),
                                .float(parameters.dispersalRadius),
                                .float(parameters.fadeOutSpeed),
                                .float(parameters.rotationSpeed),
                                .float(parameters.gravityInfluence),
                                .float(parameters.edgeSoftness),
                                .float(parameters.particleDensity),
                                .float(parameters.noiseScale),
                                .float(parameters.burstIntensity),
                                .float(Float(parameters.burstCenter.x)),
                                .float(Float(parameters.burstCenter.y)),
                                .float(parameters.spiralIntensity),
                                .float(parameters.temperatureVariation),
                                .float(Float(size.width)),
                                .float(Float(size.height))
                            ]
                        ),
                        maxSampleOffset: CGSize(width: 200, height: 200)
                    )
                    .onChange(of: context.date) { _, newDate in
                        let elapsed = newDate.timeIntervalSince(startDate)
                        let newProgress = Float(min(elapsed / duration, 1.0))
                        progress = newProgress
                        
                        if newProgress >= 1.0 && onComplete != nil {
                            onComplete?()
                        }
                    }
            }
        }
    }
}

// MARK: - Convenience Extension
extension View {
    func vaporDissolve(
        isDissolving: Bool,
        duration: TimeInterval = 2.0,
        parameters: VaporDissolveParameters = VaporDissolveParameters(),
        onComplete: (() -> Void)? = nil
    ) -> some View {
        self.modifier(
            VaporDissolveModifier(
                isDissolving: isDissolving,
                duration: duration,
                parameters: parameters,
                onComplete: onComplete
            )
        )
    }
}

// MARK: - Demo View
struct VaporDissolveDemo: View {
    @State private var isDissolving = false
    @State private var showContent = true
    @State private var selectedPreset = 0
    
    // Preset configurations
    let presets: [(String, VaporDissolveParameters)] = [
        ("Steam (Default)", VaporDissolveParameters()),
        ("Gentle Bubble Pop", VaporDissolveParameters(
            particleSize: 12,
            particleSpeed: 0.5,
            particleLifetime: 2.0,
            windStrength: 0.3,
            turbulenceIntensity: 0.5,
            gravityInfluence: 0.1, burstIntensity: 0.3,
            temperatureVariation: 0.2
        )),
        ("Explosive Burst", VaporDissolveParameters(
            particleSize: 6,
            particleSpeed: 2.0,
            particleLifetime: 1.0,
            windStrength: 0.1,
            gravityInfluence: 0.0, burstIntensity: 1.0,
            burstCenter: CGPoint(x: 0.5, y: 0.5),
            spiralIntensity: 0.5
        )),
        ("Wind Blown", VaporDissolveParameters(
            particleSize: 8,
            windDirection: CGPoint(x: 1.0, y: 0.0),
            windStrength: 2.0,
            turbulenceIntensity: 1.5,
            gravityInfluence: 0.0,
            spiralIntensity: 0.1
        )),
        ("Heavy Vapor", VaporDissolveParameters(
            particleSize: 10,
            particleSpeed: 0.8,
            windStrength: 0.5, gravityInfluence: 0.8,
            temperatureVariation: 0.0
        ))
    ]
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Vapor Dissolve Effect")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            // Preset selector
            Picker("Preset", selection: $selectedPreset) {
                ForEach(0..<presets.count, id: \.self) { index in
                    Text(presets[index].0).tag(index)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            
            // Demo content with background
            ZStack {
                // Checkered background to show transparency
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                
                if showContent {
                    ThoughtBubbleView()
                        .vaporDissolve(
                            isDissolving: isDissolving,
                            duration: 2.5,
                            parameters: presets[selectedPreset].1,
                            onComplete: {
                                showContent = false
                                isDissolving = false
                            }
                        )
                } else {
                    Text("Press Reset to show content")
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 300, height: 200)
            .border(Color.gray.opacity(0.3), width: 1)
            
            // Controls
            HStack(spacing: 20) {
                Button(action: {
                    if !showContent {
                        showContent = true
                    }
                }) {
                    Label("Reset", systemImage: "arrow.clockwise")
                        .frame(width: 100)
                }
                .buttonStyle(.bordered)
                .disabled(showContent && !isDissolving)
                
                Button(action: {
                    isDissolving = true
                }) {
                    Label("Dissolve", systemImage: "sparkles")
                        .frame(width: 100)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!showContent || isDissolving)
            }
            
            // Parameter details
            GroupBox("Current Parameters") {
                VStack(alignment: .leading, spacing: 8) {
                    let params = presets[selectedPreset].1
                    Text("Particle Size: \(params.particleSize, specifier: "%.1f")")
                    Text("Wind Strength: \(params.windStrength, specifier: "%.1f")")
                    Text("Turbulence: \(params.turbulenceIntensity, specifier: "%.1f")")
                    Text("Burst Intensity: \(params.burstIntensity, specifier: "%.1f")")
                    Text("Temperature Variation: \(params.temperatureVariation, specifier: "%.1f")")
                }
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal)
        }
        .padding()
    }
}

// MARK: - Sample Thought Bubble View
struct ThoughtBubbleView: View {
    var body: some View {
        Circle()
    }
}

// MARK: - Advanced Configuration View
struct VaporDissolveConfigurationView: View {
    @State private var parameters = VaporDissolveParameters()
    @State private var isDissolving = false
    @State private var showContent = true
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Advanced Vapor Dissolve Configuration")
                    .font(.title2)
                    .fontWeight(.bold)
                
                // Demo area
                GroupBox("Preview") {
                    VStack {
                        ZStack {
                            // Background
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                            
                            if showContent {
                                ThoughtBubbleView()
                                    .vaporDissolve(
                                        isDissolving: isDissolving,
                                        duration: 3.0,
                                        parameters: parameters,
                                        onComplete: {
                                            showContent = false
                                            isDissolving = false
                                        }
                                    )
                            } else {
                                Text("Press Reset to show content")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(width: 250, height: 150)
                        .border(Color.gray.opacity(0.3), width: 1)
                        
                        HStack {
                            Button("Reset") {
                                showContent = true
                            }
                            .disabled(showContent && !isDissolving)
                            
                            Button("Dissolve") {
                                isDissolving = true
                            }
                            .disabled(!showContent || isDissolving)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                // Parameter controls
                GroupBox("Particle Settings") {
                    VStack {
                        SliderControl(
                            value: $parameters.particleSize,
                            range: 2...20,
                            label: "Particle Size",
                            format: "%.1f"
                        )
                        
                        SliderControl(
                            value: $parameters.particleDensity,
                            range: 0.5...2.0,
                            label: "Particle Density",
                            format: "%.2f"
                        )
                        
                        SliderControl(
                            value: $parameters.sizeRandomness,
                            range: 0...1,
                            label: "Size Randomness",
                            format: "%.2f"
                        )
                        
                        SliderControl(
                            value: $parameters.edgeSoftness,
                            range: 0...1,
                            label: "Edge Softness",
                            format: "%.2f"
                        )
                    }
                }
                
                GroupBox("Motion Settings") {
                    VStack {
                        SliderControl(
                            value: $parameters.particleSpeed,
                            range: 0.1...3.0,
                            label: "Particle Speed",
                            format: "%.2f"
                        )
                        
                        SliderControl(
                            value: $parameters.windStrength,
                            range: 0...3,
                            label: "Wind Strength",
                            format: "%.2f"
                        )
                        
                        SliderControl(
                            value: $parameters.turbulenceIntensity,
                            range: 0...2,
                            label: "Turbulence",
                            format: "%.2f"
                        )
                        
                        SliderControl(
                            value: $parameters.spiralIntensity,
                            range: 0...1,
                            label: "Spiral Motion",
                            format: "%.2f"
                        )
                        
                        SliderControl(
                            value: $parameters.gravityInfluence,
                            range: 0...1,
                            label: "Gravity",
                            format: "%.2f"
                        )
                    }
                }
                
                GroupBox("Burst Settings") {
                    VStack {
                        SliderControl(
                            value: $parameters.burstIntensity,
                            range: 0...1,
                            label: "Burst Intensity",
                            format: "%.2f"
                        )
                        
                        SliderControl(
                            value: $parameters.dispersalRadius,
                            range: 0.5...5,
                            label: "Dispersal Radius",
                            format: "%.2f"
                        )
                    }
                }
                
                GroupBox("Appearance") {
                    VStack {
                        SliderControl(
                            value: $parameters.particleLifetime,
                            range: 0.5...3,
                            label: "Particle Lifetime",
                            format: "%.2f"
                        )
                        
                        SliderControl(
                            value: $parameters.fadeOutSpeed,
                            range: 0.5...3,
                            label: "Fade Speed",
                            format: "%.2f"
                        )
                        
                        SliderControl(
                            value: $parameters.temperatureVariation,
                            range: 0...1,
                            label: "Temperature Variation",
                            format: "%.2f"
                        )
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Helper Views
struct SliderControl: View {
    @Binding var value: Float
    let range: ClosedRange<Float>
    let label: String
    let format: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                Spacer()
                Text(String(format: format, value))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundColor(.secondary)
            }
            
            Slider(
                value: $value,
                in: range
            )
        }
    }
}

// MARK: - Preview
#Preview("Basic Demo") {
    VaporDissolveDemo()
}

#Preview("Advanced Configuration") {
    VaporDissolveConfigurationView()
}
