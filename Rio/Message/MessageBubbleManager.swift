//
//  MessageBubbleManager.swift
//  Rio
//
//  Created by Edward Sanchez on 10/30/25.
//

import Foundation
import SwiftUI

/// Manages state and transitions for message bubble content display and animations
@Observable
class MessageBubbleManager {
    // MARK: - Content Display State

    /// Controls typing indicator visibility
    var showTypingIndicatorContent = false

    /// Controls talking content visibility
    var showTalkingContent = false

    /// Whether to include talking text in layout calculations
    var includeTalkingTextInLayout = false

    // MARK: - Width Management

    /// Whether width is locked during animation
    var isWidthLocked = false

    /// Stores width during thinking state for consistent sizing
    var thinkingContentWidth: CGFloat = 0

    // MARK: - Opacity & Display State

    /// Fade opacity for bubble transitions
    var bubbleFadeOpacity: Double = 1

    /// The displayed bubble type (may be delayed relative to actual bubbleType)
    var displayedBubbleType: BubbleType

    // MARK: - Work Items for Scheduled Transitions

    private var widthUnlockWorkItem: DispatchWorkItem?
    private var revealWorkItem: DispatchWorkItem?
    private var bubbleFadeWorkItem: DispatchWorkItem?
    private var modeDelayWorkItem: DispatchWorkItem?

    // MARK: - Configuration

    private let config: BubbleConfiguration

    // MARK: - Initialization

    init(message: Message, config: BubbleConfiguration) {
        self.config = config
        displayedBubbleType = message.bubbleType
    }

    // MARK: - Computed Properties

    /// Whether to show the bubble background (based on content and display state)
    func shouldShowBubbleBackground(for content: ContentType) -> Bool {
        guard content.isEmoji else { return true }
        return !displayedBubbleType.isTalking
    }

    /// Locked width for consistent sizing during animations
    var lockedWidth: CGFloat? {
        guard isWidthLocked, thinkingContentWidth > 0 else { return nil }
        return thinkingContentWidth
    }

    // MARK: - Initial Configuration

    func configureInitialContentState(for bubbleType: BubbleType) {
        cancelPendingContentTransitions()
        switch bubbleType {
        case .thinking:
            isWidthLocked = true
            showTypingIndicatorContent = true
            showTalkingContent = false
            includeTalkingTextInLayout = false
        case .talking:
            isWidthLocked = false
            showTypingIndicatorContent = false
            showTalkingContent = true
            includeTalkingTextInLayout = true
        case .read:
            isWidthLocked = false
            showTypingIndicatorContent = false
            showTalkingContent = false
            includeTalkingTextInLayout = false
        }
    }

    // MARK: - Bubble Type Change Handling

    func handleBubbleTypeChange(from oldType: BubbleType, to newType: BubbleType, hasContent: Bool, isEmoji: Bool) {
        guard oldType != newType else { return }
        cancelPendingContentTransitions()

        // Handle displayedBubbleType delay for thinking→read transition
        if oldType == .thinking, newType == .read {
            // Keep displayedBubbleType at .thinking during explosion
            // It will be updated to .read after explosion completes
            startThinkingToReadTransition()
            scheduleDisplayedTypeUpdate(to: newType, delay: config.explosionDuration)
        } else if oldType == .read, newType == .talking {
            // Handle displayedBubbleType delay for read→talking transition
            // Use a tiny delay (0.02s) to let geometry settle before showing bubble
            // This ensures the bubble appears with its final size and tail position already in place
            startReadToTalkingTransition(hasContent: hasContent)
            scheduleDisplayedTypeUpdate(to: newType, delay: 0.02)
        } else {
            // For all other transitions, update displayedBubbleType immediately
            displayedBubbleType = newType

            if oldType == .thinking, newType == .talking {
                startTalkingTransition(hasContent: hasContent, isEmoji: isEmoji)
            } else if oldType == .talking, newType == .thinking {
                startThinkingState()
            } else if oldType == .read, newType == .thinking {
                startReadToThinkingTransition()
            } else if oldType == .talking, newType == .read {
                startTalkingToReadTransition()
            } else {
                configureInitialContentState(for: newType)
            }
        }
    }

    // MARK: - Transition Methods

    private func startTalkingTransition(hasContent: Bool, isEmoji: Bool) {
        if !hasContent {
            isWidthLocked = false
            showTypingIndicatorContent = false
            showTalkingContent = false
            includeTalkingTextInLayout = false
            return
        }

        if thinkingContentWidth > 0 {
            isWidthLocked = true
        }

        if isEmoji {
            withAnimation(.smooth(duration: 0.2)) {
                showTypingIndicatorContent = false
            }

            withAnimation(.smooth(duration: 0.3)) {
                includeTalkingTextInLayout = true
                showTalkingContent = true
            }

            scheduleWidthUnlock()
            return
        }

        withAnimation(.smooth(duration: 0.2)) {
            showTypingIndicatorContent = false
        }

        showTalkingContent = false
        includeTalkingTextInLayout = false

        scheduleTextLayoutInclusion()
        scheduleWidthUnlock()
        scheduleTalkingReveal()
    }

