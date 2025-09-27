//
//  ChatInputView.swift
//  Rio
//
//  Created by Edward Sanchez on 9/27/25.
//

import SwiftUI

struct ChatInputView: View {
    @State private var message: String = ""
    @FocusState private var isMessageFieldFocused: Bool
    @Binding var inputFieldFrame: CGRect
    @Binding var inputFieldHeight: CGFloat
    @State private var keyboardIsUp = false
    @Binding var shouldFocus: Bool

    let onSendMessage: (String) -> Void
    
    var body: some View {
        inputField
            .onChange(of: shouldFocus) { _, newValue in
                if newValue {
                    isMessageFieldFocused = true
                    shouldFocus = false
                }
            }
    }
    
    var inputField: some View {
        HStack {
            HStack(alignment: .bottom) {
                TextField("Message", text: $message, axis: .vertical)
                    .lineLimit(1...5) // Allow 1 to 5 lines
                    .padding([.vertical, .leading], 15)
                    .background {
                        Color.clear
                            .onGeometryChange(for: CGRect.self) { proxy in
                                proxy.frame(in: .global)
                            } action: { newValue in
                                inputFieldFrame = newValue
                                // Update input field height for dynamic spacing
                                inputFieldHeight = newValue.height
                            }
                    }
                    .focused($isMessageFieldFocused)
                    .onSubmit {
                        sendMessage()
                    }
                    .submitLabel(.send)

                sendButton
                    .padding(.bottom, 5)
            }
            .glassEffect(.clear.tint(.white.opacity(0.5)).interactive(), in: .rect(cornerRadius: 25))
        }
        .padding(.horizontal, 30)
        .padding(.top, 15)
        .background(alignment: .bottom) {
            Rectangle()
                .fill(Gradient(colors: [.base.opacity(0), .base.opacity(1)]))
                .ignoresSafeArea()
                .frame(height: 170)
                .offset(y: 120)
        }
        .safeAreaPadding(.bottom, keyboardIsUp ? nil : 0)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .animation(.smooth(duration: 0.2), value: inputFieldHeight)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                withAnimation {
                    keyboardIsUp = keyboardFrame.height > 0
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation {
                keyboardIsUp = false
            }
        }
        .background {
            Rectangle()
                .fill(Gradient(colors: [.base.opacity(0), .base.opacity(1)]))
                .ignoresSafeArea()
                .frame(height: 100)
                .offset(y: 30)
        }
    }
    
    var isEmpty: Bool {
        message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var sendButton: some View { //TODO: Toby: Reduce button size
        Button {
            sendMessage()
        } label: {
            Image(systemName: "arrow.up")
                .padding(5)
                .fontWeight(.bold)
        }
        .buttonBorderShape(.circle)
        .buttonStyle(.borderedProminent)
        .opacity(isEmpty ? 0 : 1)
        .scaleEffect(isEmpty ? 0.9  : 1)
        .animation(.smooth(duration: 0.2), value: isEmpty)
    }



    private func sendMessage() {
        // Capture the message text before clearing to avoid race conditions
        let messageText = message.trimmingCharacters(in: .whitespacesAndNewlines)

        // Guard against empty messages
        guard !messageText.isEmpty else { return }

        // Clear the text field immediately to provide instant feedback
        message = ""

        // Call the parent's send message handler with the text
        onSendMessage(messageText)

        // Restore focus after a brief delay to ensure text clearing completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isMessageFieldFocused = true
        }
    }
}

#Preview {
    @Previewable @State var inputFieldFrame: CGRect = .zero
    @Previewable @State var inputFieldHeight: CGFloat = 50
    @Previewable @State var shouldFocus = false

    return ChatInputView(
        inputFieldFrame: $inputFieldFrame,
        inputFieldHeight: $inputFieldHeight,
        shouldFocus: $shouldFocus,
        onSendMessage: { messageText in
            print("Send message: \(messageText)")
        }
    )
    .background(Color.base)
}
