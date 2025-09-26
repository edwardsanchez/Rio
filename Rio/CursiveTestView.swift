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
    @State private var drawProgress: CGFloat = 0

    var animationDuration: Double {
        Double(string.count) / 8
    }

    private let logger = Logger(subsystem: "app.amorfati.Rio", category: "CursiveLetters")

    let string: String = "Hello this is a test for the cursive font"
    let size: Double = 13

    private let wordPadding: CGFloat = 12
    private var fontSizeValue: CGFloat { CGFloat(size) }
    private var measuredWordSize: CGSize {
        CursiveWordShape.preferredSize(for: string, fontSize: fontSizeValue)
            ?? CGSize(width: fontSizeValue * 8, height: fontSizeValue * 1.4)
    }

    var body: some View {
        let fontSize = fontSizeValue
        let wordSize = measuredWordSize

        return VStack {
            Text("Cursive hello")
                .font(.title)
                .padding()

            Text(string)
                .font(.system(size: fontSize))

            ZStack {
                Rectangle().fill(Color.gray.opacity(0.08))

                // The cursive word shape
                CursiveWordShape(text: string, fontSize: fontSize)
                    .trim(from: 0, to: drawProgress)
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: fontSizeValue / 15, lineCap: .round, lineJoin: .round))
                    .frame(width: wordSize.width, height: wordSize.height)

                // The vertical line (pipe) that travels horizontally
                Rectangle()
                    .fill(Color.red)
                    .frame(width: 2, height: wordSize.height)
                    .position(
                        x: drawProgress * wordSize.width,
                        y: wordSize.height / 2
                    )
                    .frame(width: wordSize.width, height: wordSize.height, alignment: .leading)
            }
            .frame(width: wordSize.width + wordPadding * 2, height: wordSize.height + wordPadding * 2)
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
