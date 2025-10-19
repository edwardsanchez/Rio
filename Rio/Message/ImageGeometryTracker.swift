//
//  ImageGeometryTracker.swift
//  Rio
//
//  Created by Edward Sanchez on 10/19/25.
//

import SwiftUI

/// Stores the geometry information for an image
struct ImageGeometry {
    let centerX: CGFloat
    let centerY: CGFloat
    let width: CGFloat
    let height: CGFloat
    
    var center: CGPoint {
        CGPoint(x: centerX, y: centerY)
    }
    
    var size: CGSize {
        CGSize(width: width, height: height)
    }
}

/// Tracks the screen positions and sizes of images for smooth animations
@Observable
class ImageGeometryTracker {
    private(set) var geometries: [String: ImageGeometry] = [:]
    
    /// Updates the geometry for a given image ID
    func updateGeometry(for id: String, rect: CGRect) {
        geometries[id] = ImageGeometry(
            centerX: rect.midX,
            centerY: rect.midY,
            width: rect.width,
            height: rect.height
        )
    }
    
    /// Gets the geometry for a given image ID
    func geometry(for id: String) -> ImageGeometry? {
        geometries[id]
    }
    
    /// Removes geometry for a given image ID
    func removeGeometry(for id: String) {
        geometries.removeValue(forKey: id)
    }
}

