import Foundation
import SwiftUI

// MARK: - Global Functions

infix operator ?=
public func ?= <T>(left: inout T, right: T?) {
    if let right = right {
        left = right
    }
}

public func cot(_ value: CGFloat) -> CGFloat {
    return 1 / tan(value)
}

func clampValue(_ value: CGFloat, _ min: CGFloat, _ max: CGFloat) -> CGFloat {
    return Swift.min(Swift.max(value, min), max)
}

// MARK: - Array Extension

extension Array {
    public var lastIndex: Int? {
        return isEmpty ? nil : count - 1
    }
}

// MARK: - Double Extension

extension Double {
    public func string(_ decimals: Int) -> String {
        return String(format: "%.\(decimals)f", self)
    }
    
    public var cgfloat: CGFloat { CGFloat(self) }
    public var float: Float { Float(self) }
    public var timeInterval: TimeInterval { TimeInterval(self) }
    public var nsNumber: NSNumber { NSNumber(value: self) }
    public init(value: CGFloat) { self = Double(value) }
    
    public func printValue(_ name: String = "") -> Double {
        print(name, self)
        return self
    }
    
    public var degrees: Double { self * 180 / .pi }
    
    public func isBetween(_ min: Double, _ max: Double) -> Bool {
        self >= min && self <= max
    }
    
    public var negativeAngle: Double {
        return self > 180 ? self - 360 : self
    }
}

// MARK: - Int Extension

extension Int {
    public func string(_ decimals: Int) -> String {
        return String(format: "%.\(decimals)f", Double(self))
    }
    
    public var double: Double { Double(self) }
    public var string: String { String(describing: self) }
    public var percent: CGFloat { clampValue(CGFloat(self), 0, 1) }
    public var cgfloat: CGFloat { CGFloat(self) }
    public var float: Float { Float(self) }
    public var timeInterval: TimeInterval { TimeInterval(self) }
    public var nsNumber: NSNumber { NSNumber(value: self) }
    public init(value: CGFloat) { self = Int(value) }
}

// MARK: - CGFloat Extension

extension CGFloat {
    public func string(_ decimals: Int) -> String {
        return String(format: "%.\(decimals)f", self)
    }
    
    public var double: Double { Double(self) }
    public var string: String { String(describing: self) }
    public var percent: CGFloat { clampValue(self, 0, 1) }
    public var float: Float { Float(self) }
    public var timeInterval: TimeInterval { TimeInterval(self) }
    public var nsNumber: NSNumber { NSNumber(value: Double(self)) }
    
    public func clamp(min: CGFloat, max: CGFloat) -> CGFloat {
        clampValue(self, min, max)
    }
    
    public func printValue(_ name: String = "") -> Double {
        print(name, self)
        return Double(self)
    }
    
    public func decimals(_ points: Int) -> CGFloat {
        let dec = pow(10, CGFloat(points))
        return Darwin.round(self * dec) / dec
    }
    
    public var degrees: CGFloat { self * 180 / .pi }
    public var radians: CGFloat { self * .pi / 180 }
    
    public var negativeAngle: CGFloat {
        return self > 180 ? self - 360 : self
    }
    
    public func negativeFrom(_ angle: CGFloat) -> CGFloat {
        return self > angle ? self - 360 : self
    }
    
    public var cap360: CGFloat {
        let ratio = (self / 360).decimals(0)
        let degrees = self - ratio * 360
        return degrees < 0 ? degrees + 360 : degrees
    }
    
    public func isBetween(_ min: CGFloat, _ max: CGFloat) -> Bool {
        self >= min && self <= max
    }
}

// MARK: - CGPoint Extension

extension CGPoint {
    public var size: CGSize { CGSize(width: x, height: y) }
    public var average: CGFloat { sqrt(x * x + y * y) }
    public var transposed: CGPoint { CGPoint(y, x) }
    
    public func clamp(min: CGPoint, max: CGPoint) -> CGPoint {
        let clampedX = x.clamp(min: min.x, max: max.x)
        let clampedY = y.clamp(min: min.y, max: max.y)
        return CGPoint(clampedX, clampedY)
    }
}

// MARK: - CGSize Extension

extension CGSize {
    public var transposed: CGSize { CGSize(height, width) }
    public var point: CGPoint { CGPoint(width, height) }

}

// MARK: - CGRect Extension

extension CGRect {
    public init(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) {
        self.init(x: x, y: y, width: width, height: height)
    }
    
    public func containsFromCenter(_ position: CGPoint) -> Bool {
        let xCenter = position.x + (width / 2)
        let yCenter = position.y + (height / 2)
        return self.contains(CGPoint(xCenter, yCenter))
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

extension NSNumber {
    public var cgfloat: CGFloat { CGFloat(truncating: self) }
}
