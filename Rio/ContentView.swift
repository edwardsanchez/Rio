//
//  ContentView.swift
//  Rio
//
//  Created by Edward Sanchez on 9/19/25.
//

import SwiftUI

struct ContentView: View {
    @State private var chatData = ChatData()

    var body: some View {
        NavigationStack {
            ChatListView(chatData: chatData)
        }
    }
}

#Preview {
    ContentView()
}
