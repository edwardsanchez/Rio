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

    var body: some View {
        Group {
            if let avatar = user.avatar {
                Image(avatar)
                    .resizable()
                    .scaledToFill()
            } else {
                Circle()
                    .fill(Color.secondary.opacity(0.15))
                    .overlay(
                        Text(initials(for: user))
                            .font(.title.weight(.medium))
                            .foregroundStyle(.primary)
                    )
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
