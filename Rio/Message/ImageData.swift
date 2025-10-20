//
//  ImageData.swift
//  Rio
//
//  Created by Edward Sanchez on 10/18/25.
//

import SwiftUI

/// A data model for passing image information to FlowLink for zoom transitions
struct ImageData: Hashable, Equatable {
    let id: String  // Changed from UUID to String for stable IDs
    let image: Image
    let label: String?
    
    init(id: String = UUID().uuidString, image: Image, label: String? = nil) {
        self.id = id
        self.image = image
        self.label = label
    }
    
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(label)
    }
    
    // Equatable conformance
    static func == (lhs: ImageData, rhs: ImageData) -> Bool {
        lhs.id == rhs.id && lhs.label == rhs.label
    }
}
