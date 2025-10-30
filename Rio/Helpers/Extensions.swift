import Foundation
import SwiftUI

// MARK: - Global Functions

infix operator ?=
public func ?= <T>(left: inout T, right: T?) {
    if let right {
        left = right
    }
}

public func cot(_ value: CGFloat) -> CGFloat {
    1 / tan(value)
}

func clampValue(_ value: CGFloat, _ min: CGFloat, _ max: CGFloat) -> CGFloat {
    Swift.min(Swift.max(value, min), max)
}

// MARK: - Array Extension

public extension Array {
    var lastIndex: Int? {
        isEmpty ? nil : count - 1
    }
}

extension Color {
    init(light: Color, dark: Color) {
        self.init(UIColor(dynamicProvider: { traits in
            switch traits.userInterfaceStyle {
            case .light, .unspecified:
                return UIColor(light)
            case .dark:
                return UIColor(dark)
            @unknown default:
                return UIColor(light)
            }
        }))
    }
}

// MARK: - Double Extension

public extension Double {
    func string(_ decimals: Int) -> String {
        String(format: "%.\(decimals)f", self)
    }

    var cgfloat: CGFloat { CGFloat(self) }
    var float: Float { Float(self) }
    var timeInterval: TimeInterval { TimeInterval(self) }
    var nsNumber: NSNumber { NSNumber(value: self) }
    init(value: CGFloat) { self = Double(value) }

    func printValue(_ name: String = "") -> Double {
        print(name, self)
        return self
    }

    var degrees: Double { self * 180 / .pi }

    func isBetween(_ min: Double, _ max: Double) -> Bool {
        self >= min && self <= max
    }

    var negativeAngle: Double {
        self > 180 ? self - 360 : self
    }
}

// MARK: - Int Extension

public extension Int {
    func string(_ decimals: Int) -> String {
        String(format: "%.\(decimals)f", Double(self))
    }

    var double: Double { Double(self) }
    var string: String { String(describing: self) }
    var percent: CGFloat { clampValue(CGFloat(self), 0, 1) }
    var cgfloat: CGFloat { CGFloat(self) }
    var float: Float { Float(self) }
    var timeInterval: TimeInterval { TimeInterval(self) }
    var nsNumber: NSNumber { NSNumber(value: self) }
    init(value: CGFloat) { self = Int(value) }
}

// MARK: - CGFloat Extension

public extension CGFloat {
    func string(_ decimals: Int) -> String {
        String(format: "%.\(decimals)f", self)
    }

    var double: Double { Double(self) }
    var string: String { String(describing: self) }
    var percent: CGFloat { clampValue(self, 0, 1) }
    var float: Float { Float(self) }
    var timeInterval: TimeInterval { TimeInterval(self) }
    var nsNumber: NSNumber { NSNumber(value: Double(self)) }

    func clamp(min: CGFloat, max: CGFloat) -> CGFloat {
        clampValue(self, min, max)
    }

    func printValue(_ name: String = "") -> Double {
        print(name, self)
        return Double(self)
    }

    func decimals(_ points: Int) -> CGFloat {
        let dec = pow(10, CGFloat(points))
        return Darwin.round(self * dec) / dec
    }

    var degrees: CGFloat { self * 180 / .pi }
    var radians: CGFloat { self * .pi / 180 }

    var negativeAngle: CGFloat {
        self > 180 ? self - 360 : self
    }

    func negativeFrom(_ angle: CGFloat) -> CGFloat {
        self > angle ? self - 360 : self
    }

    var cap360: CGFloat {
        let ratio = (self / 360).decimals(0)
        let degrees = self - ratio * 360
        return degrees < 0 ? degrees + 360 : degrees
    }

    func isBetween(_ min: CGFloat, _ max: CGFloat) -> Bool {
        self >= min && self <= max
    }
}

// MARK: - CGPoint Extension

public extension CGPoint {
    var size: CGSize { CGSize(width: x, height: y) }
    var average: CGFloat { sqrt(x * x + y * y) }
    var transposed: CGPoint { CGPoint(x: y, y: x) }

    func clamp(min: CGPoint, max: CGPoint) -> CGPoint {
        let clampedX = x.clamp(min: min.x, max: max.x)
        let clampedY = y.clamp(min: min.y, max: max.y)
        return CGPoint(x: clampedX, y: clampedY)
    }
}

// MARK: - CGSize Extension

public extension CGSize {
    var transposed: CGSize { CGSize(width: height, height: width) }
    var point: CGPoint { CGPoint(x: width, y: height) }
}

// MARK: - CGRect Extension

public extension CGRect {
    init(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) {
        self.init(x: x, y: y, width: width, height: height)
    }

    func containsFromCenter(_ position: CGPoint) -> Bool {
        let xCenter = position.x + (width / 2)
        let yCenter = position.y + (height / 2)
        return contains(CGPoint(x: xCenter, y: yCenter))
    }
}

// MARK: - Dictionary Extension

extension Dictionary {
    func merge(_ dictionary: [Key: Value]) -> [Key: Value] {
        var merged = self
        dictionary.forEach { merged[$0.key] = $0.value }
        return merged
    }
}

// MARK: - NSNumber Extension

public extension NSNumber {
    var cgfloat: CGFloat { CGFloat(truncating: self) }
}
