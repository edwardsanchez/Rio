//
//  ChatData.swift
//  Rio
//
//  Created by Edward Sanchez on 9/24/25.
//

import SwiftUI
import Defaults

@Observable
class ChatData {
    var chats: [Chat] = []
    // Track visible thinking bubbles per chat (chatId -> participant IDs)
    var activeTypingIndicators: [UUID: Set<UUID>] = [:]
    // Tracks which chat detail sheet is currently presented
    var presentedDetailChatID: UUID?

    // Current signed-in user (for adding reactions)
    let currentUser: User

    // Define users
    let edwardUser = User(id: UUID(), name: "Edward", avatar: .edward)
    let mayaUser = User(id: UUID(), name: "Maya Maria Antonia", avatar: .amy)
    let sophiaUser = User(id: UUID(), name: "Sophia", avatar: .scarlet)
    let liamUser = User(id: UUID(), name: "Liam", avatar: .joaquin)
    let amyUser = User(id: UUID(), name: "Zoe", avatar: .amy)

    init() {
        currentUser = edwardUser //TODO: Make this not set explicitly
        generateSampleChats()
    }

    private func generateSampleChats() {
        // Chat 1: Edward and Maya (2 participants)
        let chat1Messages = [
            Message(content: .text("Hi Rio!\nHow are you doing today?"), from: mayaUser, date: Date().addingTimeInterval(-3600), bubbleType: .talking),
            Message(content: .text("Are you good?"), from: mayaUser, date: Date().addingTimeInterval(-3500), bubbleType: .talking),
            Message(content: .text("Hey!\nI'm doing well, thanks for asking!"), from: edwardUser, date: Date().addingTimeInterval(-3400)),
            Message(content: .emoji("👋"), from: edwardUser, date: Date().addingTimeInterval(-3350)),
            Message(content: .text("This is a very long message that should demonstrate text wrapping behavior in the chat bubble. It contains enough text to exceed the normal width of a single line and should wrap nicely within the bubble constraints without stretching horizontally across the entire screen."), from: mayaUser, date: Date().addingTimeInterval(-3300), bubbleType: .talking)
        ]

        let chat1 = Chat(
            title: nil,
            participants: [edwardUser, mayaUser],
            messages: chat1Messages,
            theme: .defaultTheme,
            currentUser: edwardUser
        )

        // Chat 2: Edward, Sophia, and Liam (3 participants)
        let chat2Messages = [
            Message(content: .text("Hey everyone! Ready for the project meeting?"), from: sophiaUser, date: Date().addingTimeInterval(-7200), bubbleType: .talking),
            Message(content: .text("Yes, I've prepared the slides"), from: edwardUser, date: Date().addingTimeInterval(-7100)),
            Message(content: .text("Great! I'll bring the coffee ☕️"), from: liamUser, date: Date().addingTimeInterval(-7000), bubbleType: .talking),
            Message(content: .text("Perfect team! See you at 3 PM"), from: sophiaUser, date: Date().addingTimeInterval(-6900), bubbleType: .talking),
            Message(content: .text("Looking forward to it!"), from: edwardUser, date: Date().addingTimeInterval(-6800))
        ]

        let chat2 = Chat(
            title: "Design Squad",
            participants: [edwardUser, sophiaUser, liamUser],
            messages: chat2Messages,
            theme: .theme1,
            currentUser: edwardUser
        )

        // Chat 3: Edward, Sophia, Liam, and Zoe (4 participants)
        let chat3Messages = [
            Message(content: .text("Welcome to the group chat!"), from: amyUser, date: Date().addingTimeInterval(-10800), bubbleType: .talking),
            Message(content: .text("Thanks for adding me!"), from: edwardUser, date: Date().addingTimeInterval(-10700)),
            Message(content: .text("Great to have you here Edward"), from: sophiaUser, date: Date().addingTimeInterval(-10600), bubbleType: .talking),
            Message(content: .text("We were just discussing weekend plans"), from: liamUser, date: Date().addingTimeInterval(-10500), bubbleType: .talking),
            Message(content: .text("I'm thinking of going hiking. Anyone interested?"), from: amyUser, date: Date().addingTimeInterval(-10400), bubbleType: .talking),
            Message(content: .text("Count me in! I love hiking"), from: edwardUser, date: Date().addingTimeInterval(-10300))
        ]

        let chat3 = Chat(
            title: "Adventure Crew",
            participants: [edwardUser, sophiaUser, liamUser, amyUser],
            messages: chat3Messages,
            theme: .theme2,
            currentUser: edwardUser
        )

        chats = [chat1, chat2, chat3]
    }

    // Get all participants except Edward for auto-reply
    func getOtherParticipants(in chat: Chat) -> [User] {
        return chat.participants.filter { $0.name != "Edward" }
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
                currentUser: self.currentUser
            )

            guard !options.isEmpty else { return }
            self.applyReactionOptions(options, to: messageId, in: chatId)
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
