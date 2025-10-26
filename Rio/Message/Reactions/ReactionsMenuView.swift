//
//  ReactionsMenuView.swift
//  Rio
//
//  Created by Assistant on 10/24/25.
//

import SwiftUI

struct ReactionsMenuView: View {
    var isOverlay: Bool
    var reactionsMenuModel: ReactionsMenuModel
    var reactionNamespace: Namespace.ID

    private var selectedReaction: Reaction? { reactionsMenuModel.selectedReaction }

    var body: some View {
        RadialLayout(
            radius: reactionsMenuModel.calculatedRadius,
            isShowingReactionMenu: reactionsMenuModel.isShowingReactionMenu,
            itemCount: reactionsMenuModel.reactions.count,
            itemSpacing: reactionsMenuModel.calculatedReactionSpacing,
            spacerCenterPercent: reactionsMenuModel.calculatedSpacerCenterPercent,
            parentSize: reactionsMenuModel.viewSize
        ) {
            ForEach(Array(reactionsMenuModel.reactions.enumerated()), id: \.element.id) { index, reaction in
                reactionButton(
                    for: reaction,
                    isVisible: isReactionVisible(
                        reaction,
                        isOverlay: isOverlay,
                        selectedReaction: selectedReaction
                    ),
                    isOverlay: isOverlay,
                    isSelected: selectedReaction == reaction
                ) {
                    reactionsMenuModel.handleReactionTap(reaction)
                }
                .animation(
                    .interpolatingSpring(reactionsMenuModel.isShowingReactionMenu ? .bouncy : .smooth, initialVelocity: reactionsMenuModel.isShowingReactionMenu ? 0 : -5)
                    .delay(Double(index) * ReactionsAnimationTiming.reactionStaggerStep),
                    value: reactionsMenuModel.isShowingReactionMenu
                )
            }
        }
        .offset(reactionsMenuModel.calculatedOffset)
        .animation(ReactionsAnimationTiming.menuOffsetAnimation, value: reactionsMenuModel.isShowingReactionMenu)
    }

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
                        .fill(isSelected && reactionsMenuModel.isShowingReactionMenu ? Color.accentColor.opacity(0.3) : .clear)
                        .frame(width: 44, height: 44)
                        .animation(.smooth, value: isSelected)
                }
        }
        .scaleEffect(scaleFactor(for: reaction))
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
        guard reactionsMenuModel.selectedReactionID == reaction.id else {
            return !isOverlay
        }
        return isOverlay ? !reactionsMenuModel.isShowingReactionMenu : reactionsMenuModel.isShowingReactionMenu
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

    private func scaleFactor(for reaction: Reaction) -> CGFloat {
        reaction.id == Reaction.customEmojiReactionID && reactionsMenuModel.isCustomEmojiHighlighted ? 1.4 : 1
    }

    private func isReactionVisible(
        _ reaction: Reaction,
        isOverlay: Bool,
        selectedReaction: Reaction?
    ) -> Bool {
        let menuIsShowing = reactionsMenuModel.isShowingReactionMenu

        if isOverlay {
            if menuIsShowing {
                return true
            }
            return selectedReaction == reaction
        }

        if reactionsMenuModel.showBackgroundMenu {
            return true
        }

        return menuIsShowing
    }
}