    private func startThinkingState() {
        isWidthLocked = true
        showTalkingContent = false
        includeTalkingTextInLayout = false
        withAnimation(.smooth(duration: 0.2)) {
            showTypingIndicatorContent = true
        }
    }

    private func startReadToThinkingTransition() {
        // Delay typing indicator until read→thinking animation completes
        isWidthLocked = true
        showTalkingContent = false
        includeTalkingTextInLayout = false

        // Wait for the bubble animation to complete before showing typing indicator
        DispatchQueue.main.asyncAfter(deadline: .now() + config.readToThinkingDuration / 3) {
            withAnimation(.smooth(duration: 0.3)) {
                self.showTypingIndicatorContent = true
            }
        }
    }

    private func startReadToTalkingTransition(hasContent: Bool) {
        // Quick opacity fade when going from read to talking (fast response)
        if !hasContent {
            isWidthLocked = false
            showTypingIndicatorContent = false
            showTalkingContent = false
            includeTalkingTextInLayout = false
            return
        }

        isWidthLocked = false
        showTypingIndicatorContent = false
        includeTalkingTextInLayout = true

        // Quick fade in without offset animation
        withAnimation(.smooth(duration: 0.3)) {
            showTalkingContent = true
        }

        bubbleFadeWorkItem?.cancel()
        bubbleFadeOpacity = 0

        let work = DispatchWorkItem {
            withAnimation(.smooth(duration: 0.4)) {
                self.bubbleFadeOpacity = 1
            }
        }

        bubbleFadeWorkItem = work
        // Displayed type switches after ~0.02s; start bubble fade after avatar growth (~0.3s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02 + 0.3) {
            guard !work.isCancelled else { return }
            work.perform()
            self.bubbleFadeWorkItem = nil
        }
    }

    private func startThinkingToReadTransition() {
        // Immediately hide typing indicator (no animation) when bubbleType changes to read
        showTypingIndicatorContent = false

        // After explosion completes (managed by displayedBubbleType delay), clean up remaining state
        DispatchQueue.main.asyncAfter(deadline: .now() + config.explosionDuration) {
            self.isWidthLocked = false
            self.showTalkingContent = false
            self.includeTalkingTextInLayout = false
        }
    }

    // This should only happen if the message is unsent
    private func startTalkingToReadTransition() {
        // Fade out talking content and go to read state
        withAnimation(.smooth(duration: 0.3)) {
            showTalkingContent = false
        }

        isWidthLocked = false
        showTypingIndicatorContent = false
        includeTalkingTextInLayout = false
    }

    // MARK: - Scheduling Methods

    private func scheduleTextLayoutInclusion() {
        // Include text in layout after morph phase, so it affects height during resize phase
        DispatchQueue.main.asyncAfter(deadline: .now() + config.morphDuration) {
            self.includeTalkingTextInLayout = true
        }
    }

    private func scheduleWidthUnlock() {
        let unlockItem = DispatchWorkItem {
            withAnimation(.smooth(duration: self.config.resizeCutoffDuration)) {
                self.isWidthLocked = false
            }
        }

        widthUnlockWorkItem = unlockItem
        DispatchQueue.main.asyncAfter(deadline: .now() + config.morphDuration) {
            guard !unlockItem.isCancelled else { return }
            unlockItem.perform()
            self.widthUnlockWorkItem = nil
        }
    }

    private func scheduleTalkingReveal() {
        let revealItem = DispatchWorkItem {
            withAnimation(.smooth(duration: 0.35)) {
                self.showTalkingContent = true
            }
        }

        revealWorkItem = revealItem
        DispatchQueue.main.asyncAfter(deadline: .now() + config.textRevealDelay) {
            guard !revealItem.isCancelled else { return }
            revealItem.perform()
            self.revealWorkItem = nil
        }
    }

    private func scheduleDisplayedTypeUpdate(to type: BubbleType, delay: TimeInterval) {
        // Cancel any pending bubbleType updates
        modeDelayWorkItem?.cancel()

        let delayItem = DispatchWorkItem {
            self.displayedBubbleType = type
        }

        modeDelayWorkItem = delayItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard !delayItem.isCancelled else { return }
            delayItem.perform()
            self.modeDelayWorkItem = nil
        }
    }

    // MARK: - Cleanup

    func cancelPendingContentTransitions() {
        widthUnlockWorkItem?.cancel()
        widthUnlockWorkItem = nil
        revealWorkItem?.cancel()
        revealWorkItem = nil
        modeDelayWorkItem?.cancel()
        modeDelayWorkItem = nil
        bubbleFadeWorkItem?.cancel()
        bubbleFadeWorkItem = nil
        bubbleFadeOpacity = 1
    }
}
