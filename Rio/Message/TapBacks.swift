//
//  TapBacks.swift
//  Rio
//
//  Created by Edward Sanchez on 10/20/25.
//

import SwiftUI

/// Custom layout that positions items in a circular arrangement around a center point
struct RadialLayout: Layout {
    var radius: CGFloat
    var menuIsShowing: Bool
    var itemCount: Int
    var itemSpacing: CGFloat
    var spacerCenterPercent: CGFloat
    
    /// Calculated spacer percentage based on item count and spacing
    private var spacerPercentage: CGFloat {
        let circumference = 2 * .pi * radius
        let totalItemSpacing = CGFloat(itemCount) * itemSpacing
        let spacerArc = max(0, circumference - totalItemSpacing)
        return min(0.9, max(0, spacerArc / circumference)) // Clamp between 0 and 0.9
    }

    init(
        radius: CGFloat = 100,
        menuIsShowing: Bool = false,
        itemCount: Int = 6,
        itemSpacing: CGFloat = 100,
        spacerCenterPercent: CGFloat = 0.5
    ) {
        self.radius = radius
        self.menuIsShowing = menuIsShowing
        self.itemCount = itemCount
        self.itemSpacing = itemSpacing
        self.spacerCenterPercent = spacerCenterPercent
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        // Container size needs to accommodate the full circle plus item sizes
        return CGSize(width: radius * 2, height: radius * 2)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let count = subviews.count
        guard count > 0 else { return }

        let center = CGPoint(x: bounds.midX, y: bounds.midY)

        // Calculate available arc (360 degrees minus the spacer)
        let availableArc = 360.0 * (1.0 - spacerPercentage)
        
        // Calculate the angle increment between items
        let angleIncrement = availableArc / CGFloat(count)
        
        // Calculate starting angle
        // Convert spacerCenterPercent to degrees (0% = top = -90°, going clockwise)
        let spacerCenterAngle = (spacerCenterPercent * 360.0) - 90.0
        let spacerArc = 360.0 * spacerPercentage
        // Start at the end of the spacer, plus half an increment to center the first item
        let arcStartAngle = spacerCenterAngle + (spacerArc / 2.0)
        let startAngle = arcStartAngle + (angleIncrement / 2.0)

        for (index, subview) in subviews.enumerated() {
            // Calculate angle for this item within the available arc
            let angle = startAngle + (CGFloat(index) * angleIncrement)
            let radians = angle * .pi / 180.0

            // Calculate position using polar coordinates
            // When menu is hidden, all items are at center; when shown, they move to their positions
            let currentRadius = menuIsShowing ? radius : 0
            let x = center.x + currentRadius * cos(radians)
            let y = center.y + currentRadius * sin(radians)

            // Place the subview at the calculated position
            subview.place(at: CGPoint(x: x, y: y), anchor: .center, proposal: .unspecified)
        }
    }
}

struct TapBacksModifier: ViewModifier {
    @State private var menuIsShowing = true
    @State private var viewSize: CGSize = .zero
    @State private var viewFrame: CGRect = .zero
    @State private var tapLocation: CGPoint = .zero
    @State private var screenWidth: CGFloat = 0
    
    var messageID: UUID
    var reactions: [String]
    var onReactionSelected: (String) -> Void
    
    // MARK: - Layout Decision Logic
    
    private enum LayoutMode {
        case smallSide    // Small view, compact menu to the side
        case largeTopArc  // Wide/medium view, shallow arc above
        case tallSideArc  // Tall skinny view, vertical arc on side
    }
    
    private var layoutMode: LayoutMode {
        // Small enough for side placement
        if viewSize.height < 100 && viewSize.width < 100 {
            return .smallSide
        }
        
        // Very tall and skinny -> side arc
        if viewSize.height > 200 && viewSize.width < 200 {
            return .tallSideArc
        }
        
        // Default to top arc for medium/wide views
        return .largeTopArc
    }
    
    private var calculatedRadius: CGFloat {
        switch layoutMode {
        case .smallSide:
            return 90
        case .largeTopArc:
            return max(400, viewSize.height * 1.5)
        case .tallSideArc:
            return max(300, viewSize.height * 0.8)
        }
    }
    
    private var calculatedSpacerCenterPercent: CGFloat {
        switch layoutMode {
        case .smallSide:
            return 0.75  // Spacer on left, items on right side
        case .largeTopArc:
            return 0.5   // Spacer on bottom, items arc above
        case .tallSideArc:
            return 0.75  // Spacer on left, items arc vertically on right side
        }
    }
    
