//
//  ContentView.swift
//  Rio
//
//  Created by Edward Sanchez on 9/19/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]

    @State private var message: String = ""
    private let sampleMessages: [Message] = [
        Message(text: "Hi Rio!\nHow are you doing today?", isInbound: true, showTail: false),
        Message(text: "Are you good?", isInbound: true, avatar: .usersample),
        Message(text: "Hey!\nI'm doing well, thanks for asking!", isInbound: false)
    ]

    var body: some View {
        VStack {
            ScrollView {
                VStack(spacing: 5) {
                    ForEach(sampleMessages) { message in
                        MessageBubble(message: message)
                    }
                }
            }
            .contentMargins(20)
            HStack {
                TextField("Message", text: $message)
                    .frame(maxWidth: .infinity)
                    .padding(15)
                    .glassEffect(.clear.interactive())
                    .overlay(alignment: .trailing) {
                        Button {

                        } label: {
                            Image(systemName: "arrow.up")
                                .padding(4)
                                .fontWeight(.bold)
                        }
                        .buttonBorderShape(.circle)
                        .buttonStyle(.borderedProminent)
                    }

            }
                .padding(.horizontal, 30)
        }
        .background {
            Color.base
                .ignoresSafeArea()
        }
        .overlay {
            Rectangle()
                .fill(Gradient(colors: [.white, .black]))
                .ignoresSafeArea()
                .opacity(0.2)
                .blendMode(.overlay)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
