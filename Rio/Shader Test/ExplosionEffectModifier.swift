//
//  ExplosionEffectModifier.swift
//  Rio
//
//  Created by Edward Sanchez on 10/16/25.
//
import SwiftUI

extension View {
    func explosionEffect(
        isActive: Bool,
        progress: CGFloat,
        canvasSize: CGSize
    ) -> some View {
        modifier(ExplosionEffectModifier(isActive: isActive, progress: progress, canvasSize: canvasSize))
    }
}

// MARK: - Explosion Effect Modifier

/// View modifier that applies the explosion shader effect during thinking→read transition.
private struct ExplosionEffectModifier: ViewModifier {
    let isActive: Bool
    let progress: CGFloat
    let canvasSize: CGSize

    func body(content: Content) -> some View {
        if isActive {
            content
                .layerEffect(
                    ShaderLibrary.explode(
                        .float(2.0), // Fixed pixel size
                        .float2(canvasSize),
                        .float(progress),
                        .float2(0.5, 0.57), // explosionCenter
                        .float(0.5), // speedVariance
                        .float(1.0), // gravity
                        .float(0.2), // turbulence
                        .float(0.65), // growth
                        .float(0.65), // growthVariance
                        .float(0.8), // edgeVelocityBoost
                        .float(0.0), // forceSquarePixels (false)
                        .float(0.4), // maxExplosionSpread
                        .float(0.3), // fadeStart
                        .float(0.85), // fadeVariance
                        .float(0.05)  // pinchDuration
                    ),
                    maxSampleOffset: maxSampleOffsetSize
                )
        } else {
            content
        }
    }

    private var maxSampleOffsetSize: CGSize {
        let maxDimension = max(canvasSize.width, canvasSize.height)
        let baseOffset = maxDimension * 0.4 * progress // maxExplosionSpread = 0.4
        let speedFactor = 1.0 + 0.5 // speedVariance
        let turbulenceFactor = 1.0 + 0.2 // turbulence
        let growthFactor = 1.0 + 0.65 * (1.0 + 0.65) // growth * (1 + growthVariance)
        let edgeFactor = 1.0 + 0.8 * 1.5 // edgeVelocityBoost

        let widthOffset = baseOffset * speedFactor * 2.0 * turbulenceFactor * growthFactor * edgeFactor
        let heightOffset = baseOffset * speedFactor * 2.5 * turbulenceFactor * growthFactor * edgeFactor

        return CGSize(width: widthOffset, height: heightOffset)
    }
}
