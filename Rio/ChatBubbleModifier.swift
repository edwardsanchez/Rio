//
//  ChatBubbleModifier.swift
//  Rio
//
//  Created by Edward Sanchez on 10/7/25.
//
import SwiftUI

private struct ChatBubbleModifier: ViewModifier {
    let messageType: MessageType
    let backgroundColor: Color
    let showTail: Bool
    let tailType: BubbleTailType
    let animationWidth: CGFloat?
    let animationHeight: CGFloat?

    @State private var contentSize: CGSize = .zero

    // Computed properties derived from messageType
    private var tailAlignment: Alignment {
        messageType == .inbound ? .bottomLeading : .bottomTrailing
    }

    private var tailOffset: CGSize {
        messageType == .inbound ? CGSize(width: 5, height: 5.5) : CGSize(width: -5, height: 5.5)
    }

    private var tailRotation: Angle {
        messageType == .inbound ? Angle(degrees: 180) : .zero
    }

    private var backgroundOpacity: Double {
        messageType == .inbound ? 0.6 : 1.0
    }

    func body(content: Content) -> some View {
        content
            .padding()
            .background(alignment: .leading) {
                backgroundView
            }
            .onGeometryChange(for: CGSize.self) { proxy in
                proxy.size
            } action: { newSize in
                contentSize = newSize
                print(newSize)
            }
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch tailType {
        case .talking:
            // Standard rounded rectangle background
            let base = RoundedRectangle(cornerRadius: 20)
                .fill(backgroundColor)
//                .frame(width: width, height: height)
                .overlay(alignment: tailAlignment) {
                    tailView
                }

            base
                .compositingGroup()
                .opacity(backgroundOpacity)

        case .thinking:
            // Use ThoughtBubbleView for thinking bubbles
            let bubbleWidth = contentSize.width
            let bubbleHeight = contentSize.height

            // Parameters for ThoughtBubbleView
            let maxDiameter: CGFloat = 23
            let minDiameter: CGFloat = 13
            let blurRadius: CGFloat = 4

            // Optical size compensation algorithm:
            //
            // Problem: ThoughtBubbleView draws circles centered on the perimeter of the inner
            // rectangle. These circles extend maxDiameter/2 both inward and outward, adding
            // visual weight that makes the bubble appear larger than a talking bubble with
            // the same content.
            //
            // Solution Strategy:
            // We want the overall visual bounds to match contentSize, but the circles add
            // visual weight. We have two approaches:
            //
            // Approach A: Reduce inner rectangle, keep content size
            // - Problem: Background becomes smaller than content (content overflows)
            //
            // Approach B: Keep inner rectangle at content size, apply extra negative padding
            // - Problem: Negative padding clips the canvas, but circles still extend
            //
            // Hybrid Approach (current):
            // 1. Slightly reduce inner rectangle to reduce overall footprint
            // 2. The content will naturally center within the available space
            // 3. Apply negative padding to remove canvas borders
            //
            // The reduction factor is empirically tuned for optimal visual balance.
            // Factor of 1.0 would reduce by full maxDiameter (maxDiameter/2 on each side).
            // Factor of 0.5 would reduce by maxDiameter/2 total.
            // We use 0.8 to significantly reduce visual weight while maintaining bubble integrity.
            let opticalReductionFactor: CGFloat = 0.8
            let sizeReduction = maxDiameter * opticalReductionFactor

            // Reduce inner rectangle dimensions to compensate for circle extension
            let adjustedWidth = max(bubbleWidth - sizeReduction, 20)  // Ensure minimum size
            let adjustedHeight = max(bubbleHeight - sizeReduction, 20)

            // Canvas padding to remove (brings canvas edges closer to inner rectangle)
            let canvasPadding = maxDiameter / 2 + blurRadius

            if bubbleWidth > 0 && bubbleHeight > 0 {
                ThoughtBubbleView(
                    width: adjustedWidth,
                    height: adjustedHeight,
                    cornerRadius: 20,
                    minDiameter: minDiameter,
                    maxDiameter: maxDiameter,
                    blurRadius: blurRadius,
                    color: backgroundColor
                )
                // Apply negative padding to compensate for canvas padding
                .padding(-canvasPadding)
                .padding(.leading, 10)
                .overlay(alignment: tailAlignment) {
                    tailView
                }
                .compositingGroup()
                .opacity(backgroundOpacity)
            } else {
                // Temporary placeholder while size is being measured
                RoundedRectangle(cornerRadius: 20)
                    .fill(backgroundColor)
                    .frame(width: animationWidth, height: animationHeight)
                    .overlay(alignment: tailAlignment) {
                        tailView
                    }
                    .compositingGroup()
                    .opacity(backgroundOpacity)
            }
        }
    }

    @ViewBuilder
    private var tailView: some View {
        switch tailType {
        case .talking:
            Image(.cartouche)
                .resizable()
                .frame(width: 15, height: 15)
                .rotation3DEffect(tailRotation, axis: (x: 0, y: 1, z: 0))
                .offset(x: tailOffset.width, y: tailOffset.height)
                .foregroundStyle(backgroundColor)
                .opacity(showTail ? 1 : 0)

        case .thinking:
            // Thinking bubble tail with two circles
            ZStack(alignment: tailAlignment == .bottomLeading ? .bottomLeading : .bottomTrailing) {
                // Larger circle (closer to bubble)
                Circle()
                    .fill(backgroundColor)
                    .frame(width: 14, height: 14)
                    .offset(
                        x: tailAlignment == .bottomLeading ? 12 : -12,
                        y: 15
                    )

                // Smaller circle (further from bubble)
                Circle()
                    .fill(backgroundColor)
                    .frame(width: 8, height: 8)
                    .offset(
                        x: tailAlignment == .bottomLeading ? 8 : -8,
                        y: 25
                    )
            }
            .opacity(showTail ? 1 : 0)
        }
    }
}

extension View {
    func chatBubble(
        messageType: MessageType,
        backgroundColor: Color,
        showTail: Bool,
        tailType: BubbleTailType = .talking,
        animationWidth: CGFloat? = nil,
        animationHeight: CGFloat? = nil
    ) -> some View {
        modifier(
            ChatBubbleModifier(
                messageType: messageType,
                backgroundColor: backgroundColor,
                showTail: showTail,
                tailType: tailType,
                animationWidth: animationWidth,
                animationHeight: animationHeight
            )
        )
    }
}
