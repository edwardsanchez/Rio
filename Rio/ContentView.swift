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

    var body: some View {
        VStack {
            ScrollView {
                VStack(spacing: 20) {
                    HStack(alignment: .bottom) {
                        Image(.usersample)
                            .resizable()
                            .frame(width: 40, height: 40)
                            .clipShape(.circle)
                            .offset(y: 10)
                        Text("Hi Rio!\nHow are you doing today?")
                            .foregroundStyle(.primary)
                            .padding()
                            .background{
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
                        Spacer()
                    }
                    HStack() {
                        Spacer()
                        Text("Hey!\nI'm doing well, thanks for asking!")
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
