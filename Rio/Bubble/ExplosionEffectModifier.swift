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
        canvasSize: CGSize,
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
    ) -> some View {
        modifier(ExplosionEffectModifier(
            isActive: isActive,
            progress: progress,
            canvasSize: canvasSize,
            pixelSize: pixelSize,
            explosionCenter: explosionCenter,
            speedVariance: speedVariance,
            gravity: gravity,
            turbulence: turbulence,
            growth: growth,
            growthVariance: growthVariance,
            edgeVelocityBoost: edgeVelocityBoost,
            forceSquarePixels: forceSquarePixels,
            maxExplosionSpread: maxExplosionSpread,
            fadeStart: fadeStart,
            fadeVariance: fadeVariance,
            pinchDuration: pinchDuration
        ))
    }
}

// MARK: - Explosion Effect Modifier

/// View modifier that applies the explosion shader effect during thinking→read transition.
private struct ExplosionEffectModifier: ViewModifier {
    // Required parameters (no defaults)
    let isActive: Bool
    let progress: CGFloat
    let canvasSize: CGSize
    
    // Optional parameters (with defaults)
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

    func body(content: Content) -> some View {
        if isActive {
            content
                .layerEffect(
                    ShaderLibrary.explode(
                        .float(pixelSize),
                        .float2(canvasSize),
                        .float(progress),
                        .float2(explosionCenter.x, explosionCenter.y),
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
        } else {
            content
        }
    }

    private var maxSampleOffsetSize: CGSize {
        let maxDimension = max(canvasSize.width, canvasSize.height)
        let baseOffset = maxDimension * maxExplosionSpread * progress
        let speedFactor = 1.0 + speedVariance
        let turbulenceFactor = 1.0 + turbulence
        let growthFactor = 1.0 + growth * (1.0 + growthVariance)
        let edgeFactor = 1.0 + 0.8 * edgeVelocityBoost

        let widthOffset = baseOffset * speedFactor * 2.0 * turbulenceFactor * growthFactor * edgeFactor
        let heightOffset = baseOffset * speedFactor * 2.5 * turbulenceFactor * growthFactor * edgeFactor

        return CGSize(width: widthOffset, height: heightOffset)
    }
}
