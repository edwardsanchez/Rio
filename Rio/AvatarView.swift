//
//  AvatarView.swift
//  Rio
//
//  Created by Edward Sanchez on 10/24/25.
//

import SwiftUI

struct AvatarView: View {
    let user: User
    let namespace: Namespace.ID?
    let matchedGeometryID: AnyHashable?
    let isGeometrySource: Bool
    let matchedGeometryAnimation: Animation?
    @State private var renderedDiameter: CGFloat = .zero

    init(
        user: User,
        namespace: Namespace.ID? = nil,
        matchedGeometryID: AnyHashable? = nil,
        isGeometrySource: Bool = true,
        matchedGeometryAnimation: Animation? = nil
    ) {
        self.user = user
        self.namespace = namespace
        self.matchedGeometryID = matchedGeometryID
        self.isGeometrySource = isGeometrySource
        self.matchedGeometryAnimation = matchedGeometryAnimation
    }

    var body: some View {
        Group {
            if let namespace {
                avatarBase
                    .transaction { transaction in
                        if let matchedGeometryAnimation {
                            transaction.animation = matchedGeometryAnimation
                        }
                    }
                    .matchedGeometryEffect(
                        id: resolvedMatchedGeometryID,
                        in: namespace,
                        properties: .frame,
                        anchor: .center,
                        isSource: isGeometrySource
                    )
            } else {
                avatarBase
            }
        }
    }

    private var avatarBase: some View {
        Group {
            if let avatar = user.avatar {
                Image(avatar)
                    .resizable()
                    .scaledToFill()
            } else {
                Circle()
                    .fill(Color.secondary.opacity(0.15))
                    .overlay {
                        Text(initials(for: user))
                            .font(.system(size: renderedDiameter * 0.42, weight: .medium))
                            .minimumScaleFactor(0.4)
                            .lineLimit(1)
                            .allowsTightening(true)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.size.width
                    } action: { newDiameter in
                        renderedDiameter = newDiameter
                    }
            }
        }
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .accessibilityLabel(user.name)
    }

    private var resolvedMatchedGeometryID: AnyHashable {
        matchedGeometryID ?? AnyHashable(user.id)
    }

    private func initials(for user: User) -> String {
        guard let firstCharacter = user.name.trimmingCharacters(in: .whitespacesAndNewlines).first else {
            return "?"
        }

        return String(firstCharacter).uppercased()
    }
}

#Preview("Placeholder") {
    AvatarView(
        user: User(
            id: UUID(),
            name: "Luna Park",
            avatar: nil
        )
    )
    .padding(12)
}

#Preview("With Avatar") {
    AvatarView(
        user: User(
            id: UUID(),
            name: "Maya Maria Antonia",
            avatar: .amy
        )
    )
    .padding(12)
}
