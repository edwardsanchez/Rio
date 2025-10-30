import Foundation

struct ChatSampleUsers {
    let edward: User
    let maya: User
    let sophia: User
    let liam: User
    let zoe: User
}

protocol ChatSampleProviding {
    var currentUser: User { get }
    var chats: [Chat] { get }
    var sampleUsers: ChatSampleUsers { get }
}

struct ChatSampleData: ChatSampleProviding {
    let currentUser: User
    let chats: [Chat]
    let sampleUsers: ChatSampleUsers

    init(now: Date = Date()) {
        let sampleUsers = ChatSampleUsers(
            edward: User(id: UUID(), name: "Edward", resource: .edward),
            maya: User(id: UUID(), name: "Maya Maria Antonia", resource: .amy),
            sophia: User(id: UUID(), name: "Sophia", resource: .scarlet),
            liam: User(id: UUID(), name: "Liam", resource: .joaquin),
            zoe: User(id: UUID(), name: "Zoe", resource: .amy)
        )

        self.sampleUsers = sampleUsers
        currentUser = sampleUsers.edward
        chats = ChatSampleData.makeChats(
            now: now,
            users: sampleUsers
        )
    }

    private static func makeChats(
        now: Date,
        users: ChatSampleUsers
    ) -> [Chat] {
        let chat1Messages = [
            Message(
                content: .text("Hi Rio!\nHow are you doing today?"),
                from: users.maya,
                date: now.addingTimeInterval(-3600),
                bubbleType: .talking
            ),
            Message(
                content: .text("Are you good?"),
                from: users.maya,
                date: now.addingTimeInterval(-3500),
                bubbleType: .talking
            ),
            Message(
                content: .text("Hey!\nI'm doing well, thanks for asking!"),
                from: users.edward,
                date: now.addingTimeInterval(-3400)
            ),
            Message(content: .emoji("👋"), from: users.edward, date: now.addingTimeInterval(-3350)),
            Message(
                content: .text(
                    "This is a very long message that should demonstrate text wrapping behavior in the chat bubble. It contains enough text to exceed the normal width of a single line and should wrap nicely within the bubble constraints without stretching horizontally across the entire screen."
                ),
                from: users.maya,
                date: now.addingTimeInterval(-3300),
                bubbleType: .talking
            )
        ]

        let chat1 = Chat(
            title: nil,
            participants: [users.edward, users.maya],
            messages: chat1Messages,
            theme: .defaultTheme,
            currentUser: users.edward
        )

        let chat2Messages = [
            Message(
                content: .text("Hey everyone! Ready for the project meeting?"),
                from: users.sophia,
                date: now.addingTimeInterval(-7200),
                bubbleType: .talking
            ),
            Message(
                content: .text("Yes, I've prepared the slides"),
                from: users.edward,
                date: now.addingTimeInterval(-7100)
            ),
            Message(
                content: .text("Great! I'll bring the coffee ☕️"),
                from: users.liam,
                date: now.addingTimeInterval(-7000),
                bubbleType: .talking
            ),
            Message(
                content: .text("Perfect team! See you at 3 PM"),
                from: users.sophia,
                date: now.addingTimeInterval(-6900),
                bubbleType: .talking
            ),
            Message(
                content: .text("Looking forward to it!"),
                from: users.edward,
                date: now.addingTimeInterval(-6800)
            )
        ]

        let chat2 = Chat(
            title: "Design Squad",
            participants: [users.edward, users.sophia, users.liam],
            messages: chat2Messages,
            theme: .theme1,
            currentUser: users.edward
        )

        let chat3Messages = [
            Message(
                content: .text("Welcome to the group chat!"),
                from: users.zoe,
                date: now.addingTimeInterval(-10800),
                bubbleType: .talking
            ),
            Message(
                content: .text("Thanks for adding me!"),
                from: users.edward,
                date: now.addingTimeInterval(-10700)
            ),
            Message(
                content: .text("Great to have you here Edward"),
                from: users.sophia,
                date: now.addingTimeInterval(-10600),
                bubbleType: .talking
            ),
            Message(
                content: .text("We were just discussing weekend plans"),
                from: users.liam,
                date: now.addingTimeInterval(-10500),
                bubbleType: .talking
            ),
            Message(
                content: .text("I'm thinking of going hiking. Anyone interested?"),
                from: users.zoe,
                date: now.addingTimeInterval(-10400),
                bubbleType: .talking
            ),
            Message(
                content: .text("Count me in! I love hiking"),
                from: users.edward,
                date: now.addingTimeInterval(-10300)
            )
        ]

        let chat3 = Chat(
            title: "Adventure Crew",
            participants: [users.edward, users.sophia, users.liam, users.zoe],
            messages: chat3Messages,
            theme: .theme2,
            currentUser: users.edward
        )

        return [chat1, chat2, chat3]
    }
}
