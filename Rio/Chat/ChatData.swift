//
//  ChatData.swift
//  Rio
//
//  Created by Edward Sanchez on 9/24/25.
//

import Defaults
import SwiftUI

@Observable
class ChatData {
    var chats: [Chat]
    // Track visible thinking bubbles per chat (chatId -> participant IDs)
    var activeTypingIndicators: [UUID: Set<UUID>] = [:]
    // Tracks which chat detail sheet is currently presented
    var presentedDetailChatID: UUID?

    // Current signed-in user (for adding reactions)
    let currentUser: User
    private let sampleProvider: ChatSampleProviding

    init(
        sampleProvider: ChatSampleProviding = ChatSampleData(),
        currentUser: User? = nil
    ) {
        self.sampleProvider = sampleProvider

        let resolvedCurrentUser = currentUser ?? sampleProvider.currentUser
        self.currentUser = resolvedCurrentUser

        if resolvedCurrentUser.id == sampleProvider.currentUser.id {
            chats = sampleProvider.chats
        } else {
            chats = sampleProvider.chats.map { chat in
                ChatData.replaceCurrentUser(
                    in: chat,
                    oldUser: sampleProvider.currentUser,
                    newUser: resolvedCurrentUser
                )
            }
        }
    }

    var sampleUsers: ChatSampleUsers {
        sampleProvider.sampleUsers
    }

    // Get all participants except the current user for auto-reply
    func getOtherParticipants(in chat: Chat) -> [User] {
        chat.participants.filter { $0.id != currentUser.id }
    }

    // Add a message to a specific chat
    func addMessage(_ message: Message, to chatId: UUID) {
        if let chatIndex = chats.firstIndex(where: { $0.id == chatId }) {
            var updatedChat = chats[chatIndex]
            var updatedMessages = updatedChat.messages
            updatedMessages.append(message)

            updatedChat = Chat(
                id: updatedChat.id,
                title: updatedChat.title,
                participants: updatedChat.participants,
                messages: updatedMessages,
                theme: updatedChat.theme
            )

            chats[chatIndex] = updatedChat
            if let appendedMessage = updatedChat.messages.last {
                scheduleReactionOptions(for: appendedMessage, in: updatedChat)
            }
        }
    }

    func updateMessage(_ message: Message, in chatId: UUID) {
        guard let chatIndex = chats.firstIndex(where: { $0.id == chatId }) else { return }
        var updatedChat = chats[chatIndex]
        var updatedMessages = updatedChat.messages
        if let messageIndex = updatedMessages.firstIndex(where: { $0.id == message.id }) {
            updatedMessages[messageIndex] = message
            updatedChat = Chat(
                id: updatedChat.id,
                title: updatedChat.title,
                participants: updatedChat.participants,
                messages: updatedMessages,
                theme: updatedChat.theme
            )

            chats[chatIndex] = updatedChat
            let resolvedMessage = updatedMessages[messageIndex]
            scheduleReactionOptions(for: resolvedMessage, in: updatedChat)
        }
    }

    func addReaction(_ emoji: String, toMessageId messageId: UUID) {
        guard let chatIndex = chats.firstIndex(where: { chat in
            chat.messages.contains(where: { $0.id == messageId })
        }) else { return }

        var updatedChat = chats[chatIndex]
        var updatedMessages = updatedChat.messages
        guard let messageIndex = updatedMessages.firstIndex(where: { $0.id == messageId }) else { return }

        var message = updatedMessages[messageIndex]
        let newReaction = MessageReaction(user: currentUser, date: Date(), emoji: emoji)
        message.reactions.append(newReaction)
        updatedMessages[messageIndex] = message

        updatedChat = Chat(
            id: updatedChat.id,
            title: updatedChat.title,
            participants: updatedChat.participants,
            messages: updatedMessages,
            theme: updatedChat.theme
        )

        chats[chatIndex] = updatedChat
    }

    func updateChatTitle(_ title: String?, for chatId: UUID) {
        guard let chatIndex = chats.firstIndex(where: { $0.id == chatId }) else { return }
        let chat = chats[chatIndex]
        let trimmedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let updatedChat = Chat(
            id: chat.id,
            title: trimmedTitle.isEmpty ? nil : trimmedTitle,
            participants: chat.participants,
            messages: chat.messages,
            theme: chat.theme,
            currentUser: currentUser
        )

        chats[chatIndex] = updatedChat
    }

    func updateChatTheme(_ theme: ChatTheme, for chatId: UUID) {
        guard let chatIndex = chats.firstIndex(where: { $0.id == chatId }) else { return }
        let chat = chats[chatIndex]

        let updatedChat = Chat(
            id: chat.id,
            title: chat.title,
            participants: chat.participants,
            messages: chat.messages,
            theme: theme,
            currentUser: currentUser
        )

        chats[chatIndex] = updatedChat
    }

    func removeParticipant(_ participant: User, from chatId: UUID) {
        guard participant.id != currentUser.id else { return }
        guard let chatIndex = chats.firstIndex(where: { $0.id == chatId }) else { return }

        let chat = chats[chatIndex]
        let updatedParticipants = chat.participants.filter { $0.id != participant.id }

        guard updatedParticipants.count != chat.participants.count else { return }

        let previousFallbackTitle = Chat.fallbackTitle(for: chat.participants, currentUser: currentUser)
        let shouldUseFallback = chat.title == previousFallbackTitle
        let resolvedTitle: String? = shouldUseFallback ? nil : chat.title

        let updatedChat = Chat(
            id: chat.id,
            title: resolvedTitle,
            participants: updatedParticipants,
            messages: chat.messages,
            theme: chat.theme,
            currentUser: currentUser
        )

        chats[chatIndex] = updatedChat
    }

