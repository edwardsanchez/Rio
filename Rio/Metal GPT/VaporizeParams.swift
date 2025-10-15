//
//  VaporizeParams.swift
//  Rio
//
//  Created by Edward Sanchez on 10/15/25.
//


import SwiftUI

public struct VaporizeParams {
    public var progress: CGFloat = 0            // 0..1
    public var time: CGFloat = 0                // seconds
    public var cell: CGFloat = 6                // px, particle density controller
    public var baseRadius: CGFloat = 3          // px
    public var sizeJitter: CGFloat = 0.45       // 0..1
    public var speed: CGFloat = 160             // px/sec
    public var life: CGFloat = 0.35             // 0..1 stagger range
    public var wind: CGPoint = .init(x: 1, y: -0.15) // direction
    public var turbulence: CGFloat = 0.6        // 0..1
    public var twirl: CGFloat = 0.4             // 0..1
    public var drag: CGFloat = 0.6              // 0..2
    public var burst: CGFloat = 40              // px radial pop
    public var feather: CGFloat = 1.2           // px
    public var seed: CGFloat = 4.2              // any value

    public init() {}
    
    public init(progress: CGFloat, time: CGFloat, cell: CGFloat, baseRadius: CGFloat, sizeJitter: CGFloat, speed: CGFloat, life: CGFloat, wind: CGPoint, turbulence: CGFloat, twirl: CGFloat, drag: CGFloat, burst: CGFloat, feather: CGFloat, seed: CGFloat) {
        self.progress = progress
        self.time = time
        self.cell = cell
        self.baseRadius = baseRadius
        self.sizeJitter = sizeJitter
        self.speed = speed
        self.life = life
        self.wind = wind
        self.turbulence = turbulence
        self.twirl = twirl
        self.drag = drag
        self.burst = burst
        self.feather = feather
        self.seed = seed
    }
}

public extension View {
    /// Vaporizes the view into small circular motes and drifts them away like a warm steam plume.
    func vaporizeEffect(_ p: VaporizeParams,
                        size: CGSize,
                        maxDisplacement: CGFloat = 320) -> some View {
        let shader = createVaporShader(params: p, size: size)
        let maxOffset = CGSize(width: maxDisplacement, height: maxDisplacement)
        return self.layerEffect(shader, maxSampleOffset: maxOffset)
    }
}

private func createVaporShader(params p: VaporizeParams, size: CGSize) -> Shader {
    let sizeX = Float(size.width)
    let sizeY = Float(size.height)
    let windX = Float(p.wind.x)
    let windY = Float(p.wind.y)
    
    return Shader(
        function: ShaderFunction(library: .default, name: "vaporizeLayer"),
        arguments: [
            .float(Float(p.time)),
            .float(Float(p.progress)),
            .float(Float(p.cell)),
            .float(Float(p.baseRadius)),
            .float(Float(p.sizeJitter)),
            .float(Float(p.speed)),
            .float(Float(p.life)),
            .float(windX),
            .float(windY),
            .float(Float(p.turbulence)),
            .float(Float(p.twirl)),
            .float(Float(p.drag)),
            .float(Float(p.burst)),
            .float(Float(p.feather)),
            .float(Float(p.seed)),
            .float(sizeX),
            .float(sizeY)
        ]
    )
}