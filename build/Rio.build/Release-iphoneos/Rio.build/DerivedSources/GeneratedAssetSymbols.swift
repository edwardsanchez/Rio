import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(DeveloperToolsSupport)
import DeveloperToolsSupport
#endif

#if SWIFT_PACKAGE
private let resourceBundle = Foundation.Bundle.module
#else
private class ResourceBundleClass {}
private let resourceBundle = Foundation.Bundle(for: ResourceBundleClass.self)
#endif

// MARK: - Color Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ColorResource {

    /// The "AccentColor" asset catalog color resource.
    static let accent = DeveloperToolsSupport.ColorResource(name: "AccentColor", bundle: resourceBundle)

    /// The "Base" asset catalog color resource.
    static let base = DeveloperToolsSupport.ColorResource(name: "Base", bundle: resourceBundle)

    /// The "Theme2" asset catalog resource namespace.
    enum Theme2 {

        /// The "Theme2/inboundBubble" asset catalog color resource.
        static let inboundBubble = DeveloperToolsSupport.ColorResource(name: "Theme2/inboundBubble", bundle: resourceBundle)

        /// The "Theme2/outboundBubble" asset catalog color resource.
        static let outboundBubble = DeveloperToolsSupport.ColorResource(name: "Theme2/outboundBubble", bundle: resourceBundle)

    }

    /// The "Theme1" asset catalog resource namespace.
    enum Theme1 {

        /// The "Theme1/inboundBubble" asset catalog color resource.
        static let inboundBubble = DeveloperToolsSupport.ColorResource(name: "Theme1/inboundBubble", bundle: resourceBundle)

        /// The "Theme1/outboundBubble" asset catalog color resource.
        static let outboundBubble = DeveloperToolsSupport.ColorResource(name: "Theme1/outboundBubble", bundle: resourceBundle)

    }

    /// The "Default" asset catalog resource namespace.
    enum Default {

        /// The "Default/inboundBubble" asset catalog color resource.
        static let inboundBubble = DeveloperToolsSupport.ColorResource(name: "Default/inboundBubble", bundle: resourceBundle)

        /// The "Default/outboundBubble" asset catalog color resource.
        static let outboundBubble = DeveloperToolsSupport.ColorResource(name: "Default/outboundBubble", bundle: resourceBundle)

    }

    /// The "ownBubble" asset catalog color resource.
    static let ownBubble = DeveloperToolsSupport.ColorResource(name: "ownBubble", bundle: resourceBundle)

}

// MARK: - Image Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ImageResource {

    /// The "amy" asset catalog image resource.
    static let amy = DeveloperToolsSupport.ImageResource(name: "amy", bundle: resourceBundle)

    /// The "cartouche" asset catalog image resource.
    static let cartouche = DeveloperToolsSupport.ImageResource(name: "cartouche", bundle: resourceBundle)

    /// The "edward" asset catalog image resource.
    static let edward = DeveloperToolsSupport.ImageResource(name: "edward", bundle: resourceBundle)

    /// The "joaquin" asset catalog image resource.
    static let joaquin = DeveloperToolsSupport.ImageResource(name: "joaquin", bundle: resourceBundle)

    /// The "read" asset catalog image resource.
    static let read = DeveloperToolsSupport.ImageResource(name: "read", bundle: resourceBundle)

    /// The "scarlet" asset catalog image resource.
    static let scarlet = DeveloperToolsSupport.ImageResource(name: "scarlet", bundle: resourceBundle)

}

// MARK: - Color Symbol Extensions -

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSColor {

    /// The "AccentColor" asset catalog color.
    static var accent: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .accent)
#else
        .init()
#endif
    }

    /// The "Base" asset catalog color.
    static var base: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .base)
#else
        .init()
#endif
    }

    /// The "Theme2" asset catalog resource namespace.
    enum Theme2 {

        /// The "Theme2/inboundBubble" asset catalog color.
        static var inboundBubble: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
            .init(resource: .Theme2.inboundBubble)
#else
            .init()
#endif
        }

        /// The "Theme2/outboundBubble" asset catalog color.
        static var outboundBubble: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
            .init(resource: .Theme2.outboundBubble)
