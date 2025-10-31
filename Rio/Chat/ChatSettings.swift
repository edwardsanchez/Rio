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
    @State private var participantShowingActions: User?
    @State private var participantPendingRemoval: User?
    @State private var isRemoveParticipantAlertPresented = false

    private var isPresented: Bool {
        chatData.isDetailPresented(for: chat.id)
    }

    private var isGroupChat: Bool {
        chat.participants.count > 2
    }

    private var participantGridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 50, maximum: 100), spacing: 20, alignment: .leading)]
    }

    private var participantsExcludingCurrentUser: [User] {
        chat.participants.filter { $0.id != chatData.currentUser.id }
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
                    settingsSection
                    destructiveSection
                }
                .padding(.top, -20)
                .scrollContentBackground(.hidden)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(Color(.systemGroupedBackground))
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
                .opacity
            )
        }
    }

    private var participantsList: some View {
        VStack {
            LazyVGrid(columns: participantGridColumns, spacing: 16) {
                ForEach(participantsExcludingCurrentUser) { participant in
                    participantTile(for: participant)
                }

                addParticipantButton
            }
            .padding(.bottom, 20)

            Text("Settings")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, 30)
        .padding(.horizontal, 20)
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
            participantsList
        } footer: {
            EmptyView()
        }

//        Section {
//
//        } header: {
//            Text("Settings")
//        }
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

        chatNameSelection = TextSelection(range: currentText.startIndex ..< currentText.endIndex)
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

    @ViewBuilder
    private func participantTile(for participant: User) -> some View {
        if isGroupChat {
            participantTileContent(for: participant)
        } else {
            participantTileContent(for: participant)
        }
    }

    private func participantTileContent(for participant: User) -> some View {
        VStack(spacing: 3) {
            Button {
                participantShowingActions = participant
            } label: {
                AvatarView(
                    user: participant,
                    namespace: avatarNamespace,
                    matchedGeometryID: chat.avatarGeometryKey(for: participant),
                    isGeometrySource: true,
                    matchedGeometryAnimation: avatarTransitionAnimation
                )
                .glassEffect(.regular.interactive(), in: .circle)
            }
            .buttonStyle(.plain)
            .confirmationDialog(
                participant.name,
                isPresented: actionsDialogBinding(for: participant),
                titleVisibility: .hidden
            ) {
                Button(role: .destructive) {
                    participantPendingRemoval = participant
                    isRemoveParticipantAlertPresented = true
                    participantShowingActions = nil
                } label: {
                    Label("Remove from Group", systemImage: "xmark")
                }

                Button {
                    //TODO: Implement - only have this if there is more than 2 participants including you
                } label: {
                    Label("Chat 1:1", systemImage: "person.2")
                }
            }
            .alert(
                "Remove from Group?",
                isPresented: alertBinding(for: participant),
                presenting: participantPendingRemoval
            ) { participant in
                Button("Remove", role: .destructive) {
                    removeParticipant(participant)
                    isRemoveParticipantAlertPresented = false
                    participantPendingRemoval = nil
                }

                Button("Cancel", role: .cancel) {
                    isRemoveParticipantAlertPresented = false
                    participantPendingRemoval = nil
                }
            } message: { participant in
                Text("Are you sure you want to remove \(participant.name) from this chat?")
            }

            Text(participant.name)
                .font(.caption)
                .multilineTextAlignment(.center)
                .lineLimit(2, reservesSpace: true)
                .truncationMode(.tail)
        }
    }

    private func removeParticipant(_ participant: User) {
        chatData.removeParticipant(participant, from: chat.id)
    }

    private func alertBinding(for participant: User) -> Binding<Bool> {
        Binding(
            get: {
                isRemoveParticipantAlertPresented && participantPendingRemoval?.id == participant.id
            },
            set: { newValue in
                if !newValue, participantPendingRemoval?.id == participant.id {
                    isRemoveParticipantAlertPresented = false
                    participantPendingRemoval = nil
                } else {
                    isRemoveParticipantAlertPresented = newValue
                }
            }
        )
    }

    private func actionsDialogBinding(for participant: User) -> Binding<Bool> {
        Binding(
            get: {
                participantShowingActions?.id == participant.id
            },
            set: { newValue in
                if !newValue, participantShowingActions?.id == participant.id {
                    participantShowingActions = nil
                } else if newValue {
                    participantShowingActions = participant
                }
            }
        )
    }
}

private struct ChatSettingsPreviewHost: View {
    let chatData: ChatData
    let chat: Chat

    @Namespace private var avatarNamespace

    var body: some View {
        ChatSettings(
            chat: chat,
            fallbackChatTitle: Chat.fallbackTitle(
                for: chat.participants,
                currentUser: chatData.currentUser
            ),
            avatarNamespace: avatarNamespace,
            avatarTransitionAnimation: .smooth(duration: 0.28),
            onDestructiveAction: {}
        )
        .environment(chatData)
    }
}

#Preview("Group Chat Settings") {
    @Previewable @State var chatData = ChatData()

    let sampleUsers = chatData.sampleUsers
    let currentUser = sampleUsers.edward
    let groupParticipants = [currentUser, sampleUsers.sophia, sampleUsers.liam, sampleUsers.zoe]

    let previewChat = Chat(
        title: "Weekend Plans",
        participants: groupParticipants,
        messages: [],
        theme: .theme2,
        currentUser: currentUser
    )

    chatData.chats = [previewChat]
    chatData.presentDetail(for: previewChat.id)

    let storedChat = chatData.chats.first ?? previewChat

    return ChatSettingsPreviewHost(
        chatData: chatData,
        chat: storedChat
    )
    .background(Color.red)
}