    func removeChat(withId chatId: UUID) {
        chats.removeAll { $0.id == chatId }
        activeTypingIndicators.removeValue(forKey: chatId)
        updateMutedChatIDs { $0.remove(chatId) }
        if presentedDetailChatID == chatId {
            presentedDetailChatID = nil
        }
    }

    func isChatMuted(_ chatId: UUID) -> Bool {
        Defaults[.mutedChatIDs].contains(chatId)
    }

    func setChatMuted(_ chatId: UUID, isMuted: Bool) {
        updateMutedChatIDs { mutedChatIDs in
            if isMuted {
                mutedChatIDs.insert(chatId)
            } else {
                mutedChatIDs.remove(chatId)
            }
        }
    }

    func setTypingIndicator(_ visible: Bool, for userId: UUID, in chatId: UUID) {
        var indicatorSet = activeTypingIndicators[chatId] ?? []
        if visible {
            indicatorSet.insert(userId)
        } else {
            indicatorSet.remove(userId)
        }

        if indicatorSet.isEmpty {
            activeTypingIndicators.removeValue(forKey: chatId)
        } else {
            activeTypingIndicators[chatId] = indicatorSet
        }
    }

    func isTypingIndicatorVisible(for userId: UUID, in chatId: UUID) -> Bool {
        activeTypingIndicators[chatId]?.contains(userId) ?? false
    }

    // Get a random participant for auto-reply (excluding Edward)
    func getRandomParticipantForReply(in chat: Chat) -> User? {
        let otherParticipants = getOtherParticipants(in: chat)
        return otherParticipants.randomElement()
    }

    private func updateMutedChatIDs(_ modify: (inout Set<UUID>) -> Void) {
        var mutedChatIDs = Set(Defaults[.mutedChatIDs])
        modify(&mutedChatIDs)
        Defaults[.mutedChatIDs] = Array(mutedChatIDs)
    }

    func isDetailPresented(for chatId: UUID) -> Bool {
        presentedDetailChatID == chatId
    }

    func presentDetail(for chatId: UUID) {
        presentedDetailChatID = chatId
    }

    func dismissDetail(for chatId: UUID) {
        guard presentedDetailChatID == chatId else { return }
        presentedDetailChatID = nil
    }

    private func scheduleReactionOptions(for message: Message, in chat: Chat) {
        guard message.messageType(currentUser: currentUser).isInbound,
              !message.isTypingIndicator,
              message.reactionOptions.isEmpty else { return }

        let chatId = chat.id
        let messageId = message.id
        let messagesSnapshot = chat.messages

        Task { [weak self] in
            guard let self else { return }
            let options = await MessageEmojiService.reactionOptions(
                for: message,
                in: messagesSnapshot,
                currentUser: currentUser
            )

            guard !options.isEmpty else { return }
            applyReactionOptions(options, to: messageId, in: chatId)
        }
    }

    @MainActor
    private func applyReactionOptions(_ options: [String], to messageId: UUID, in chatId: UUID) {
        guard let chatIndex = chats.firstIndex(where: { $0.id == chatId }) else { return }

        var chat = chats[chatIndex]
        var messages = chat.messages

        guard let messageIndex = messages.firstIndex(where: { $0.id == messageId }) else { return }

        var targetMessage = messages[messageIndex]
        guard targetMessage.reactionOptions != options else { return }

        targetMessage.reactionOptions = options
        messages[messageIndex] = targetMessage

        chat = Chat(
            id: chat.id,
            title: chat.title,
            participants: chat.participants,
            messages: messages,
            theme: chat.theme
        )

        chats[chatIndex] = chat
    }
}

extension ChatData {
    //TODO: Remove this probably
    private static func replaceCurrentUser(
        in chat: Chat,
        oldUser: User,
        newUser: User
    ) -> Chat {
        let updatedParticipants = chat.participants.map { participant in
            participant.id == oldUser.id ? newUser : participant
        }

        let updatedMessages = chat.messages.map { message -> Message in
            if message.user.id == oldUser.id {
                var updatedMessage = Message(
                    id: message.id,
                    content: message.content,
                    from: newUser,
                    date: message.date
                )

                updatedMessage.reactions = ChatData.replaceReactions(
                    in: message,
                    oldUser: oldUser,
                    newUser: newUser
                )
                updatedMessage.reactionOptions = message.reactionOptions

                return updatedMessage
            } else {
                var updatedMessage = message
                updatedMessage.reactions = ChatData.replaceReactions(
                    in: message,
                    oldUser: oldUser,
                    newUser: newUser
                )
                return updatedMessage
            }
        }

        return Chat(
            id: chat.id,
            title: chat.title,
            participants: updatedParticipants,
            messages: updatedMessages,
            theme: chat.theme,
            currentUser: newUser
        )
    }

    private static func replaceReactions(
        in message: Message,
        oldUser: User,
        newUser: User
    ) -> [MessageReaction] {
        message.reactions.map { reaction in
            if reaction.user.id == oldUser.id {
                MessageReaction(
                    user: newUser,
                    date: reaction.date,
                    emoji: reaction.emoji
                )
            } else {
                reaction
            }
        }
    }
}
