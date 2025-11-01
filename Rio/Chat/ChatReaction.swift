//
//  ChatReaction.swift
//  Rio
//
//  Created by ChatGPT on 10/29/25.
//

import SwiftUI
import UIKit

struct ChatReaction: View {
    @Environment(ReactionsCoordinator.self) private var coordinator
    @Environment(ChatData.self) private var chatData
    let bubbleNamespace: Namespace.ID
    @Binding var selectedImageData: ImageData?

    var body: some View {
        ZStack {
            if coordinator.isBackgroundDimmerVisible {
                scrimView
                    .onTapGesture {
                        coordinator.closeActiveMenu()
                    }
            }

            VStack {
                if let context = coordinator.reactingMessage {
                    let reactions = context.message.reactions.filter { reaction in
                        reaction.user.id != chatData.currentUser.id
                    }

                    if !reactions.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .top, spacing: 16) {
                                ForEach(reactions) { reaction in
                                    ReactionParticipantView(
                                        user: reaction.user,
                                        emoji: reaction.emoji
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        .scrollClipDisabled()
                        .padding(.top, 10)
                    }

                    let overlayContext = context.updatingOverlay(true)
                    let formattedTimestamp = context.message.date.chatTimestampString()
                    Spacer()

                    overlayAlignedBubble(for: overlayContext)
                        .padding(.horizontal, 20)
                        .onAppear {
                            coordinator.promoteGeometrySourceToOverlay(for: context.message.id)
                        }
                        .onDisappear {
                            coordinator.resetGeometrySourceToList()
                        }

                    Text(formattedTimestamp)
                        .safeAreaPadding(.all)
                        .font(.footnote.bold())
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if coordinator.isBackgroundDimmerVisible {
                    contextMenu
                        .transition(.move(edge: .bottom))
                } else {
                    contextMenu
                        .hidden()
                        .allowsHitTesting(false)
                }
            }
            .padding(.bottom, 20)
            .ignoresSafeArea(.container, edges: .bottom)
            .animation(.smooth, value: coordinator.isBackgroundDimmerVisible)
        }
    }

    private var scrimView: some View {
        ZStack {
            Rectangle()
                .fill(Material.ultraThin)
            Rectangle()
                .fill(.base.opacity(0.7))
        }
        .ignoresSafeArea()
        .transition(
            .asymmetric(
                insertion: .opacity.animation(.easeIn),
                removal: .opacity.animation(.easeIn(duration: 0.4).delay(0.5))
            )
        )
    }

    private var contextMenu: some View {
        VStack(spacing: 30) {
            Button(action: copyActiveMessage) {
                Label("Copy", systemImage: "document.on.document")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(.rect)
            }

            //TODO: Need to implement save for inbound + outbound images and videos

            //TODO: For outbound, need to eventually implement Undo send
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 40)
        .buttonSizing(.flexible)
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: .containerRelative)
        .padding(.top, 60)
        .padding(.horizontal, 20)
        .contentShape(.rect)
    }

    private func copyActiveMessage() {
        guard let message = coordinator.reactingMessage?.message else { return }
        message.copyToClipboard()
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        coordinator.closeActiveMenu()
    }

    @ViewBuilder
    private func overlayAlignedBubble(for context: MessageBubbleContext) -> some View {
        if context.messageType.isOutbound {
            HStack {
                Spacer()
                bubbleView(for: context)
            }
        } else {
            HStack {
                bubbleView(for: context)
                Spacer()
            }
        }
    }

    private func bubbleView(for context: MessageBubbleContext) -> some View {
        MessageBubbleView(
            message: context.message,
            showTail: context.showTail,
            theme: context.theme,
            bubbleNamespace: bubbleNamespace,
            activeReactingMessageID: coordinator.reactingMessage?.message.id,
            geometrySource: coordinator.geometrySource,
            isReactionsOverlay: context.isReactionsOverlay,
            selectedImageData: $selectedImageData
        )
    }
}

struct ReactionParticipantView: View {
    let user: User
    let emoji: String

    var body: some View {
        VStack(spacing: 4) {
            AvatarView(user: user)
                .frame(width: 60, height: 60)

            Text(user.name)
                .font(.caption)
                .multilineTextAlignment(.center)
                .lineLimit(2, reservesSpace: true)
                .truncationMode(.tail)
        }
        .overlay(alignment: .topTrailing) {
            Text(emoji)
                .font(.system(size: 34))
                .padding(-15)
        }
    }
}

// MARK: - Previews

private struct ChatReactionPreviewContainer: View {
    enum Direction {
        case inbound
        case outbound
    }

    let direction: Direction
    private let previewSetup: PreviewSetup

    @State private var bubbleConfig = BubbleConfiguration()
    @State private var chatData: ChatData
    @State private var coordinator: ReactionsCoordinator
    @State private var selectedImageData: ImageData?
    @Namespace private var bubbleNamespace

