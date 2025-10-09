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
            Message(text: "Hi Rio!\nHow are you doing today?", user: mayaUser, date: Date().addingTimeInterval(-3600)),
            Message(text: "Are you good?", user: mayaUser, date: Date().addingTimeInterval(-3500)),
            Message(text: "Hey!\nI'm doing well, thanks for asking!", user: edwardUser, date: Date().addingTimeInterval(-3400)),
            Message(text: "This is a very long message that should demonstrate text wrapping behavior in the chat bubble. It contains enough text to exceed the normal width of a single line and should wrap nicely within the bubble constraints without stretching horizontally across the entire screen.", user: mayaUser, date: Date().addingTimeInterval(-3300))
        ]

        let chat1 = Chat(
            title: "Maya & Edward",
            participants: [edwardUser, mayaUser],
            messages: chat1Messages,
            theme: .defaultTheme
        )

        // Chat 2: Edward, Sophia, and Liam (3 participants)
        let chat2Messages = [
            Message(text: "Hey everyone! Ready for the project meeting?", user: sophiaUser, date: Date().addingTimeInterval(-7200)),
            Message(text: "Yes, I've prepared the slides", user: edwardUser, date: Date().addingTimeInterval(-7100)),
            Message(text: "Great! I'll bring the coffee ☕️", user: liamUser, date: Date().addingTimeInterval(-7000)),
            Message(text: "Perfect team! See you at 3 PM", user: sophiaUser, date: Date().addingTimeInterval(-6900)),
            Message(text: "Looking forward to it!", user: edwardUser, date: Date().addingTimeInterval(-6800))
        ]

        let chat2 = Chat(
            title: "Design Squad",
            participants: [edwardUser, sophiaUser, liamUser],
            messages: chat2Messages,
            theme: .theme1
        )

        // Chat 3: Edward, Sophia, Liam, and Zoe (4 participants)
        let chat3Messages = [
            Message(text: "Welcome to the group chat!", user: amyUser, date: Date().addingTimeInterval(-10800)),
            Message(text: "Thanks for adding me!", user: edwardUser, date: Date().addingTimeInterval(-10700)),
            Message(text: "Great to have you here Edward", user: sophiaUser, date: Date().addingTimeInterval(-10600)),
            Message(text: "We were just discussing weekend plans", user: liamUser, date: Date().addingTimeInterval(-10500)),
            Message(text: "I'm thinking of going hiking. Anyone interested?", user: amyUser, date: Date().addingTimeInterval(-10400)),
            Message(text: "Count me in! I love hiking", user: edwardUser, date: Date().addingTimeInterval(-10300))
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
    
    // Get a random participant for auto-reply (excluding Edward)
    func getRandomParticipantForReply(in chat: Chat) -> User? {
        let otherParticipants = getOtherParticipants(in: chat)
        return otherParticipants.randomElement()
    }
}
