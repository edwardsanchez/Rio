//
//  ContentView.swift
//  Rio
//
//  Created by Edward Sanchez on 9/19/25.
//

import SwiftUI
import SwiftData

struct Message: Identifiable {
    let id: UUID
    let text: String
    let isInbound: Bool

    init(id: UUID = UUID(), text: String, isInbound: Bool) {
        self.id = id
        self.text = text
        self.isInbound = isInbound
    }
}

struct MessageBubble: View {
    let text: String
    let isInbound: Bool

    init(text: String, isInbound: Bool) {
        self.text = text
        self.isInbound = isInbound
    }

    init(message: Message) {
        self.init(text: message.text, isInbound: message.isInbound)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            if isInbound {
                Image(.usersample)
                    .resizable()
                    .frame(width: 40, height: 40)
                    .clipShape(.circle)
                    .offset(y: 10)

                inboundBubble
                Spacer()
            } else {
                Spacer()
                outboundBubble
            }
        }
    }

    private var inboundBubble: some View {
        Text(text)
            .foregroundStyle(.primary)
            .padding()
            .background {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.userBubble)
                    .overlay(alignment: .bottomLeading) {
                        Image(.cartouche)
                            .resizable()
                            .frame(width: 15, height: 15)
                            .rotation3DEffect(Angle(degrees: 180), axis: (x: 0, y: 1, z: 0))
                            .offset(x: 5, y: 5.5)
                            .foregroundStyle(Color.userBubble)
                    }
                    .compositingGroup()
                    .opacity(0.6)
            }
    }

    private var outboundBubble: some View {
        Text(text)
            .foregroundStyle(.white)
            .padding()
            .background {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.ownBubble)
                    .overlay(alignment: .bottomTrailing) {
                        Image(.cartouche)
                            .resizable()
                            .frame(width: 15, height: 15)
                            .offset(x: -5, y: 5.5)
                            .foregroundStyle(Color.ownBubble)
                    }
            }
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    
    @State private var message: String = ""
    private let sampleMessages: [Message] = [
        Message(text: "Hi Rio!\nHow are you doing today?", isInbound: true),
        Message(text: "Hey!\nI'm doing well, thanks for asking!", isInbound: false)
    ]

    var body: some View {
        VStack {
            ScrollView {
                VStack(spacing: 20) {
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
