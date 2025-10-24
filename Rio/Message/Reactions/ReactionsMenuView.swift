//
//  ReactionsMenuView.swift
//  Rio
//
//  Created by Assistant on 10/24/25.
//

import SwiftUI

struct ReactionsMenuView: View {
    var isOverlay: Bool
    @Bindable var model: ReactionsMenuModel
    var reactionNamespace: Namespace.ID

    private var selectedReaction: Reaction? { model.selectedReaction }

    var body: some View {
        RadialLayout(
            radius: model.calculatedRadius,
            menuIsShowing: model.menuIsShowing,
            itemCount: model.reactions.count,
            itemSpacing: model.calculatedReactionSpacing,
            spacerCenterPercent: model.calculatedSpacerCenterPercent,
            parentSize: model.viewSize
        ) {
            ForEach(Array(model.reactions.enumerated()), id: \.element.id) { index, reaction in
                reactionButton(
                    for: reaction,
                    isVisible: (selectedReaction != reaction) != isOverlay,
                    isOverlay: isOverlay,
                    isSelected: selectedReaction == reaction
                ) {
                    model.handleReactionTap(reaction)
                }
                .animation(
                    .interpolatingSpring(model.menuIsShowing ? .bouncy : .smooth, initialVelocity: model.menuIsShowing ? 0 : -5)
                    .delay(Double(index) * ReactionsMenuModel.AnimationTiming.reactionStaggerStep),
                    value: model.menuIsShowing
                )
            }
        }
        .offset(model.calculatedOffset)
        .animation(ReactionsMenuModel.AnimationTiming.menuOffsetAnimation, value: model.menuIsShowing)
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
                        .fill(isSelected && model.menuIsShowing ? Color.accentColor.opacity(0.3) : .clear)
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
        guard model.selectedReactionID == reaction.id else {
            return !isOverlay
        }
        return isOverlay ? !model.menuIsShowing : model.menuIsShowing
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
