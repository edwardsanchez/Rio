//
//  ImageDetailView.swift
//  Rio
//
//  Created by Edward Sanchez on 10/18/25.
//

import SwiftUI
import FlowStack

/// A full-screen image detail view with zoom, pan, and interactive dismiss gestures
struct ImageDetailView: View {
    @Environment(\.flowDismiss) var flowDismiss
    @State private var opacity: CGFloat = 0
    @State private var safeAreaInsets: EdgeInsets = EdgeInsets()
    
    let imageData: ImageData
    
    var body: some View {
        ZStack {
            // Centered image
            imageData.image
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Overlay with buttons and label
            VStack(spacing: 0) {
                // Top bar with label and close button
                HStack(alignment: .top, spacing: 8) {
                    // Label for labeled images
                    if let label = imageData.label {
                        Text(label)
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                            .opacity(opacity)
                    }
                    
                    Spacer()
                    
                    // Close button
                    Button(action: {
                        flowDismiss()
                    }, label: {
                        Image(systemName: "xmark")
                            .padding(10)
                    })
                    .opacity(opacity)
                    .buttonBorderShape(.circle)
                    .buttonStyle(.glass)
                }
                .padding(.horizontal, 12)
                .padding(.top, safeAreaInsets.top + 12)
                
                Spacer()
                
                // Share button at bottom right
                HStack {
                    Spacer()
                    
                    Button(action: {
                        print("share")
                    }, label: {
                        Image(systemName: "square.and.arrow.up")
                            .padding(10)
                            
                    })
                    .opacity(opacity)
                    .buttonBorderShape(.circle)
                    .buttonStyle(.glass)
                    
                }
                .padding(.horizontal, 12)
                .padding(.bottom, safeAreaInsets.bottom)
            }
        }
        .ignoresSafeArea()
        .background(Color.black)
        .onGeometryChange(for: EdgeInsets.self) { proxy in
            proxy.safeAreaInsets
        } action: { newValue in
            safeAreaInsets = newValue
        }
        .withFlowAnimation {
            opacity = 1
        } onDismiss: {
            opacity = 0
        }
    }
}

#Preview {
    ImageDetailView(
        imageData: ImageData(
            image: Image(.cat),
            label: "A cute cat"
        )
    )
}

