//
//  ReactionsMenuView.swift
//  Rio
//
//  Created by Assistant on 10/24/25.
//

import SwiftUI

struct ReactionsMenuView: View {
    var isOverlay: Bool
    var reactions: [Reaction]
    var menuIsShowing: Bool
    var radius: CGFloat
    var itemSpacing: CGFloat
    var spacerCenterPercent: CGFloat
    var parentSize: CGSize
    var calculatedOffset: CGSize
    @Binding var selectedReactionID: Reaction.ID?
    var reactionNamespace: Namespace.ID
    var reactionStaggerStep: TimeInterval
    var menuOffsetAnimation: Animation
    var onTap: (Reaction) -> Void

    private var selectedReaction: Reaction? {
        guard let selectedReactionID else { return nil }
        return reactions.first { $0.id == selectedReactionID }
    }

    var body: some View {
        RadialLayout(
            radius: radius,
            menuIsShowing: menuIsShowing,
            itemCount: reactions.count,
            itemSpacing: itemSpacing,
            spacerCenterPercent: spacerCenterPercent,
            parentSize: parentSize
        ) {
            ForEach(Array(reactions.enumerated()), id: \.element.id) { index, reaction in
                reactionButton(
                    for: reaction,
                    isVisible: (selectedReaction != reaction) != isOverlay,
                    isOverlay: isOverlay,
                    isSelected: selectedReaction == reaction
                ) {
                    onTap(reaction)
                }
                .animation(
                    .interpolatingSpring(menuIsShowing ? .bouncy : .smooth, initialVelocity: menuIsShowing ? 0 : -5)
                    .delay(Double(index) * reactionStaggerStep),
                    value: menuIsShowing
                )
            }
        }
        .offset(calculatedOffset)
        .animation(menuOffsetAnimation, value: menuIsShowing)
    }

    @ViewBuilder
    private func reactionButton(
        for reaction: Reaction,
        isVisible: Bool,
        isOverlay: Bool,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            reactionContent(for: reaction)
                .frame(width: 28, height: 28)
                .shadow(color: Color.base.opacity(1), radius: 3)
                .background {
                    Circle()
                        .fill(isSelected && menuIsShowing ? Color.accentColor.opacity(0.3) : .clear)
                        .frame(width: 44, height: 44)
                        .animation(.smooth, value: isSelected)
                }
        }
        .buttonBorderShape(.circle)
        .buttonStyle(.glass)
        .animation(isVisible ? .smooth : nil) { content in
            content
                .opacity(isVisible ? 1 : 0)
        }
        .matchedGeometryEffect(
            id: reaction.id,
            in: reactionNamespace,
            isSource: matchedGeometryIsSource(for: reaction, isOverlay: isOverlay)
        )
        .offset(x: isOverlay ? 25 : 0, y: isOverlay ? -20 : 0)
    }

    private func matchedGeometryIsSource(for reaction: Reaction, isOverlay: Bool) -> Bool {
        guard selectedReactionID == reaction.id else {
            return !isOverlay
        }
        return isOverlay ? !menuIsShowing : menuIsShowing
    }

    @ViewBuilder
    private func reactionContent(for reaction: Reaction) -> some View {
        switch reaction.display {
        case let .emoji(value, fontSize):
            Text(value)
                .font(.system(size: fontSize))
        case let .systemImage(name, pointSize, weight):
            Image(systemName: name)
                .font(.system(size: pointSize, weight: weight))
                .foregroundStyle(.secondary)
        }
    }
}
