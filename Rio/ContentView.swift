//
//  ContentView.swift
//  Rio
//
//  Created by Edward Sanchez on 9/19/25.
//

import SVGPath
import SwiftUI
import Defaults

struct ContentView: View {
    @State private var chatData = ChatData()

    init() {
        let existingUser = Defaults[.currentUser]

        let resolvedUser: User
        if let existingUser {
            resolvedUser = existingUser
        } else {
            let newUser = User(name: "Edward", resource: .edward) //TODO: make it shows an undismissable flow to create the user if no user is found.
            Defaults[.currentUser] = newUser
            resolvedUser = newUser
        }

        _chatData = State(initialValue: ChatData(currentUser: resolvedUser))
    }

    var body: some View {
        NavigationStack {
            ChatListView() // Do not touch this
        }
        .environment(chatData)
    }
}

#Preview {
    ContentView()
        .environment(ChatData())
        .environment(BubbleConfiguration())
}
