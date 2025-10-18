//
//  URLPreviewCard.swift
//  Rio
//
//  Created by Edward Sanchez on 10/18/25.
//

import SwiftUI
import LinkPresentation

/// A view that displays a URL preview card using LinkPresentation framework
struct URLPreviewCard: View {
    let url: URL
    let textColor: Color
    
    @State private var metadata: LPLinkMetadata?
    @State private var isLoading = true
    @State private var hasFailed = false
    
    var body: some View {
        Group {
            if isLoading {
                loadingPlaceholder
            } else if let metadata = metadata, !hasFailed {
                LinkPreviewView(metadata: metadata)
            } else {
                fallbackView
            }
        }
        .onAppear {
            fetchMetadata()
        }
    }
    
    // Loading placeholder with redacted content
    private var loadingPlaceholder: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Placeholder for image
            Rectangle()
                .fill(Color.primary.opacity(0.5))
                .cornerRadius(8)
            
            // Placeholder for title
            Text("Lorem ipsum dolor sit amet")
                .font(.headline)
                .redacted(reason: .placeholder)
            
            // Placeholder for description
            Text("Consectetur adipiscing elit sed do eiusmod tempor incididunt")
                .font(.subheadline)
                .lineLimit(2)
                .redacted(reason: .placeholder)
        }
    }
    
    // Fallback view when metadata fetch fails
    private var fallbackView: some View {
        Text(url.absoluteString)
            .font(.caption)
            .foregroundStyle(textColor)
            .lineLimit(2)
            .truncationMode(.middle)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .onTapGesture {
                openURL()
            }
    }
    
    private func fetchMetadata() {
        let provider = LPMetadataProvider()
        provider.startFetchingMetadata(for: url) { fetchedMetadata, error in
            DispatchQueue.main.async {
                isLoading = false
                if let fetchedMetadata = fetchedMetadata, error == nil {
                    self.metadata = fetchedMetadata
                    self.hasFailed = false
                } else {
                    self.hasFailed = true
                }
            }
        }
    }
    
    private func openURL() {
        UIApplication.shared.open(url)
    }
}

/// UIViewRepresentable wrapper for LPLinkView
struct LinkPreviewView: UIViewRepresentable {
    let metadata: LPLinkMetadata
    
    func makeUIView(context: Context) -> LPLinkView {
        let linkView = LPLinkView(metadata: metadata)
        return linkView
    }
    
    func updateUIView(_ uiView: LPLinkView, context: Context) {
        uiView.metadata = metadata
    }
}

#Preview("URL Preview Card - Loaded") {
    VStack(spacing: 20) {
        URLPreviewCard(
            url: URL(string: "https://www.apple.com")!,
            textColor: .white
        )
        .padding()
        .background(Color.blue)
        .cornerRadius(12)
    }
    .padding()
}

#Preview("URL Preview Card - Loading") {
    VStack(alignment: .leading, spacing: 8) {
        // Placeholder for image
        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .frame(height: 160)
            .cornerRadius(8)
        
        // Placeholder for title
        Text("Lorem ipsum dolor sit amet")
            .font(.headline)
            .redacted(reason: .placeholder)
        
        // Placeholder for description
        Text("Consectetur adipiscing elit sed do eiusmod tempor incididunt")
            .font(.subheadline)
            .lineLimit(2)
            .redacted(reason: .placeholder)
    }
    .frame(maxWidth: 280)
    .padding(12)
    .padding()
}

#Preview("URL Preview Card - Fallback") {
    Text("https://www.example.com/very/long/url/path/that/should/truncate")
        .font(.caption)
        .foregroundStyle(Color.white)
        .lineLimit(2)
        .truncationMode(.middle)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .padding()
        .background(Color.blue)
        .cornerRadius(12)
        .padding()
}