#else
            .init()
#endif
        }

    }

    /// The "Theme1" asset catalog resource namespace.
    enum Theme1 {

        /// The "Theme1/inboundBubble" asset catalog color.
        static var inboundBubble: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
            .init(resource: .Theme1.inboundBubble)
#else
            .init()
#endif
        }

        /// The "Theme1/outboundBubble" asset catalog color.
        static var outboundBubble: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
            .init(resource: .Theme1.outboundBubble)
#else
            .init()
#endif
        }

    }

    /// The "Default" asset catalog resource namespace.
    enum Default {

        /// The "Default/inboundBubble" asset catalog color.
        static var inboundBubble: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
            .init(resource: .Default.inboundBubble)
#else
            .init()
#endif
        }

        /// The "Default/outboundBubble" asset catalog color.
        static var outboundBubble: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
            .init(resource: .Default.outboundBubble)
#else
            .init()
#endif
        }

    }

    /// The "ownBubble" asset catalog color.
    static var ownBubble: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .ownBubble)
#else
        .init()
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

    /// The "AccentColor" asset catalog color.
    static var accent: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .accent)
#else
        .init()
#endif
    }

    /// The "Base" asset catalog color.
    static var base: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .base)
#else
        .init()
#endif
    }

    /// The "Theme2" asset catalog resource namespace.
    enum Theme2 {

        /// The "Theme2/inboundBubble" asset catalog color.
        static var inboundBubble: UIKit.UIColor {
#if !os(watchOS)
            .init(resource: .Theme2.inboundBubble)
#else
            .init()
#endif
        }

        /// The "Theme2/outboundBubble" asset catalog color.
        static var outboundBubble: UIKit.UIColor {
#if !os(watchOS)
            .init(resource: .Theme2.outboundBubble)
#else
            .init()
#endif
        }

    }

    /// The "Theme1" asset catalog resource namespace.
    enum Theme1 {

        /// The "Theme1/inboundBubble" asset catalog color.
        static var inboundBubble: UIKit.UIColor {
#if !os(watchOS)
            .init(resource: .Theme1.inboundBubble)
#else
            .init()
#endif
        }

        /// The "Theme1/outboundBubble" asset catalog color.
        static var outboundBubble: UIKit.UIColor {
#if !os(watchOS)
            .init(resource: .Theme1.outboundBubble)
#else
            .init()
#endif
        }

    }

    /// The "Default" asset catalog resource namespace.
    enum Default {

        /// The "Default/inboundBubble" asset catalog color.
        static var inboundBubble: UIKit.UIColor {
#if !os(watchOS)
            .init(resource: .Default.inboundBubble)
#else
            .init()
#endif
        }

        /// The "Default/outboundBubble" asset catalog color.
        static var outboundBubble: UIKit.UIColor {
#if !os(watchOS)
            .init(resource: .Default.outboundBubble)
#else
            .init()
#endif
        }

    }

    /// The "ownBubble" asset catalog color.
    static var ownBubble: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .ownBubble)
#else
        .init()
