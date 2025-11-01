//
//  ChatReaction.swift
//  Rio
//
//  Created by ChatGPT on 10/29/25.
//

import SwiftUI
import UIKit

struct ChatReaction: View {
    @Environment(ReactionsCoordinator.self) private var coordinator
    let bubbleNamespace: Namespace.ID
    @Binding var selectedImageData: ImageData?

    var body: some View {
        ZStack {
            if coordinator.isBackgroundDimmerVisible {
                scrimView
                    .onTapGesture {
                        coordinator.closeActiveMenu()
                    }
            }

            VStack {
                if let context = coordinator.reactingMessage {
                    let overlayContext = context.updatingOverlay(true)
                    Spacer()

                    overlayAlignedBubble(for: overlayContext)
                        .padding(.horizontal, 20)
                        .onAppear {
                            coordinator.promoteGeometrySourceToOverlay(for: context.message.id)
                        }
                        .onDisappear {
                            coordinator.resetGeometrySourceToList()
                        }
                }

                Spacer()

                if coordinator.isBackgroundDimmerVisible {
                    contextMenu
                        .transition(.move(edge: .bottom))
                } else {
                    contextMenu
                        .hidden()
                        .allowsHitTesting(false)
                }
            }
            .padding(.bottom, 20)
            .ignoresSafeArea()
            .animation(.smooth, value: coordinator.isBackgroundDimmerVisible)
        }
    }

    private var scrimView: some View {
        ZStack {
            Rectangle()
                .fill(Material.ultraThin)
            Rectangle()
                .fill(.base.opacity(0.7))
        }
        .ignoresSafeArea()
        .transition(
            .asymmetric(
                insertion: .opacity.animation(.easeIn),
                removal: .opacity.animation(.easeIn(duration: 0.4).delay(0.5))
            )
        )
    }

    private var contextMenu: some View {
        VStack(spacing: 30) {
            Button(action: copyActiveMessage) {
                Label("Copy", systemImage: "document.on.document")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(.rect)
            }

            //TODO: Need to implement save for inbound + outbound images and videos

            //TODO: For outbound, need to eventually implement Undo send
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 40)
        .buttonSizing(.flexible)
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: .containerRelative)
        .padding(.top, 60)
        .padding(.horizontal, 20)
        .contentShape(.rect)
    }

    private func copyActiveMessage() {
        guard let message = coordinator.reactingMessage?.message else { return }
        message.copyToClipboard()
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        coordinator.closeActiveMenu()
    }

    @ViewBuilder
    private func overlayAlignedBubble(for context: MessageBubbleContext) -> some View {
        if context.messageType.isOutbound {
            HStack {
                Spacer()
                bubbleView(for: context)
            }
        } else {
            HStack {
                bubbleView(for: context)
                Spacer()
            }
        }
    }

    private func bubbleView(for context: MessageBubbleContext) -> some View {
        MessageBubbleView(
            message: context.message,
            showTail: context.showTail,
            theme: context.theme,
            bubbleNamespace: bubbleNamespace,
            activeReactingMessageID: coordinator.reactingMessage?.message.id,
            geometrySource: coordinator.geometrySource,
            isReactionsOverlay: context.isReactionsOverlay,
            selectedImageData: $selectedImageData
        )
    }
}
