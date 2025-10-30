//
//  ChatSettings.swift
//  Rio
//
//  Created by ChatGPT on 10/29/25.
//

import SwiftUI

struct ChatSettings: View {
    let chat: Chat
    let fallbackChatTitle: String
    let avatarNamespace: Namespace.ID
    let avatarTransitionAnimation: Animation
    let onDestructiveAction: () -> Void

    @Environment(ChatData.self) private var chatData

    @State private var isThemePickerPresented = false

    private var isPresented: Bool {
        chatData.isDetailPresented(for: chat.id)
    }

    private var isGroupChat: Bool {
        chat.participants.count > 2
    }

    private var participantGridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 60, maximum: 100), spacing: 20, alignment: .leading)]
    }

    private var chatNameBinding: Binding<String> {
        Binding(
            get: {
                let currentTitle = chat.title
                return currentTitle == fallbackChatTitle ? "" : currentTitle
            },
            set: { newValue in
                chatData.updateChatTitle(newValue, for: chat.id)
            }
        )
    }

    private var hideAlertsBinding: Binding<Bool> {
        Binding(
            get: { chatData.isChatMuted(chat.id) },
            set: { isMuted in
                chatData.setChatMuted(chat.id, isMuted: isMuted)
                // TODO: Connect hide alerts toggle to notification preferences
            }
        )
    }

    private var resolvedThemeColor: Color {
        chatData.chats.first(where: { $0.id == chat.id })?.theme.outboundBackgroundColor
            ?? chat.theme.outboundBackgroundColor
    }

    var body: some View {
        if isPresented {
            NavigationStack {
                Form {
                    participantsSection

                    settingsSection

                    destructiveSection
                }
                .navigationBarTitleDisplayMode(.inline)
                .navigationTitle(chat.title)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: close) {
                            Label("Close", systemImage: "xmark")
                        }
                        .tint(.primary)
                        .buttonBorderShape(.circle)
                    }
                }
                .sheet(isPresented: $isThemePickerPresented) {
                    ThemePickerView(
                        selectedColor: resolvedThemeColor
                    ) { selectedColor in
                        chatData.updateChatTheme(
                            ChatTheme(outboundBackgroundColor: selectedColor),
                            for: chat.id
                        )

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            isThemePickerPresented = false
                        }
                    }
                    .presentationDetents([.height(240)])
                }
            }
            .transition(
//                .move(edge: .bottom)
                .opacity
            )
        }
    }

    private var participantsSection: some View {
        Section {
            LazyVGrid(columns: participantGridColumns) {
                ForEach(chat.participants) { participant in
                    VStack(spacing: 3) {
                        AvatarView(
                            user: participant,
                            namespace: avatarNamespace,
                            matchedGeometryID: chat.avatarGeometryKey(for: participant),
                            isGeometrySource: true,
                            matchedGeometryAnimation: avatarTransitionAnimation
                        )

                        Text(participant.name)
                            .font(.caption)
                            .fixedSize()
                    }
                    .contextMenu {
                        Button("Remove from Group") {

                        }
                        //TODO: Implement this, this is a role destructive.
                        //Use the xmark icon for this

                        Button("Chat 1:1") {

                        }
                        //TODO: Use person.2.fill icon
                    }
                }
            }
            .padding(.vertical, 8)

            //TODO: Add an "Add" button here which will open a sheet and allow you to add a participant to this chat. It will have plus sf symbol and the label below it should say "Add"
        } header: {
            Text("Participants")
        }
    }

    private var settingsSection: some View {
        Section {
            if isGroupChat {
                LabeledContent {
                    TextField(
                        "",
                        text: chatNameBinding,
                        prompt: Text(fallbackChatTitle)
                    )
                    .textInputAutocapitalization(.words)
                } label: {
                    Label("Chat Name", systemImage: "character.bubble")
                }
            }

            LabeledContent {
                Button {
                    isThemePickerPresented = true
                } label: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(resolvedThemeColor)
                        .frame(width: 34, height: 34)
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                        }
                        .accessibilityLabel("Current chat color")
                }
                .buttonStyle(.plain)
            } label: {
                Label("Color", systemImage: "paintpalette")
            }

            Toggle(isOn: hideAlertsBinding) {
                Label("Hide alerts", systemImage: "bell.slash")
            }

        } header: {
            Text("Settings")
        }
    }

    private var destructiveSection: some View {
        Section {
            Button(role: .destructive, action: handleDestructiveAction) {
                Text(isGroupChat ? "Leave Group" : "Delete Chat")
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func close() {
        withAnimation(.easeInOut(duration: 0.25)) {
            chatData.dismissDetail(for: chat.id)
        }
    }

    private func handleDestructiveAction() {
        close()
        onDestructiveAction()
    }
}