    init(direction: Direction) {
        self.direction = direction

        let chatData = ChatData()
        let coordinator = ReactionsCoordinator()
        let bubbleType: BubbleType = .talking
        let theme = ChatTheme.theme1

        let setup = ChatReactionPreviewContainer.makePreviewSetup(
            direction: direction,
            chatData: chatData,
            coordinator: coordinator,
            bubbleType: bubbleType
        )

        let context = MessageBubbleContext(
            message: setup.message,
            theme: theme,
            showTail: true,
            messageType: setup.messageType,
            bubbleType: bubbleType,
            layoutType: bubbleType,
            isReactionsOverlay: false
        )

        if let menuModel = setup.menuModel {
            coordinator.registerMenuModel(menuModel, for: setup.message.id)
        }

        coordinator.reactingMessage = context
        coordinator.geometrySource = .overlay
        coordinator.isBackgroundDimmerVisible = true

        _chatData = State(initialValue: chatData)
        _coordinator = State(initialValue: coordinator)
        _selectedImageData = State(initialValue: nil)
        previewSetup = setup
    }

    var body: some View {
        ChatReaction(
            bubbleNamespace: bubbleNamespace,
            selectedImageData: $selectedImageData
        )
        .id(previewSetup.message.id)
        .environment(bubbleConfig)
        .environment(chatData)
        .environment(coordinator)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }

    private static func makePreviewSetup(
        direction: Direction,
        chatData: ChatData,
        coordinator: ReactionsCoordinator,
        bubbleType: BubbleType
    ) -> PreviewSetup {
        let sampleUsers = chatData.sampleUsers
        let currentUser = chatData.currentUser

        switch direction {
        case .inbound:
            let inboundSender = sampleUsers.maya
            let selectedEmoji = "😍"
            let reactions = [
                MessageReaction(
                    user: currentUser,
                    date: Date(timeIntervalSinceReferenceDate: 1000),
                    emoji: selectedEmoji
                ),
                MessageReaction(
                    user: sampleUsers.zoe,
                    date: Date(timeIntervalSinceReferenceDate: 1200),
                    emoji: "🔥"
                ),
                MessageReaction(
                    user: sampleUsers.liam,
                    date: Date(timeIntervalSinceReferenceDate: 1320),
                    emoji: "👏"
                )
            ]

            var message = Message(
                content: .text("Whoa! Did you see the bubble tail snap into place?"),
                from: inboundSender,
                date: Date(timeIntervalSinceReferenceDate: 900),
                bubbleType: bubbleType,
                reactions: reactions
            )

            message.reactionOptions = ["😍", "🔥", "👏", "👍", "😂", "😲"]

            let menuReactions = makeMenuReactions(for: message)
            let menuModel = ReactionsMenuModel(
                messageID: message.id,
                reactions: menuReactions
            )

            menuModel.selectedReactionID = menuReactions.first { $0.selectedEmoji == selectedEmoji }?.id
            menuModel.state = .open
            menuModel.showBackgroundMenu = false
            menuModel.coordinator = coordinator
            menuModel.chatData = chatData

            return PreviewSetup(
                message: message,
                messageType: .inbound(bubbleType),
                menuModel: menuModel
            )

        case .outbound:
            let reactions = [
                MessageReaction(
                    user: sampleUsers.maya,
                    date: Date(timeIntervalSinceReferenceDate: 1500),
                    emoji: "🤯"
                ),
                MessageReaction(
                    user: sampleUsers.liam,
                    date: Date(timeIntervalSinceReferenceDate: 1800),
                    emoji: "🙌"
                )
            ]

            let message = Message(
                content: .text("Finally unlocked the jelly transition timing!"),
                from: currentUser,
                date: Date(timeIntervalSinceReferenceDate: 1400),
                reactions: reactions
            )

            return PreviewSetup(
                message: message,
                messageType: .outbound,
                menuModel: nil
            )
        }
    }

    private static func makeMenuReactions(for message: Message) -> [Reaction] {
        var reactions = message.reactionOptions.enumerated().map { index, emoji in
            Reaction(
                id: "emoji-\(message.id.uuidString)-\(index)",
                display: .emoji(value: emoji, fontSize: 24),
                selectedEmoji: emoji
            )
        }

        if !reactions.contains(where: { $0.id == Reaction.customEmojiReactionID }) {
            reactions.append(.systemImage("face.dashed", selectedEmoji: "?"))
        }

        return reactions
    }

    private struct PreviewSetup {
        let message: Message
        let messageType: MessageType
        let menuModel: ReactionsMenuModel?
    }
}

#Preview("Inbound Reaction Overlay") {
    ChatReactionPreviewContainer(direction: .inbound)
}

#Preview("Outbound Reaction Overlay") {
    ChatReactionPreviewContainer(direction: .outbound)
}