    private var calculatedOffset: CGSize {
        let radius = calculatedRadius
        
        switch layoutMode {
        case .smallSide:
            // Position to the right of the view
            let offsetX = viewSize.width / 2// + radius
            let offsetY: CGFloat = 0
            return CGSize(width: offsetX, height: offsetY)
            
        case .largeTopArc:
            // Center horizontally at tap location
            // Position circle so top arc appears just above the view
            let offsetX = tapLocation.x - viewSize.width / 2
            // Circle center should be positioned so items at -radius are just above view top
            // View top is at -viewSize.height/2, we want items about 30-40px above that
            let offsetY = radius - viewSize.height / 2 - 80
            return CGSize(width: offsetX, height: offsetY)
            
        case .tallSideArc:
            // Position to the right of the view
            let offsetX = viewSize.width / 2 + radius * 0.7
            let offsetY: CGFloat = 0
            return CGSize(width: offsetX, height: offsetY)
        }
    }

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGSize.self) { proxy in
                proxy.size
            } action: { newSize in
                viewSize = newSize
            }
            .onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .global)
            } action: { newFrame in
                viewFrame = newFrame
            }
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { width in
                screenWidth = width
            }
            .background(
                RadialLayout(
                    radius: calculatedRadius,
                    menuIsShowing: menuIsShowing,
                    itemCount: reactions.count,
                    itemSpacing: 50,
                    spacerCenterPercent: calculatedSpacerCenterPercent
                ) {
                    GlassEffectContainer {
                        ForEach(Array(reactions.enumerated()), id: \.offset) { index, emoji in
                            Button {
                                onReactionSelected(emoji)
                                menuIsShowing = false
                            } label: {
                                Circle()
                                    .fill(.clear)
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Text(emoji)
                                            .font(.system(size: 24))
                                            .opacity(menuIsShowing ? 1 : 0)
                                    )

                            }
                            .glassEffect(menuIsShowing ? .regular : .clear, in: .circle)
                            .animation(
                                .spring(duration: 0.4, bounce: 0.5)
                                .delay(Double(index) * 0.05),
                                value: menuIsShowing
                            )
                        }
                    }
                }
                .offset(calculatedOffset)
                .animation(.spring(duration: 0.4, bounce: 0.5), value: menuIsShowing)
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        tapLocation = value.location
                        menuIsShowing.toggle()
                    }
            )
    }
}

extension View {
    func tapBacks(
        messageID: UUID,
        reactions: [String] = ["❤️", "👍", "😂", "😮", "😢", "🔥"],
        onReactionSelected: @escaping (String) -> Void = { reaction in
            print("Selected reaction: \(reaction)")
        }
    ) -> some View {
        modifier(
            TapBacksModifier(
                messageID: messageID,
                reactions: reactions,
                onReactionSelected: onReactionSelected
            )
        )
    }
}

struct TapBackTestView: View {
    var body: some View {
        VStack(spacing: 60) {
            // Small rectangle - should show compact side menu
//            VStack(alignment: .leading, spacing: 8) {
//                Text("Small View (50×40)")
//                    .font(.caption)
//                    .foregroundStyle(.secondary)
//                
//                RoundedRectangle(cornerRadius: 10)
//                    .fill(.blue)
//                    .frame(width: 50, height: 40)
//                    .containerShape(.rect)
//                    .glassEffect(.regular.interactive(), in: .rect)
//                    .tapBacks(messageID: UUID()) { reaction in
//                        print("Small tapped: \(reaction)")
//                    }
//            }
//            .frame(maxWidth: .infinity, alignment: .leading)
//            .padding(.horizontal)
            
            // Wide rectangle - should show top arc with large radius
            VStack(alignment: .leading, spacing: 8) {
                Text("Wide View (300×150)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                RoundedRectangle(cornerRadius: 10)
                    .fill(.green)
                    .frame(width: 300, height: 50)
                    .containerShape(.rect)
                    .glassEffect(.regular.interactive(), in: .rect)
                    .tapBacks(messageID: UUID()) { reaction in
                        print("Wide tapped: \(reaction)")
                    }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            
//            // Tall rectangle - should show vertical side arc
//            VStack(alignment: .leading, spacing: 8) {
//                Text("Tall View (150×400)")
//                    .font(.caption)
//                    .foregroundStyle(.secondary)
//                
//                RoundedRectangle(cornerRadius: 10)
//                    .fill(.orange)
//                    .frame(width: 50, height: 200)
//                    .containerShape(.rect)
//                    .glassEffect(.regular.interactive(), in: .rect)
//                    .tapBacks(messageID: UUID()) { reaction in
//                        print("Tall tapped: \(reaction)")
//                    }
//            }
//            .frame(maxWidth: .infinity, alignment: .leading)
//            .padding(.horizontal)
        }
        .frame(maxHeight: .infinity)
        .scaleEffect(0.2)
    }
}

#Preview {
    TapBackTestView()
}
