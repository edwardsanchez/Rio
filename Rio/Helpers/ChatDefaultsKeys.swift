//
//  ChatDefaultsKeys.swift
//  Rio
//
//  Created by ChatGPT on 10/29/25.
//

import Defaults
import Foundation

extension Defaults.Keys {
    static let mutedChatIDs = Key<[UUID]>("mutedChatIDs", default: [])
    static let currentUser = Key<User?>("currentUser", default: nil)
}
