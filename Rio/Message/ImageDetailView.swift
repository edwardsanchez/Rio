//
//  ImageDetailView.swift
//  Rio
//
//  Created by Edward Sanchez on 10/18/25.
//

import SwiftUI

/// A full-screen image detail view with zoom, pan, and interactive dismiss gestures
struct ImageDetailView: View {
    let imageData: ImageData
    @Binding var isPresented: Bool
    
    @Environment(ImageGeometryTracker.self) private var geometryTracker
    
    @State private var opacity: CGFloat = 0
    @State private var safeAreaInsets: EdgeInsets = EdgeInsets()
    @State private var screenSize: CGSize = .zero
    
    // Presentation animation state
    @State private var isPresentingFullScreen: Bool = false
    
    // Pull-to-dismiss gesture state
    @GestureState private var dragOffset: CGSize = .zero
    @State private var backgroundOpacity: CGFloat = 1
    
    // Zoom and pan state
    @State private var currentZoom: CGFloat = 1.0
    @State private var totalZoom: CGFloat = 1.0
    @State private var panOffset: CGSize = .zero
    @State private var currentPanOffset: CGSize = .zero
    
    private var isZoomedOut: Bool {
        totalZoom <= 1.0
    }
    
    // Calculate the source geometry for animation
    private var sourceGeometry: ImageGeometry? {
        geometryTracker.geometry(for: imageData.id)
    }
    
    // Calculate screen center
    private var screenCenter: CGPoint {
        CGPoint(x: screenSize.width / 2, y: screenSize.height / 2)
    }
    
    // Calculate scale needed to match source size
    private var calculatedScale: CGFloat {
        guard let sourceGeometry = sourceGeometry else { return 1.0 }
        guard screenSize.width > 0 else { return 1.0 }
        return sourceGeometry.width / screenSize.width
    }
    
    // Calculate offset needed to match source position
    private var calculatedOffset: CGSize {
        guard let sourceGeometry = sourceGeometry else { return .zero }
        let dx = sourceGeometry.centerX - screenCenter.x
        let dy = sourceGeometry.centerY - screenCenter.y
        return CGSize(width: dx, height: dy)
    }
    
    // Interpolate corner radius during animation
    private var cornerRadius: CGFloat {
        isPresentingFullScreen ? 10 : 10
    }
    
    var body: some View {
        ZStack {
            Color.black
                .opacity(backgroundOpacity)
                .ignoresSafeArea()
            
            // Centered zoomable image with manual transforms
            imageData.image
                .resizable()
                .scaledToFit()
                .mask {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                }
                // Presentation animation (small → large, large → small)
                .scaleEffect(isPresentingFullScreen ? 1.0 : calculatedScale)
                .offset(
                    x: isPresentingFullScreen ? 0 : calculatedOffset.width,
                    y: isPresentingFullScreen ? 0 : calculatedOffset.height
                )
                // User zoom/pan transforms (applied after presentation)
                .scaleEffect(currentZoom * totalZoom)
                .offset(
                    x: panOffset.width + currentPanOffset.width,
                    y: panOffset.height + currentPanOffset.height + (isZoomedOut ? dragOffset.height : 0)
                )
                .gesture(isZoomedOut ? nil : panGesture)
                .gesture(zoomGesture)
                .onTapGesture(count: 2, perform: handleDoubleTap)
                .simultaneousGesture(isZoomedOut ? dismissGesture : nil)
            
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
                    
                    // Close button (top right)
                    Button(action: {
                        dismiss()
                    }, label: {
                        Image(systemName: "xmark")
                            .padding(10)
                    })
                    .opacity(opacity)
                    .buttonBorderShape(.circle)
                    .buttonStyle(.glass)
                }
                .padding(.horizontal, 20)
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
                .padding(.horizontal, 20)
                .padding(.bottom, safeAreaInsets.bottom)
            }
        }
        .ignoresSafeArea()
        .onGeometryChange(for: EdgeInsets.self) { proxy in
            proxy.safeAreaInsets
        } action: { newValue in
            safeAreaInsets = newValue
        }
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { newValue in
            screenSize = newValue
        }
        .onTapGesture {
            // Tap background to dismiss
            if isZoomedOut {
                dismiss()
            }
        }
        .task {
            // Small delay to ensure geometry is calculated
            try? await Task.sleep(for: .milliseconds(50))
            
            // Animate to full screen
            withAnimation(.smooth(duration: 0.4)) {
                isPresentingFullScreen = true
            }
            
            // Delay button fade until after zoom animation completes
            try? await Task.sleep(for: .seconds(0.4))
            withAnimation(.easeIn(duration: 0.2)) {
                opacity = 1
            }
        }
        .onChange(of: isPresented) { _, newValue in
            if !newValue {
                // Animate back to source position before dismissing
                withAnimation(.smooth(duration: 0.4)) {
                    isPresentingFullScreen = false
                    opacity = 0
                }
            }
        }
    }
    
    // Pull-to-dismiss gesture (only when zoomed out)
    private var dismissGesture: some Gesture {
        DragGesture()
            .updating($dragOffset) { value, state, _ in
                guard value.translation.height > 0 else { return }
                state = value.translation
            }
            .onChanged { value in
                guard value.translation.height > 0 else { return }
                let dragDistance = value.translation.height
                let progress = min(dragDistance / 200, 1)
                backgroundOpacity = 1 - progress
            }
            .onEnded { value in
                if value.translation.height > 200 {
                    dismiss()
                } else {
                    // Snap back
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        backgroundOpacity = 1
                    }
                }
            }
    }
    
    // Zoom gesture
    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                currentZoom = value
            }
            .onEnded { value in
                totalZoom *= value
                currentZoom = 1.0
                // Clamp between 1.0 and 3.0
                totalZoom = min(max(totalZoom, 1.0), 3.0)
                
                // Reset pan offset when zooming out to 1.0
                if totalZoom == 1.0 {
                    withAnimation(.spring()) {
                        panOffset = .zero
                        currentPanOffset = .zero
                    }
                }
            }
    }
    
    // Pan gesture (only when zoomed in)
    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                currentPanOffset = value.translation
            }
            .onEnded { value in
                panOffset.width += value.translation.width
                panOffset.height += value.translation.height
                currentPanOffset = .zero
            }
    }
    
    // Double-tap to zoom
    private func handleDoubleTap() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if totalZoom > 1.0 {
                totalZoom = 1.0
                panOffset = .zero
                currentPanOffset = .zero
            } else {
                totalZoom = 2.0
            }
        }
    }
    
    // Helper function to dismiss with animation
    private func dismiss() {
        // Reset zoom/pan state before dismissing
        totalZoom = 1.0
        panOffset = .zero
        currentPanOffset = .zero
        
        // Trigger the isPresented binding which will animate back
        isPresented = false
    }
}

#Preview {
    @Previewable @State var isPresented = true
    @Previewable @State var geometryTracker = ImageGeometryTracker()
    
    ImageDetailView(
        imageData: ImageData(
            image: Image(.cat),
            label: "A cute cat"
        ),
        isPresented: $isPresented
    )
    .environment(geometryTracker)
}

