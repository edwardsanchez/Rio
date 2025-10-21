//
//  File.swift
//  
//
//  Created by Edward Sanchez on 1/24/24.
//

import Foundation

//Round number to 3 decimal places so there's higher chance of it matching dictionary key
func rd(_ i: CGFloat) -> CGFloat {
    return round(10000*(i))/10000
}

public enum CurveType {
    case easingCurve
    case spring
}

public class Curve {
    enum Curves {
        case easeIn
        case easeOut
        case easeInOut
        case linear
        case bezier
    }
    
    public var curveType = CurveType.easingCurve
    
    let type:     Curves
    let power:    CGFloat
    let fraction: CGFloat
    
    //Dictionary to hold coordinates of the bezier curve
    let coordinates: [CGFloat : CGFloat]
    
    var holder = CGFloat.zero
    
    private init(type:     Curves              = .linear,
                 power:    CGFloat             = 0,
                 fraction: CGFloat             = 0,
                 p1x:      CGFloat             = 0,
                 p1y:      CGFloat             = 0,
                 p2x:      CGFloat             = 0,
                 p2y:      CGFloat             = 0,
                 bezier:   [CGFloat : CGFloat] = [0 : 0]) {
        self.type        = type
        self.power       = power
        self.fraction    = fraction
        self.coordinates = bezier
    }
    
    public init() {
        self.type        = .linear
        self.power       = 0
        self.fraction    = 0
        self.coordinates = [0: 0]
    }
    
    public static var linear = Curve(type: .linear)
    
    public static func easeIn(_ power: CGFloat = 3) -> Curve {
        return Curve(type: .easeIn, power: power)
    }
    
    public static func easeOut(_ power: CGFloat = 3) -> Curve {
        return Curve(type: .easeOut, power: power)
    }
    
    public static func easeInOut(_ power: CGFloat = 3, _ fraction: CGFloat = 0.5) -> Curve {
        assert((fraction >= 0 || fraction <= 1), "Curve fraction must be greater than 0 and smaller than 1")
        
        return Curve(type: .easeInOut, power: power, fraction: fraction.percent)
    }
    
    public static func bezier(_ p1x: CGFloat = 0.5, _ p1y: CGFloat = 0, _ p2x: CGFloat = 0.4, _ p2y: CGFloat = 0.9) -> Curve {
        
        //Bezier Curve function
        func bezierPointOverTime(_ time: CGFloat) -> CGPoint {
            
            let p0  = CGPoint(x: 0, y: 1)
            let p3  = CGPoint(x: 1, y: 0)

            let p0m = (pow((1 - time), 3))
            let p1m = (3 * pow(1 - time, 2) * time)
            let p2m = (3 * (1 - time) * pow(time, 2))
            let p3m = (pow(time, 3))
            
            func BP(_ p0: CGFloat, _ p1: CGFloat, _ p2: CGFloat, _ p3: CGFloat) -> CGFloat {
                return p0m * p0 + p1m * p1 + p2m * p2 + p3m * p3
            }
            
            return CGPoint(x: 1 - BP(p0.x, p1x, p2x, p3.x), y:
                            BP(p0.y, 1 - p1y, 1 - p2y, p3.y))
        }
        
        var time = CGFloat.zero
        var coordinates = [CGFloat.zero: CGFloat.zero]
        
        //Populate dictionary with 50000 coordinates
        while time < 1 {
            coordinates[rd(bezierPointOverTime(time).x)] = rd(bezierPointOverTime(time).y)
            time += 1.0/50000
        }
        
        return Curve(type: .bezier, bezier: coordinates)
    }
}

public struct ValueInterpolator {
    private let inputMin: CGFloat
    private let inputMax: CGFloat
    private let outputMin: CGFloat
    private let outputMax: CGFloat
    private let extendRange: Bool
    private let curve: Curve
    private let log: Bool
    
    private let inputStart: CGFloat
    private let inputEnd: CGFloat
    private let outputStart: CGFloat
    private let outputEnd: CGFloat
    private let inputRange: CGFloat
    private let outputRange: CGFloat
    
    private let ratio: CGFloat
    
    public init(
        inputMin: CGFloat,
        inputMax: CGFloat,
        outputMin: CGFloat,
        outputMax: CGFloat,
        extendRange: Bool = false,
        curve: Curve = .linear,
        log: Bool = false
    ) {
        self.inputMin = inputMin
        self.inputMax = inputMax
        self.outputMin = outputMin
        self.outputMax = outputMax
        self.extendRange = extendRange
        self.curve = curve
        self.log = log
        
        //Check if input range is reversed
        inputStart  = min(inputMin, inputMax)
        inputEnd    = max(inputMin, inputMax)
        
        //Check if output range is reversed
        outputStart = min(outputMin, outputMax)
        outputEnd   = max(outputMin, outputMax)
        
        //Input and output ranges
        inputRange  = inputEnd  - inputStart
        outputRange = outputEnd - outputStart
        
        ratio = outputRange / inputRange
    }
    
    public func interpolateFrom(input: CGFloat) -> CGFloat {
        //Prevent input range from being 0, which would crash the app
        if inputRange == 0 {
            return outputStart
        }
        
        //Current input / Capped if extendRange is off
        let currentInput = extendRange ? input : max(inputStart, min(input, inputEnd))
        
        //Fraction complete with easing curve
        let curvedFractionComplete: CGFloat = {
            var fractionComplete = 1 - ((inputEnd - currentInput) / inputRange)
            
            //Reverse fraction complete if outputs and inputs are not both reversed
            if (outputMax != outputEnd) == (inputMax == inputEnd) {
                fractionComplete = 1 - fractionComplete
            }
            
            let curvedResult: CGFloat = {
                func easeIn(_ fraction: CGFloat = 1) -> CGFloat {
                    return pow(fractionComplete / fraction, curve.power) * fraction
                }
                
                func easeOut(_ fraction: CGFloat = 0) -> CGFloat {
                    let reversedFraction = 1 - fraction
                    return 1 - pow((1 - fractionComplete) / reversedFraction, curve.power) * reversedFraction
                }
                
                switch curve.type {
                case .easeIn:
                    return easeIn()
                case .easeOut:
                    return easeOut()
                case .easeInOut:
                    return {
                        if fractionComplete < curve.fraction {
                            return easeIn(curve.fraction)
                        } else {
                            return easeOut(curve.fraction)
                        }
                    }()
                case .bezier:
                    return {
                        //Map actual fraction complete to coordinate
                        if let BX = curve.coordinates[rd(fractionComplete)] {
                            curve.holder = BX
                            return BX
                        } else {
                            //Set easingCurve to the previous value in case there's no match (rare)
                            return curve.holder
                        }
                    }()
                    
                case .linear:
                    return fractionComplete
                }
            }()
            
            //Cap value between 0 and 1
            return 0 ... 1 ~= fractionComplete ? curvedResult : fractionComplete
        }()
        
        //Result
        let result = (inputRange * curvedFractionComplete * ratio) + outputStart
        
        //Logs values for debugging
        if log {
            print("------------------------------")
            print("input       ", input)
            print("inputMin    ", inputMin)
            print("inputMax    ", inputMax)
            print("outputMin   ", outputStart)
            print("outputMax   ", outputEnd)
            print("extendRange ", extendRange)
            print("curve       ", (curve.type))
            print("fraction    ", curvedFractionComplete)
            print("result      ", result)
            
            if extendRange && (input > inputEnd || input < inputStart) {
                print(">>>>>Outside range!!!!<<<<<")
            }
        }
        
        return result
    }
}
