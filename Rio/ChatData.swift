//
//  ChatData.swift
//  Rio
//
//  Created by Edward Sanchez on 9/24/25.
//

import SwiftUI

@Observable
class ChatData {
    var chats: [Chat] = []
    // Track visible thinking bubbles per chat (chatId -> participant IDs)
    var activeTypingIndicators: [UUID: Set<UUID>] = [:]
    // Flag used to temporarily disable chat scrolling (e.g., while reaction menus are active).
    var isChatScrollDisabled = false
    // Tracks which message currently displays a reactions menu so we can bring it to the front.
    var activeReactionMessageID: UUID?

    // Define users
    let edwardUser = User(id: UUID(), name: "Edward", avatar: .edward)
    let mayaUser = User(id: UUID(), name: "Maya", avatar: .edward)
    let sophiaUser = User(id: UUID(), name: "Sophia", avatar: .scarlet)
    let liamUser = User(id: UUID(), name: "Liam", avatar: .joaquin)
    let amyUser = User(id: UUID(), name: "Zoe", avatar: .amy)

    init() {
        generateSampleChats()
    }

    private func generateSampleChats() {
        // Chat 1: Edward and Maya (2 participants)
        let chat1Messages = [
            Message(content: .text("Hi Rio!\nHow are you doing today?"), user: mayaUser, date: Date().addingTimeInterval(-3600), messageType: .inbound(.talking)),
            Message(content: .text("Are you good?"), user: mayaUser, date: Date().addingTimeInterval(-3500), messageType: .inbound(.talking)),
            Message(content: .text("Hey!\nI'm doing well, thanks for asking!"), user: edwardUser, date: Date().addingTimeInterval(-3400), messageType: .outbound),
            Message(content: .emoji("👋"), user: edwardUser, date: Date().addingTimeInterval(-3350), messageType: .outbound),
            Message(content: .text("This is a very long message that should demonstrate text wrapping behavior in the chat bubble. It contains enough text to exceed the normal width of a single line and should wrap nicely within the bubble constraints without stretching horizontally across the entire screen."), user: mayaUser, date: Date().addingTimeInterval(-3300), messageType: .inbound(.talking)),
            Message(content: .emoji("😊🎉"), user: mayaUser, date: Date().addingTimeInterval(-3200), messageType: .inbound(.talking))
        ]

        let chat1 = Chat(
            title: "Maya & Edward",
            participants: [edwardUser, mayaUser],
            messages: chat1Messages,
            theme: .defaultTheme
        )

        // Chat 2: Edward, Sophia, and Liam (3 participants)
        let chat2Messages = [
            Message(content: .text("Hey everyone! Ready for the project meeting?"), user: sophiaUser, date: Date().addingTimeInterval(-7200), messageType: .inbound(.talking)),
            Message(content: .text("Yes, I've prepared the slides"), user: edwardUser, date: Date().addingTimeInterval(-7100), messageType: .outbound),
            Message(content: .text("Great! I'll bring the coffee ☕️"), user: liamUser, date: Date().addingTimeInterval(-7000), messageType: .inbound(.talking)),
            Message(content: .text("Perfect team! See you at 3 PM"), user: sophiaUser, date: Date().addingTimeInterval(-6900), messageType: .inbound(.talking)),
            Message(content: .text("Looking forward to it!"), user: edwardUser, date: Date().addingTimeInterval(-6800), messageType: .outbound)
        ]

        let chat2 = Chat(
            title: "Design Squad",
            participants: [edwardUser, sophiaUser, liamUser],
            messages: chat2Messages,
            theme: .theme1
        )

        // Chat 3: Edward, Sophia, Liam, and Zoe (4 participants)
        let chat3Messages = [
            Message(content: .text("Welcome to the group chat!"), user: amyUser, date: Date().addingTimeInterval(-10800), messageType: .inbound(.talking)),
            Message(content: .text("Thanks for adding me!"), user: edwardUser, date: Date().addingTimeInterval(-10700), messageType: .outbound),
            Message(content: .text("Great to have you here Edward"), user: sophiaUser, date: Date().addingTimeInterval(-10600), messageType: .inbound(.talking)),
            Message(content: .text("We were just discussing weekend plans"), user: liamUser, date: Date().addingTimeInterval(-10500), messageType: .inbound(.talking)),
            Message(content: .text("I'm thinking of going hiking. Anyone interested?"), user: amyUser, date: Date().addingTimeInterval(-10400), messageType: .inbound(.talking)),
            Message(content: .text("Count me in! I love hiking"), user: edwardUser, date: Date().addingTimeInterval(-10300), messageType: .outbound)
        ]

        let chat3 = Chat(
            title: "Adventure Crew",
            participants: [edwardUser, sophiaUser, liamUser, amyUser],
            messages: chat3Messages,
            theme: .theme2
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
}
