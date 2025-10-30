//
//  ReactionsMenuView.swift
//  Rio
//
//  Created by Assistant on 10/24/25.
//

import SwiftUI

// MARK: - Reaction Visibility Helper

/// Determines which reactions should be visible based on menu state
struct ReactionVisibility {
    let menuIsShowing: Bool
    let showBackgroundMenu: Bool
    let isOverlay: Bool
    let isSelected: Bool

    var isVisible: Bool {
        if isOverlay {
            // Overlay shows selected reaction always, others only when menu is open and background is hidden
            if isSelected { return true }
            guard menuIsShowing else { return false }
            return !showBackgroundMenu
        }

        // Background shows non-selected reactions when background is visible
        if isSelected { return false }
        return showBackgroundMenu
    }
}

// MARK: - Reactions Menu View

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
                let isSelected = selectedReaction == reaction
                let visibility = ReactionVisibility(
                    menuIsShowing: reactionsMenuModel.isShowingReactionMenu,
                    showBackgroundMenu: reactionsMenuModel.showBackgroundMenu,
                    isOverlay: isOverlay,
                    isSelected: isSelected
                )

                ReactionButton(
                    reaction: reaction,
                    isVisible: visibility.isVisible,
                    isOverlay: isOverlay,
                    isSelected: isSelected,
                    menuIsShowing: reactionsMenuModel.isShowingReactionMenu,
                    isCustomEmojiHighlighted: reactionsMenuModel.isCustomEmojiHighlighted,
                    reactionNamespace: reactionNamespace,
                    matchedGeometryIsSource: matchedGeometryIsSource(for: reaction, isOverlay: isOverlay),
                    visibilityAnimation: nil
                ) {
                    reactionsMenuModel.handleReactionTap(reaction)
                }
                .animation(
                    .interpolatingSpring(
                        reactionsMenuModel.isShowingReactionMenu ? .bouncy : .smooth,
                        initialVelocity: reactionsMenuModel.isShowingReactionMenu ? 0 : -5
                    )
                    .delay(Double(index) * ReactionsAnimationTiming.reactionStaggerStep),
                    value: reactionsMenuModel.isShowingReactionMenu
                )
            }
        }
        .offset(reactionsMenuModel.calculatedOffset)
        .animation(ReactionsAnimationTiming.menuOffsetAnimation, value: reactionsMenuModel.isShowingReactionMenu)
    }

    private func matchedGeometryIsSource(for reaction: Reaction, isOverlay: Bool) -> Bool {
        guard reactionsMenuModel.selectedReactionID == reaction.id else {
            return !isOverlay
        }

        return isOverlay ? !reactionsMenuModel.isShowingReactionMenu : reactionsMenuModel.isShowingReactionMenu
    }
}
