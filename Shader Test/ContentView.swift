//
//  ContentView.swift
//  Shader Test
//
//  Created by Edward Sanchez on 10/17/25.
//

import SwiftUI

enum ShaderTest: String, CaseIterable, Identifiable {
    case bubbleExplode = "BubbleExplode.metal"
    case particleExplosion = "ParticleExplosion.metal"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .bubbleExplode:
            return "Bubble Explode"
        case .particleExplosion:
            return "Particle Explosion"
        }
    }
}

struct ContentView: View {
    @State private var selectedShader: ShaderTest? = .bubbleExplode
    
    var body: some View {
        NavigationSplitView {
            List(ShaderTest.allCases, selection: $selectedShader) { shader in
                NavigationLink(value: shader) {
                    Label(shader.displayName, systemImage: "sparkles")
                }
            }
            .navigationTitle("Shader Tests")
        } detail: {
            if let selectedShader {
                shaderView(for: selectedShader)
            } else {
                Text("Select a shader test")
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private func shaderView(for shader: ShaderTest) -> some View {
        switch shader {
        case .bubbleExplode:
            BubbleExplodeTestView()
        case .particleExplosion:
            ParticleExplosionTestView()
        }
    }
}

#Preview {
    ContentView()
}
