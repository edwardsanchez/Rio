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
    let victorUser = User(id: UUID(), name: "Victor", avatar: .edward)
    let aliceUser = User(id: UUID(), name: "Alice", avatar: .scarlet)
    let bobUser = User(id: UUID(), name: "Bob", avatar: .joaquin)
    let charlieUser = User(id: UUID(), name: "Charlie", avatar: nil)
    
    init() {
        generateSampleChats()
    }
    
    private func generateSampleChats() {
        // Chat 1: Edward and Victor (2 participants)
        let chat1Messages = [
            Message(text: "Hi Rio!\nHow are you doing today?", user: victorUser, date: Date().addingTimeInterval(-3600)),
            Message(text: "Are you good?", user: victorUser, date: Date().addingTimeInterval(-3500)),
            Message(text: "Hey!\nI'm doing well, thanks for asking!", user: edwardUser, date: Date().addingTimeInterval(-3400)),
            Message(text: "This is a very long message that should demonstrate text wrapping behavior in the chat bubble. It contains enough text to exceed the normal width of a single line and should wrap nicely within the bubble constraints without stretching horizontally across the entire screen.", user: victorUser, date: Date().addingTimeInterval(-3300))
        ]
        
        let chat1 = Chat(
            title: "Chat with Victor",
            participants: [edwardUser, victorUser],
            messages: chat1Messages
        )
        
        // Chat 2: Edward, Alice, and Bob (3 participants)
        let chat2Messages = [
            Message(text: "Hey everyone! Ready for the project meeting?", user: aliceUser, date: Date().addingTimeInterval(-7200)),
            Message(text: "Yes, I've prepared the slides", user: edwardUser, date: Date().addingTimeInterval(-7100)),
            Message(text: "Great! I'll bring the coffee ☕️", user: bobUser, date: Date().addingTimeInterval(-7000)),
            Message(text: "Perfect team! See you at 3 PM", user: aliceUser, date: Date().addingTimeInterval(-6900)),
            Message(text: "Looking forward to it!", user: edwardUser, date: Date().addingTimeInterval(-6800))
        ]
        
        let chat2 = Chat(
            title: "Project Team",
            participants: [edwardUser, aliceUser, bobUser],
            messages: chat2Messages
        )
        
        // Chat 3: Edward, Alice, Bob, and Charlie (4 participants)
        let chat3Messages = [
            Message(text: "Welcome to the group chat!", user: charlieUser, date: Date().addingTimeInterval(-10800)),
            Message(text: "Thanks for adding me!", user: edwardUser, date: Date().addingTimeInterval(-10700)),
            Message(text: "Great to have you here Edward", user: aliceUser, date: Date().addingTimeInterval(-10600)),
            Message(text: "We were just discussing weekend plans", user: bobUser, date: Date().addingTimeInterval(-10500)),
            Message(text: "I'm thinking of going hiking. Anyone interested?", user: charlieUser, date: Date().addingTimeInterval(-10400)),
            Message(text: "Count me in! I love hiking", user: edwardUser, date: Date().addingTimeInterval(-10300))
        ]
        
        let chat3 = Chat(
            title: "Weekend Squad",
            participants: [edwardUser, aliceUser, bobUser, charlieUser],
            messages: chat3Messages
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
                messages: updatedMessages
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
