//
//  BubbleExplodeTestView.swift
//  Shader Test
//
//  Created by Edward Sanchez on 10/17/25.
//

import SwiftUI

struct BubbleExplodeTestView: View {
    @State private var bubbleSize: CGSize = .zero
    @State private var animationProgress: Double = 0.0

    // Animation parameters
    @State private var explosionCenterX: CGFloat = 0.5
    @State private var explosionCenterY: CGFloat = 0.5
    @State private var speedVariance: CGFloat = 0.5
    @State private var gravity: CGFloat = 1.0
    @State private var turbulence: CGFloat = 0.2
    @State private var growth: CGFloat = 0.65
    @State private var growthVariance: CGFloat = 0.65
    @State private var edgeVelocityBoost: CGFloat = 0.8
    @State private var forceSquarePixels: Bool = false
    @State private var fadeStart: CGFloat = 0.3
    @State private var fadeVariance: CGFloat = 0.85

    private let maxExplosionSpread: CGFloat = 0.4
    private let pinchDuration: CGFloat = 0.05

    var body: some View {
        HStack(spacing: 0) {
            // Left side - Controls
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Bubble Explode Shader")
                        .font(.title2)
                        .fontWeight(.bold)

                    // Time control
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Animation Progress")
                            .font(.headline)

                        HStack {
                            Text("0.0")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Slider(value: $animationProgress, in: 0 ... 1)
                            Text("1.0")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Text(String(format: "%.3f", animationProgress))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    // Explosion center
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Explosion Center")
                            .font(.headline)

                        HStack {
                            Text("X:")
                                .frame(width: 20, alignment: .leading)
                            Slider(value: $explosionCenterX, in: 0 ... 1)
                            Text(String(format: "%.2f", explosionCenterX))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 40, alignment: .trailing)
                        }

                        HStack {
                            Text("Y:")
                                .frame(width: 20, alignment: .leading)
                            Slider(value: $explosionCenterY, in: 0 ... 1)
                            Text(String(format: "%.2f", explosionCenterY))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 40, alignment: .trailing)
                        }
                    }

                    Divider()

                    // Speed Variance
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Speed Variance")
                            .font(.headline)
                        HStack {
                            Slider(value: $speedVariance, in: 0 ... 1)
                            Text(String(format: "%.2f", speedVariance))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 40, alignment: .trailing)
                        }
                    }

                    // Gravity
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Gravity")
                            .font(.headline)
                        HStack {
                            Slider(value: $gravity, in: 0 ... 2)
                            Text(String(format: "%.2f", gravity))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 40, alignment: .trailing)
                        }
                    }

                    // Turbulence
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Turbulence")
                            .font(.headline)
                        HStack {
                            Slider(value: $turbulence, in: 0 ... 1)
                            Text(String(format: "%.2f", turbulence))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 40, alignment: .trailing)
                        }
                    }

                    Divider()

                    // Growth
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Growth")
                            .font(.headline)
                        HStack {
                            Slider(value: $growth, in: 0 ... 1)
                            Text(String(format: "%.2f", growth))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 40, alignment: .trailing)
                        }
                    }

                    // Growth Variance
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Growth Variance")
                            .font(.headline)
                        HStack {
                            Slider(value: $growthVariance, in: 0 ... 1)
                            Text(String(format: "%.2f", growthVariance))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 40, alignment: .trailing)
                        }
                    }

                    // Edge Velocity Boost
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Edge Velocity Boost")
                            .font(.headline)
                        HStack {
                            Slider(value: $edgeVelocityBoost, in: 0 ... 2)
                            Text(String(format: "%.2f", edgeVelocityBoost))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 40, alignment: .trailing)
                        }
                    }

                    Divider()

                    // Fade Start
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Fade Start")
                            .font(.headline)
                        HStack {
                            Slider(value: $fadeStart, in: 0 ... 1)
                            Text(String(format: "%.2f", fadeStart))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 40, alignment: .trailing)
                        }
                    }

                    // Fade Variance
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Fade Variance")
                            .font(.headline)
                        HStack {
                            Slider(value: $fadeVariance, in: 0 ... 1)
                            Text(String(format: "%.2f", fadeVariance))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 40, alignment: .trailing)
                        }
                    }

                    Divider()

                    // Force Square Pixels
                    Toggle("Force Square Pixels", isOn: $forceSquarePixels)

                    Spacer()
                }
                .padding()
            }
            .frame(width: 350)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Right side - Preview
            VStack {
                Circle()
                    .fill(.blue.gradient)
                    .frame(width: 300, height: 300)
                    .onGeometryChange(for: CGSize.self) { proxy in
                        proxy.size
                    } action: { newSize in
                        bubbleSize = newSize
                    }
                    .layerEffect(
                        ShaderLibrary.explode(
                            .float(2.0),
                            .float2(bubbleSize),
                            .float(animationProgress),
                            .float2(explosionCenterX, explosionCenterY),
                            .float(speedVariance),
                            .float(gravity),
                            .float(turbulence),
                            .float(growth),
                            .float(growthVariance),
                            .float(edgeVelocityBoost),
                            .float(forceSquarePixels ? 1.0 : 0.0),
                            .float(maxExplosionSpread),
                            .float(fadeStart),
                            .float(fadeVariance),
                            .float(pinchDuration)
                        ),
                        maxSampleOffset: maxSampleOffsetSize
                    )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .textBackgroundColor))
        }
    }

    private var maxSampleOffsetSize: CGSize {
        let maxDimension = max(bubbleSize.width, bubbleSize.height)
        let baseOffset = maxDimension * maxExplosionSpread * animationProgress
        let speedFactor = 1.0 + speedVariance
        let turbulenceFactor = 1.0 + turbulence
        let growthFactor = 1.0 + growth * (1.0 + growthVariance)
        let edgeFactor = 1.0 + edgeVelocityBoost * 1.5

        let widthOffset = baseOffset * speedFactor * 2.0 * turbulenceFactor * growthFactor * edgeFactor
        let heightOffset = baseOffset * speedFactor * 2.5 * turbulenceFactor * growthFactor * edgeFactor

        return CGSize(width: widthOffset, height: heightOffset)
    }
}

#Preview {
    BubbleExplodeTestView()
}
