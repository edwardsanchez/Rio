//
//  ThoughtBubble.swift
//  Rio
//
//  Created by Edward Sanchez on 10/15/25.
//
import SwiftUI

struct ThoughtBubble: View {
    let text: String
    var body: some View {
        Text(text)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(.white)
                    .shadow(radius: 10, y: 4)
            )
    }
}

struct VaporizeDemo: View {
    @State private var t: CGFloat = 0
    @State private var params = VaporizeParams()

    var body: some View {
        TimelineView(.animation) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            let time = now.truncatingRemainder(dividingBy: 10_000)
            
            // Create a copy of params with updated time
            let currentParams = VaporizeParams(
                progress: params.progress,
                time: time,
                cell: params.cell,
                baseRadius: params.baseRadius,
                sizeJitter: params.sizeJitter,
                speed: params.speed,
                life: params.life,
                wind: params.wind,
                turbulence: params.turbulence,
                twirl: params.twirl,
                drag: params.drag,
                burst: params.burst,
                feather: params.feather,
                seed: params.seed
            )

            VStack(spacing: 24) {
                GeometryReader { geo in
                    ThoughtBubble(text: "poof…")
                        .vaporizeEffect(currentParams, size: geo.size)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 1.2)) {
                                params.progress = 1
                            }
                        }
                }
                .frame(height: 50)

                // Controls for live tuning while you iterate
                controls
            }
            .padding(30)
            .background(Color.black.opacity(0.1))
        }
    }

    var controls: some View {
        Group {
            LabeledContent("Progress") {
                Slider(value: $params.progress, in: 0...1)
            }
            LabeledContent("Cell") {
                Slider(value: $params.cell, in: 3...16)
            }
            LabeledContent("Base radius") {
                Slider(value: $params.baseRadius, in: 1...8)
            }
            LabeledContent("Size jitter") {
                Slider(value: $params.sizeJitter, in: 0...1)
            }
            LabeledContent("Speed") {
                Slider(value: $params.speed, in: 20...400)
            }
            LabeledContent("Life (stagger)") {
                Slider(value: $params.life, in: 0...1)
            }
            LabeledContent("Turbulence") {
                Slider(value: $params.turbulence, in: 0...1)
            }
            LabeledContent("Twirl") {
                Slider(value: $params.twirl, in: 0...1)
            }
            LabeledContent("Drag") {
                Slider(value: $params.drag, in: 0...2)
            }
            LabeledContent("Burst") {
                Slider(value: $params.burst, in: 0...120)
            }
            LabeledContent("Feather") {
                Slider(value: $params.feather, in: 0...3)
            }
            LabeledContent("Wind X") {
                Slider(value: Binding(
                    get: { params.wind.x }, set: { params.wind.x = $0 }), in: -1...1)
            }
            LabeledContent("Wind Y") {
                Slider(value: Binding(
                    get: { params.wind.y }, set: { params.wind.y = $0 }), in: -1...1)
            }
        }
        .tint(.black)
    }
}

#Preview {
    VaporizeDemo()
}
