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
    let isGroupChat: Bool
    let avatarNamespace: Namespace.ID
    let avatarTransitionAnimation: Animation
    let hideAlertsBinding: Binding<Bool>
    let chatNameBinding: Binding<String>
    let onClose: () -> Void
    let onDestructiveAction: () -> Void

    private var participantGridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 60, maximum: 100), spacing: 20, alignment: .leading)]
    }

    var body: some View {
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
                    Button(action: onClose) {
                        Label("Close", systemImage: "xmark")
                    }
                    .tint(.primary)
                    .buttonBorderShape(.circle)
                }
            }
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
                    // TODO: Present color picker sheet for outbound bubble color
                } label: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(chat.theme.outboundBackgroundColor)
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
            Button(role: .destructive, action: onDestructiveAction) {
                Text(isGroupChat ? "Leave Group" : "Delete Chat")
                    .frame(maxWidth: .infinity)
            }
        }
    }
}
