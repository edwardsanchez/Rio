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
    @State private var messages: [Message] = [
        Message(text: "Hi Rio!\nHow are you doing today?", isInbound: true, showTail: false),
        Message(text: "Are you good?", isInbound: true, avatar: .usersample),
        Message(text: "Hey!\nI'm doing well, thanks for asking!", isInbound: false)
    ]
    @FocusState private var isMessageFieldFocused: Bool

    var body: some View {
        VStack {
            ScrollView {
                VStack(spacing: 5) {
                    ForEach(messages) { message in
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
                    .focused($isMessageFieldFocused)
                    .overlay(alignment: .trailing) {
                        Button {
                            let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmedMessage.isEmpty else { return }
                            messages.append(Message(text: trimmedMessage, isInbound: false))
                            message = ""
                            isMessageFieldFocused = true
                        } label: {
                            Image(systemName: "arrow.up")
                                .padding(4)
                                .fontWeight(.bold)
                        }
                        .buttonBorderShape(.circle)
                        .buttonStyle(.borderedProminent)
                        .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

            }
                .padding(.horizontal, 30)
        }
        .onAppear {
            isMessageFieldFocused = true
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
