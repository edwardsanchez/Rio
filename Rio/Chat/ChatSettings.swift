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

    @FocusState private var isChatNameFieldFocused: Bool
    @State private var chatNameSelection: TextSelection?
    @State private var isThemePickerPresented = false
    @State private var isAddParticipantPresented = false

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
                            .multilineTextAlignment(.center)
                            .lineLimit(2, reservesSpace: true)
                            .truncationMode(.tail)
                    }
                    .contextMenu {
                        Button("Remove from Group") {
                            //TODO: Implement
                        }
                        //TODO: Implement this, this is a role destructive.
                        //Use the xmark icon for this

                        Button("Chat 1:1") {
                            //TODO: Implement
                        }
                        //TODO: Use person.2.fill icon
                    }
                }

                addParticipantButton
            }
            .padding(.vertical, 8)

        } header: {
            Text("Participants")
        }
    }

    private var addParticipantButton: some View {
        Button {
            // swiftlint:disable:next todo
            // TODO: Implement add participant flow
            isAddParticipantPresented = true
        } label: {
            VStack(spacing: 3) {
                Circle()
                    .fill(Color.secondary.opacity(0.15))
                    .overlay {
                        Image(systemName: "plus")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .overlay {
                        Circle()
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    }

                Text("Add")
                    .font(.caption)
                    .fixedSize()
                    .lineLimit(2, reservesSpace: true)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add participant")
        .sheet(isPresented: $isAddParticipantPresented) {
            AddParticipantSheetView {
                isAddParticipantPresented = false
            }
        }
    }

    private var settingsSection: some View {
        Section {
            if isGroupChat {
                LabeledContent {
                    TextField(
                        "",
                        text: chatNameBinding,
                        selection: $chatNameSelection,
                        prompt: Text(fallbackChatTitle)
                    )
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.words)
                    .focused($isChatNameFieldFocused)
                    .onChange(of: isChatNameFieldFocused) { _, isFocused in
                        if isFocused {
                            DispatchQueue.main.async {
                                selectEntireChatName()
                            }
                        } else {
                            chatNameSelection = nil
                        }
                    }
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

    private func selectEntireChatName() {
        let currentText = chatNameBinding.wrappedValue

        guard !currentText.isEmpty else {
            chatNameSelection = nil
            return
        }

        chatNameSelection = TextSelection(range: currentText.startIndex..<currentText.endIndex)
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
