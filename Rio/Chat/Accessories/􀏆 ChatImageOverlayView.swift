//
//  􀏆 ChatImageOverlayView.swift
//  Rio
//
//  Created by ChatGPT on 10/29/25.
//

import SwiftUI

struct ChatImageOverlayView: View {
    @Binding var selectedImageData: ImageData?

    var body: some View {
        if let imageData = selectedImageData {
            ImageDetailView(
                imageData: imageData,
                isPresented: Binding(
                    get: { selectedImageData != nil },
                    set: { newValue in
                        if !newValue {
                            selectedImageData = nil
                        }
                    }
                )
            )
            .zIndex(1)
        }
    }
}
