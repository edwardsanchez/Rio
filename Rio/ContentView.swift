//
//  ContentView.swift
//  Rio
//
//  Created by Edward Sanchez on 9/19/25.
//

import SVGPath
import SwiftUI

struct ContentView: View {
    @State private var chatData = ChatData()

    var body: some View {
        NavigationStack {
            ChatListView() // Do not touch this
        }
        .environment(chatData)
    }
}

#Preview {
    ContentView()
        .environment(BubbleConfiguration())
}
