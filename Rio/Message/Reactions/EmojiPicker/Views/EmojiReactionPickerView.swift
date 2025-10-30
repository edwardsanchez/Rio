//
//  EmojiReactionPickerView.swift
//  EmojiPicker
//
//  Created by Edward Sanchez on 10/23/25.
//

import SwiftUI

struct EmojiReactionPickerView: View {
    @State private var viewModel = EmojiReactionViewModel()
    @FocusState private var isInputFocused: Bool
    @State private var textSelection: TextSelection?
    @State private var conversationText: String = ""
    @State private var lastMessage: String = ""

    var body: some View {
        VStack(spacing: 24) {
            // Provider toggle
            Picker("Provider", selection: $viewModel.provider) {
                ForEach(EmojiProvider.allCases) { provider in
                    Text(provider.rawValue).tag(provider)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .onChange(of: viewModel.provider) { _, _ in
                // Re-run with the latest inputs if available
                let message = lastMessage.isEmpty ? viewModel.inputText : lastMessage
                guard !message.isEmpty else { return }
                Task {
                    await viewModel.findEmojis(
                        for: message,
                        context: conversationText.isEmpty ? nil : conversationText
                    )
                }
            }

            // Title
            Text("AI Emoji Reaction Picker")
                .font(.title)
                .fontWeight(.bold)

            // Fast/OpenAI toggle above

            // Preset conversations
            VStack(alignment: .leading, spacing: 12) {
                Text("Test conversations")
                    .font(.headline)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    Button(action: {
                        let transcript = """
                        Alex: Hey! Maya is throwing a birthday party this Saturday. Want to go together?
                        You: That could be fun—who else is going?
                        Alex: A bunch of our college friends. Starts at 7.
                        You: Nice, I’ll grab a card on the way.
                        Alex: Ok awesome!
                        """.trimmingCharacters(in: .whitespacesAndNewlines)
                        conversationText = transcript
                        lastMessage = "Yes"
                        Task { await viewModel.findEmojis(for: lastMessage, context: conversationText) }
                    }) {
                        Text("Party invite → Yes")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button(action: {
                        let transcript = """
                        Alex: I just heard about your uncle. I’m so sorry.
                        You: Thanks… it’s been a hard week.
                        Alex: Do you want to go to the funeral together?
                        """.trimmingCharacters(in: .whitespacesAndNewlines)
                        conversationText = transcript
                        lastMessage = "Yes"
                        Task { await viewModel.findEmojis(for: lastMessage, context: conversationText) }
                    }) {
                        Text("Funeral support → Yes")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button(action: {
                        let transcript = """
                        PM: I pushed the latest brief into the shared folder.
                        You: Got it—reviewing now.
                        PM: Can you send the draft by EOD if possible?
                        """.trimmingCharacters(in: .whitespacesAndNewlines)
                        conversationText = transcript
                        lastMessage = "Sounds good"
                        Task { await viewModel.findEmojis(for: lastMessage, context: conversationText) }
                    }) {
                        Text("Project update → Sounds good")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button(action: {
                        let transcript = """
                        Partner: Can we talk about splitting chores more evenly?
                        You: I’ve been swamped lately, but I hear you.
                        Partner: Could you handle dishes tonight and laundry tomorrow?
                        """.trimmingCharacters(in: .whitespacesAndNewlines)
                        conversationText = transcript
                        lastMessage = "Fine"
                        Task { await viewModel.findEmojis(for: lastMessage, context: conversationText) }
                    }) {
                        Text("Tough conversation → Fine")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.horizontal)

            // Input field
            VStack(alignment: .leading, spacing: 8) {
                Text("Enter your message:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextField(
                    "e.g., Let's go to Cancun",
                    text: $viewModel.inputText,
                    selection: $textSelection
                )
                .textFieldStyle(.roundedBorder)
                .focused($isInputFocused)
                .onSubmit {
                    Task {
                        await viewModel.findEmojis(
                            for: viewModel.inputText,
                            context: conversationText.isEmpty ? nil : conversationText
                        )
                    }
                }
                .disabled(viewModel.isLoading)

                Text("Press Return to find emoji reactions")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal)

            // Loading indicator
            if viewModel.isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Finding the perfect emoji...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }

            // Error message
            if let errorMessage = viewModel.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
            }

            // Compact results under buttons
            if !viewModel.finalists.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Emoji reactions")
                        .font(.headline)
                        .padding(.horizontal)
                    HStack(spacing: 12) {
                        ForEach(viewModel.finalists) { emoji in
                            Text(emoji.character)
                                .font(.system(size: 25))
                                .padding(8)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)
                }
            }

            // Conversation transcript
            if !conversationText.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Conversation context")
                        .font(.headline)
                        .padding(.horizontal)
                    ScrollView {
                        Text(conversationText)
                            .font(.caption)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                    .frame(maxHeight: 200)
                    .background(Color.gray.opacity(0.06))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }
            }

            Spacer()
        }
        .padding()
        .frame(maxWidth: 600)
    }

    private func selectAllText(isFocused: Bool) {
        guard isFocused else {
            textSelection = nil
            return
        }

        guard !viewModel.inputText.isEmpty else {
            textSelection = nil
            return
        }

        let range = viewModel.inputText.startIndex ..< viewModel.inputText.endIndex
        DispatchQueue.main.async {
            textSelection = TextSelection(range: range)
        }
    }
}

struct EmojiResultCard: View {
    let emoji: Emoji

    var body: some View {
        VStack(spacing: 8) {
            Text(emoji.character)
                .font(.system(size: 60))

            Text(emoji.name)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(height: 32)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

#Preview {
    EmojiReactionPickerView()
}