#endif
    }

}
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.Color {

    /// The "AccentColor" asset catalog color.
    static var accent: SwiftUI.Color { .init(.accent) }

    /// The "Base" asset catalog color.
    static var base: SwiftUI.Color { .init(.base) }

    /// The "Theme2" asset catalog resource namespace.
    enum Theme2 {

        /// The "Theme2/inboundBubble" asset catalog color.
        static var inboundBubble: SwiftUI.Color { .init(.Theme2.inboundBubble) }

        /// The "Theme2/outboundBubble" asset catalog color.
        static var outboundBubble: SwiftUI.Color { .init(.Theme2.outboundBubble) }

    }

    /// The "Theme1" asset catalog resource namespace.
    enum Theme1 {

        /// The "Theme1/inboundBubble" asset catalog color.
        static var inboundBubble: SwiftUI.Color { .init(.Theme1.inboundBubble) }

        /// The "Theme1/outboundBubble" asset catalog color.
        static var outboundBubble: SwiftUI.Color { .init(.Theme1.outboundBubble) }

    }

    /// The "Default" asset catalog resource namespace.
    enum Default {

        /// The "Default/inboundBubble" asset catalog color.
        static var inboundBubble: SwiftUI.Color { .init(.Default.inboundBubble) }

        /// The "Default/outboundBubble" asset catalog color.
        static var outboundBubble: SwiftUI.Color { .init(.Default.outboundBubble) }

    }

    /// The "ownBubble" asset catalog color.
    static var ownBubble: SwiftUI.Color { .init(.ownBubble) }

}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.ShapeStyle where Self == SwiftUI.Color {

    /// The "AccentColor" asset catalog color.
    static var accent: SwiftUI.Color { .init(.accent) }

    /// The "Base" asset catalog color.
    static var base: SwiftUI.Color { .init(.base) }

    /// The "ownBubble" asset catalog color.
    static var ownBubble: SwiftUI.Color { .init(.ownBubble) }

}
#endif

// MARK: - Image Symbol Extensions -

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSImage {

    /// The "amy" asset catalog image.
    static var amy: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .amy)
#else
        .init()
#endif
    }

    /// The "cartouche" asset catalog image.
    static var cartouche: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .cartouche)
#else
        .init()
#endif
    }

    /// The "edward" asset catalog image.
    static var edward: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .edward)
#else
        .init()
#endif
    }

    /// The "joaquin" asset catalog image.
    static var joaquin: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .joaquin)
#else
        .init()
#endif
    }

    /// The "read" asset catalog image.
    static var read: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .read)
#else
        .init()
#endif
    }

    /// The "scarlet" asset catalog image.
    static var scarlet: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .scarlet)
#else
        .init()
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

    /// The "amy" asset catalog image.
    static var amy: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .amy)
#else
        .init()
#endif
    }

    /// The "cartouche" asset catalog image.
    static var cartouche: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .cartouche)
#else
        .init()
#endif
    }

    /// The "edward" asset catalog image.
    static var edward: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .edward)
#else
        .init()
#endif
    }

    /// The "joaquin" asset catalog image.
    static var joaquin: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .joaquin)
#else
        .init()
#endif
    }

    /// The "read" asset catalog image.
    static var read: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .read)
#else
        .init()
#endif
    }

    /// The "scarlet" asset catalog image.
    static var scarlet: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .scarlet)
#else
        .init()
#endif
    }

}
#endif

// MARK: - Thinnable Asset Support -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@available(watchOS, unavailable)
extension DeveloperToolsSupport.ColorResource {

    private init?(thinnableName: Swift.String, bundle: Foundation.Bundle) {
#if canImport(AppKit) && os(macOS)
        if AppKit.NSColor(named: NSColor.Name(thinnableName), bundle: bundle) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#elseif canImport(UIKit) && !os(watchOS)
        if UIKit.UIColor(named: thinnableName, in: bundle, compatibleWith: nil) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSColor {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
#if !targetEnvironment(macCatalyst)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
#if !os(watchOS)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.Color {

    private init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
        if let resource = thinnableResource {
            self.init(resource)
        } else {
            return nil
        }
    }

}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.ShapeStyle where Self == SwiftUI.Color {

    private init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
        if let resource = thinnableResource {
            self.init(resource)
        } else {
            return nil
        }
    }

}
#endif

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@available(watchOS, unavailable)
extension DeveloperToolsSupport.ImageResource {

    private init?(thinnableName: Swift.String, bundle: Foundation.Bundle) {
#if canImport(AppKit) && os(macOS)
        if bundle.image(forResource: NSImage.Name(thinnableName)) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#elseif canImport(UIKit) && !os(watchOS)
        if UIKit.UIImage(named: thinnableName, in: bundle, compatibleWith: nil) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSImage {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ImageResource?) {
#if !targetEnvironment(macCatalyst)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ImageResource?) {
#if !os(watchOS)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

