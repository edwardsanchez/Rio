//
//  ExplosionEffectModifier.swift
//  Rio
//
//  Created by Edward Sanchez on 10/16/25.
//
import SwiftUI

// MARK: - Explosion Configuration

/// Configuration for explosion effect parameters
struct ExplosionConfiguration {
    let pixelSize: CGFloat
    let explosionCenter: CGPoint
    let speedVariance: CGFloat
    let gravity: CGFloat
    let turbulence: CGFloat
    let growth: CGFloat
    let growthVariance: CGFloat
    let edgeVelocityBoost: CGFloat
    let forceSquarePixels: Bool
    let maxExplosionSpread: CGFloat
    let fadeStart: CGFloat
    let fadeVariance: CGFloat
    let pinchDuration: CGFloat
    
    /// Default explosion configuration
    static let `default` = ExplosionConfiguration()
    
    init(
        pixelSize: CGFloat = 2.0,
        explosionCenter: CGPoint = CGPoint(x: 0.5, y: 0.5),
        speedVariance: CGFloat = 0.5,
        gravity: CGFloat = 1.0,
        turbulence: CGFloat = 0.2,
        growth: CGFloat = 0.65,
        growthVariance: CGFloat = 0.65,
        edgeVelocityBoost: CGFloat = 2.0,
        forceSquarePixels: Bool = false,
        maxExplosionSpread: CGFloat = 0.4,
        fadeStart: CGFloat = 0.3,
        fadeVariance: CGFloat = 0.85,
        pinchDuration: CGFloat = 0.05
    ) {
        self.pixelSize = pixelSize
        self.explosionCenter = explosionCenter
        self.speedVariance = speedVariance
        self.gravity = gravity
        self.turbulence = turbulence
        self.growth = growth
        self.growthVariance = growthVariance
        self.edgeVelocityBoost = edgeVelocityBoost
        self.forceSquarePixels = forceSquarePixels
        self.maxExplosionSpread = maxExplosionSpread
        self.fadeStart = fadeStart
        self.fadeVariance = fadeVariance
        self.pinchDuration = pinchDuration
    }
}

extension View {
    func explosionEffect(
        isActive: Bool,
        progress: CGFloat,
        configuration: ExplosionConfiguration = .default
    ) -> some View {
        modifier(ExplosionEffectModifier(
            isActive: isActive,
            progress: progress,
            configuration: configuration
        ))
    }
}

// MARK: - Explosion Effect Modifier

/// View modifier that applies the explosion shader effect during thinking→read transition.
private struct ExplosionEffectModifier: ViewModifier {
    let isActive: Bool
    let progress: CGFloat
    let configuration: ExplosionConfiguration
    
    @State private var canvasSize: CGSize = .zero

    func body(content: Content) -> some View {
        if isActive {
            content
                .onGeometryChange(for: CGSize.self) { proxy in
                    proxy.size
                } action: { newSize in
                    canvasSize = newSize
                }
                .layerEffect(
                    ShaderLibrary.explode(
                        .float(configuration.pixelSize),
                        .float2(canvasSize),
                        .float(progress),
                        .float2(configuration.explosionCenter.x, configuration.explosionCenter.y),
                        .float(configuration.speedVariance),
                        .float(configuration.gravity),
                        .float(configuration.turbulence),
                        .float(configuration.growth),
                        .float(configuration.growthVariance),
                        .float(configuration.edgeVelocityBoost),
                        .float(configuration.forceSquarePixels ? 1.0 : 0.0),
                        .float(configuration.maxExplosionSpread),
                        .float(configuration.fadeStart),
                        .float(configuration.fadeVariance),
                        .float(configuration.pinchDuration)
                    ),
                    maxSampleOffset: maxSampleOffsetSize
                )
        } else {
            content
        }
    }

    private var maxSampleOffsetSize: CGSize {
        let maxDimension = max(canvasSize.width, canvasSize.height)
        let baseOffset = maxDimension * configuration.maxExplosionSpread * progress
        let speedFactor = 1.0 + configuration.speedVariance
        let turbulenceFactor = 1.0 + configuration.turbulence
        let growthFactor = 1.0 + configuration.growth * (1.0 + configuration.growthVariance)
        let edgeFactor = 1.0 + 0.8 * configuration.edgeVelocityBoost

        let widthOffset = baseOffset * speedFactor * 2.0 * turbulenceFactor * growthFactor * edgeFactor
        let heightOffset = baseOffset * speedFactor * 2.5 * turbulenceFactor * growthFactor * edgeFactor

        return CGSize(width: widthOffset, height: heightOffset)
    }
}
