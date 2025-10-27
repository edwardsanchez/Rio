//
//  ReactionButton.swift
//  Rio
//
//  Created by Assistant on 10/26/25.
//

import SwiftUI

/// Shared reaction button component used in both the radial menu and as a badge
struct ReactionButton: View {
    let reaction: Reaction
    let isVisible: Bool
    let isOverlay: Bool
    let isSelected: Bool
    let menuIsShowing: Bool
    let isCustomEmojiHighlighted: Bool
    let reactionNamespace: Namespace.ID
    let matchedGeometryIsSource: Bool
    let visibilityAnimation: Animation?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            reactionContent
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
        .scaleEffect(scaleFactor)
        .animation(visibilityAnimation) { content in
            content
                .opacity(isVisible ? 1 : 0)
        }
        .matchedGeometryEffect(
            id: reaction.id,
            in: reactionNamespace,
            isSource: matchedGeometryIsSource
        )
        .offset(x: isOverlay ? 25 : 0, y: isOverlay ? -20 : 0)
        .disabled(!isInteractable)
    }

    @ViewBuilder
    private var reactionContent: some View {
        switch reaction.display {
        case let .emoji(value, fontSize):
            Text(value)
                .font(.system(size: fontSize))
                .transition(.scale.combined(with: .opacity).animation(.smooth))
        case let .systemImage(name, pointSize, weight):
            Image(systemName: name)
                .font(.system(size: pointSize, weight: weight))
                .foregroundStyle(.secondary)
        case .placeholder:
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.secondary)
                .scaleEffect(0.8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.scale.combined(with: .opacity).animation(.smooth))
        }
    }

    private var scaleFactor: CGFloat {
        reaction.id == Reaction.customEmojiReactionID && isCustomEmojiHighlighted ? 1.2 : 1
    }

    private var isInteractable: Bool {
        switch reaction.display {
        case let .emoji(value, _):
            return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .systemImage:
            return true
        case .placeholder:
            return false
        }
    }
}
