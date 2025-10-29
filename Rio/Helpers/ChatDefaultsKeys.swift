//
//  ChatDefaultsKeys.swift
//  Rio
//
//  Created by ChatGPT on 10/29/25.
//

import Foundation
import Defaults

extension Defaults.Keys {
    static let mutedChatIDs = Key<[UUID]>("mutedChatIDs", default: [])
}
