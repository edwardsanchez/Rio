//
//  􀘲 MessageStackView.swift
//  Rio
//
//  Created by Edward Sanchez on 10/8/25.
//

import SwiftUI

// Component to handle the entire message list with date headers
struct MessageStackView: View {
    let messages: [Message]
    @Binding var newMessageId: UUID?
    let inputFieldFrame: CGRect
    let scrollViewFrame: CGRect
    let scrollVelocity: CGFloat
    let scrollPhase: ScrollPhase
    let theme: ChatTheme
    @Binding var selectedImageData: ImageData?
    let bubbleNamespace: Namespace.ID?
    @Environment(ChatData.self) private var chatData
    @Environment(ReactionsCoordinator.self) private var reactionsCoordinator

    var body: some View {
        let activeReactionMessageID = reactionsCoordinator.reactingMessage?.message.id

        LazyVStack(spacing: 0) {
            ForEach(Array(zip(messages.indices, messages)), id: \.1.id) { index, message in
                let isNew = message.id == newMessageId
                var isLastMessageInChat: Bool { messages.last!.id == message.id }
                let showTail = shouldShowTail(at: index)

                VStack(spacing: 5) {
                    if shouldShowDateHeader(at: index) {
                        DateHeaderView(
                            date: message.date,
                            scrollVelocity: scrollVelocity,
                            scrollPhase: scrollPhase,
                            visibleMessageIndex: index
                        )
                        .padding(.vertical, 5)
                    }

                    MessageBubbleView(
                        message: message,
                        showTail: showTail,
                        isNew: isNew,
                        scrollViewFrame: scrollViewFrame,
                        newMessageId: $newMessageId,
                        scrollVelocity: scrollVelocity,
                        scrollPhase: scrollPhase,
                        visibleMessageIndex: index,
                        theme: theme,
                        bubbleNamespace: bubbleNamespace,
                        activeReactingMessageID: activeReactionMessageID,
                        geometrySource: reactionsCoordinator.geometrySource,
                        selectedImageData: $selectedImageData
                    )
                    .padding(.bottom, isLastMessageInChat ? 20 : (showTail ? 15 : 5))
                    .id(message.id) // Essential for ScrollPosition to work
                }
            }
        }
        .scrollTargetLayout() // Optimizes scrolling performance for iOS 18+
    }

    private func shouldShowTail(at index: Int) -> Bool { // Move inside Message Bubble
        let nextIndex = index + 1
        let nextMessageShowsDateHeader = nextIndex < messages.count ? shouldShowDateHeader(at: nextIndex) : false

        return MessageBubbleContext.shouldShowTail(
            in: messages,
            at: index,
            currentUser: chatData.currentUser,
            nextMessageShowsDateHeader: nextMessageShowsDateHeader
        )
    }

    private func shouldShowDateHeader(at index: Int) -> Bool { // keep here
        guard index > 0 else {
            // Always show date header for the first message
            return true
        }

        // Use 5 seconds for testing, change to 3600 (1 hour) for production
        let dateHeaderThreshold: TimeInterval = 3600

        let current = messages[index]
        let previous = messages[index - 1]
        let timeDifference = current.date.timeIntervalSince(previous.date)

        // Show date header if messages are more than threshold apart
        return abs(timeDifference) > dateHeaderThreshold
    }
}
