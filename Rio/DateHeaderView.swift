//
//  DateHeaderView.swift
//  Rio
//
//  Created by Edward Sanchez on 10/8/25.
//

import SwiftUI

struct DateHeaderView: View {
    var date: Date
    let scrollVelocity: CGFloat
    let scrollPhase: ScrollPhase
    let visibleMessageIndex: Int
    
    @Environment(BubbleConfiguration.self) private var bubbleConfig
    
    init(date: Date, scrollVelocity: CGFloat = 0, scrollPhase: ScrollPhase = .idle, visibleMessageIndex: Int = 0) {
        self.date = date
        self.scrollVelocity = scrollVelocity
        self.scrollPhase = scrollPhase
        self.visibleMessageIndex = visibleMessageIndex
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.doesRelativeDateFormatting = true
        return formatter
    }
    
    private var parallaxOffset: CGFloat {
        bubbleConfig.calculateParallaxOffset(
            scrollVelocity: scrollVelocity,
            scrollPhase: scrollPhase,
            visibleMessageIndex: visibleMessageIndex,
            isNewMessage: false
        )
    }
    
    var body: some View {
        Text(dateFormatter.string(from: date))
            .font(.caption)
            .foregroundColor(.secondary)
            .offset(y: parallaxOffset)
            .animation(.interactiveSpring, value: parallaxOffset)
    }
}
