//
//  AvatarView.swift
//  Rio
//
//  Created by Edward Sanchez on 10/24/25.
//

import SwiftUI

struct AvatarView: View {
    let user: User
    var avatarSize: CGFloat? = 80
    var isVertical: Bool = false
    @State private var renderedSize: CGSize = .zero

    var body: some View {
        Group {
            if let avatar = user.avatar {
                Image(avatar)
                    .resizable()
                    .scaledToFill()
            } else {
                Circle()
                    .fill(Color.secondary.opacity(0.15))
                    .overlay {
                        let diameter = max(1, min(renderedSize.width, renderedSize.height, avatarSize ?? 80))
                        Text(initials(for: user))
                            .font(.system(size: diameter * 0.42, weight: .medium))
                            .minimumScaleFactor(0.4)
                            .lineLimit(1)
                            .allowsTightening(true)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .onGeometryChange(for: CGSize.self) { proxy in
                        proxy.size
                    } action: { newSize in
                        renderedSize = newSize
                    }
            }
        }
        .frame(width: avatarSize, height: avatarSize)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .accessibilityLabel(user.name)
    }

    private func initials(for user: User) -> String {
        guard let firstCharacter = user.name.trimmingCharacters(in: .whitespacesAndNewlines).first else {
            return "?"
        }

        return String(firstCharacter).uppercased()
    }
}
