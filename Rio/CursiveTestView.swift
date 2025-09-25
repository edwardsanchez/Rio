//
//  CursiveTestView.swift
//  Rio
//
//  Created by Edward Sanchez on 9/24/25.
//

import SwiftUI
import SVGPath
import os.log

struct CursiveTestView: View {
    @State private var helloLetters: [CGPath] = []
    @State private var drawProgress: CGFloat = 0

    private let animationDuration: Double = 3.0
    private let logger = Logger(subsystem: "app.amorfati.Rio", category: "CursiveLetters")

    var body: some View {
        VStack {
            Text("Cursive hello")
                .font(.title)
                .padding()

            ZStack {
                Rectangle().fill(Color.gray.opacity(0.08))
                CursiveWordShape(text: "Hello")
                    .trim(from: 0, to: drawProgress)
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
            .frame(width: 400, height: 120)
            .border(Color.red.opacity(0.4))
            .padding()

            Button("Restart Animation") {
                restartAnimation()
            }
            .padding(.top, 8)

            Spacer()
        }
        .onAppear {
            restartAnimation()
        }
    }

    private func restartAnimation() {
        drawProgress = 0
        DispatchQueue.main.async {
            withAnimation(.linear(duration: animationDuration)) {
                drawProgress = 1
            }
        }
    }
}
