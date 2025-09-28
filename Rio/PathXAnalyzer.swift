//
//  PathXAnalyzer.swift
//  Rio
//
//  Created by Edward Sanchez on 9/25/25.
//


import SwiftUI
import SVGPath
import os.log

// X-parametrized path analyzer
struct PathXAnalyzer {
    struct Sample {
        let u: CGFloat      // Path parameter [0,1]
        let point: CGPoint  // Point on path
        let cumulativeX: CGFloat  // Cumulative horizontal distance
        let cumulativeLength: CGFloat  // Cumulative path length
    }

    let samples: [Sample]
    let totalXDistance: CGFloat
    let totalPathLength: CGFloat
    let bounds: CGRect

    init(path: CGPath, sampleCount: Int = 800) {
        let result = PathXAnalyzer.prepareSamples(
            for: path,
            sampleCount: max(sampleCount, 1)
        )

        self.samples = result.samples
        self.totalXDistance = result.totalXDistance
        self.totalPathLength = result.totalPathLength
        self.bounds = path.boundingBox
    }
    private struct PolylineData {
        let points: [CGPoint]
        let cumulativeLengths: [CGFloat]
        let cumulativeX: [CGFloat]
        let totalLength: CGFloat
        let totalX: CGFloat
    }

    private static func prepareSamples(for path: CGPath, sampleCount: Int) -> (samples: [Sample], totalXDistance: CGFloat, totalPathLength: CGFloat) {
        let divisions = max(sampleCount, 1)
        let stepsPerCurve = min(200, max(24, sampleCount / 4))
        let polyline = polylineData(for: path, stepsPerCurve: stepsPerCurve)

        guard polyline.totalLength > 0, polyline.points.count > 1 else {
            let origin = polyline.points.first ?? .zero
            let defaultSample = Sample(u: 0, point: origin, cumulativeX: 0, cumulativeLength: 0)
            return ([defaultSample], 0, 0)
        }

        var samples: [Sample] = []
        samples.reserveCapacity(divisions + 1)

        for index in 0...divisions {
            let fraction = CGFloat(index) / CGFloat(divisions)
            let targetLength = fraction * polyline.totalLength
            let (point, cumulativeX) = point(on: polyline, atLength: targetLength)

            samples.append(Sample(
                u: fraction,
                point: point,
                cumulativeX: cumulativeX,
                cumulativeLength: targetLength
            ))
        }

        return (samples, polyline.totalX, polyline.totalLength)
    }

    private static func polylineData(for path: CGPath, stepsPerCurve: Int) -> PolylineData {
        var points: [CGPoint] = []
        points.reserveCapacity(max(stepsPerCurve * 8, 16))

        var currentPoint: CGPoint = .zero
        var subpathStart: CGPoint = .zero

        func appendPoint(_ point: CGPoint) {
            if let last = points.last, last == point {
                return
            }
            points.append(point)
        }

        path.applyWithBlock { element in
            switch element.pointee.type {
            case .moveToPoint:
                currentPoint = element.pointee.points[0]
                subpathStart = currentPoint
                appendPoint(currentPoint)
            case .addLineToPoint:
                let end = element.pointee.points[0]
                appendPoint(end)
                currentPoint = end
            case .addQuadCurveToPoint:
                let control = element.pointee.points[0]
                let end = element.pointee.points[1]
                let steps = max(2, stepsPerCurve)
                for step in 1...steps {
                    let t = CGFloat(step) / CGFloat(steps)
                    appendPoint(quadPoint(p0: currentPoint, p1: control, p2: end, t: t))
                }
                currentPoint = end
            case .addCurveToPoint:
                let control1 = element.pointee.points[0]
                let control2 = element.pointee.points[1]
                let end = element.pointee.points[2]
                let steps = max(3, stepsPerCurve * 2)
                for step in 1...steps {
                    let t = CGFloat(step) / CGFloat(steps)
                    appendPoint(cubicPoint(p0: currentPoint, p1: control1, p2: control2, p3: end, t: t))
                }
                currentPoint = end
            case .closeSubpath:
                appendPoint(subpathStart)
                currentPoint = subpathStart
            @unknown default:
                break
            }
        }

        if points.isEmpty {
            points.append(.zero)
        }

        var cumulativeLengths: [CGFloat] = [0]
        var cumulativeX: [CGFloat] = [0]
        cumulativeLengths.reserveCapacity(points.count)
        cumulativeX.reserveCapacity(points.count)

        var totalLength: CGFloat = 0
        var totalX: CGFloat = 0

        for index in 1..<points.count {
            let start = points[index - 1]
            let end = points[index]
            let segmentLength = hypot(end.x - start.x, end.y - start.y)
            let segmentX = abs(end.x - start.x)

            totalLength += segmentLength
            totalX += segmentX

            cumulativeLengths.append(totalLength)
            cumulativeX.append(totalX)
        }

        return PolylineData(
            points: points,
            cumulativeLengths: cumulativeLengths,
            cumulativeX: cumulativeX,
            totalLength: totalLength,
            totalX: totalX
        )
    }

    private static func point(on polyline: PolylineData, atLength targetLength: CGFloat) -> (CGPoint, CGFloat) {
        guard let totalLength = polyline.cumulativeLengths.last, totalLength > 0 else {
            let point = polyline.points.first ?? .zero
            return (point, 0)
        }

        let clamped = min(max(targetLength, 0), totalLength)

        var low = 0
        var high = polyline.cumulativeLengths.count - 1

        while low < high {
            let mid = (low + high) / 2
            if polyline.cumulativeLengths[mid] < clamped {
                low = mid + 1
            } else {
                high = mid
            }
        }

        if low == 0 || polyline.cumulativeLengths[low] == clamped {
            let xValue = polyline.cumulativeX[min(low, polyline.cumulativeX.count - 1)]
            return (polyline.points[min(low, polyline.points.count - 1)], xValue)
        }

        let prevIndex = low - 1
        let prevLength = polyline.cumulativeLengths[prevIndex]
        let nextLength = polyline.cumulativeLengths[low]
        let denom = nextLength - prevLength

        let t = denom > 0 ? (clamped - prevLength) / denom : 0

        let startPoint = polyline.points[prevIndex]
        let endPoint = polyline.points[low]
        let startX = polyline.cumulativeX[prevIndex]
        let endX = polyline.cumulativeX[low]

        let interpolatedPoint = CGPoint(
            x: startPoint.x + (endPoint.x - startPoint.x) * t,
            y: startPoint.y + (endPoint.y - startPoint.y) * t
        )
        let interpolatedX = startX + (endX - startX) * t

        return (interpolatedPoint, interpolatedX)
    }

    private static func quadPoint(p0: CGPoint, p1: CGPoint, p2: CGPoint, t: CGFloat) -> CGPoint {
        let oneMinusT = 1 - t
        let x = oneMinusT * oneMinusT * p0.x + 2 * oneMinusT * t * p1.x + t * t * p2.x
        let y = oneMinusT * oneMinusT * p0.y + 2 * oneMinusT * t * p1.y + t * t * p2.y
        return CGPoint(x: x, y: y)
    }

    private static func cubicPoint(p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint, t: CGFloat) -> CGPoint {
        let oneMinusT = 1 - t
        let oneMinusTSquared = oneMinusT * oneMinusT
        let tSquared = t * t

        let a = oneMinusTSquared * oneMinusT
        let b = 3 * oneMinusTSquared * t
        let c = 3 * oneMinusT * tSquared
        let d = tSquared * t

        let x = a * p0.x + b * p1.x + c * p2.x + d * p3.x
        let y = a * p0.y + b * p1.y + c * p2.y + d * p3.y

        return CGPoint(x: x, y: y)
    }


    // Get path length between two x positions
    func pathLengthBetweenX(from startX: CGFloat, to endX: CGFloat) -> CGFloat {
        // Find samples at or near the x positions
        let startSample = sampleAtX(startX)
        let endSample = sampleAtX(endX)

        return abs(endSample.cumulativeLength - startSample.cumulativeLength)
    }

    // Find the sample closest to a given x position
    private func sampleAtX(_ targetX: CGFloat) -> Sample {
        // Binary search for the closest x position
        var bestSample = samples[0]
        var minDist = CGFloat.infinity

        for sample in samples {
            let dist = abs(sample.point.x - targetX)
            if dist < minDist {
                minDist = dist
                bestSample = sample
            }
        }

        return bestSample
    }

    // Get parameter u for a given x-distance traveled
    func parameterAtXDistance(_ xDist: CGFloat) -> CGFloat {
        guard xDist >= 0 else { return 0 }
        guard xDist < totalXDistance else { return 1 }

        // Binary search through samples
        var low = 0
        var high = samples.count - 1

        while low < high {
            let mid = (low + high) / 2
            if samples[mid].cumulativeX < xDist {
                low = mid + 1
            } else {
                high = mid
            }
        }

        // Interpolate between samples
        if low > 0 {
            let s1 = samples[low - 1]
            let s2 = samples[low]
            let t = (xDist - s1.cumulativeX) / max(0.001, s2.cumulativeX - s1.cumulativeX)
            return s1.u + t * (s2.u - s1.u)
        }

        return samples[low].u
    }

    // Get the actual point at a given path parameter
    func pointAtParameter(_ u: CGFloat) -> CGPoint {
        guard u >= 0 else { return samples.first?.point ?? .zero }
        guard u <= 1 else { return samples.last?.point ?? CGPoint(x: bounds.maxX, y: bounds.midY) }

        // Find the samples that bracket this parameter
        var low = 0
        var high = samples.count - 1

        while low < high {
            let mid = (low + high) / 2
            if samples[mid].u < u {
                low = mid + 1
            } else {
                high = mid
            }
        }

        // Interpolate between samples to get the point
        if low > 0 {
            let s1 = samples[low - 1]
            let s2 = samples[low]
            if s2.u > s1.u {
                let t = (u - s1.u) / (s2.u - s1.u)
                // Interpolate the point position
                return CGPoint(
                    x: s1.point.x + (s2.point.x - s1.point.x) * t,
                    y: s1.point.y + (s2.point.y - s1.point.y) * t
                )
            }
        }

        return samples[low].point
    }

    // Find the parameter that corresponds to a given X position
    func parameterAtXPosition(_ targetX: CGFloat) -> CGFloat {
        // Find the closest sample to the target X
        var bestU: CGFloat = 0
        var minDist = CGFloat.infinity

        for sample in samples {
            let dist = abs(sample.point.x - targetX)
            if dist < minDist {
                minDist = dist
                bestU = sample.u
            }
        }

        return bestU
    }

    // Find the parameter that is a certain X distance before another parameter
    func parameterXPixelsBefore(endParameter: CGFloat, xDistance: CGFloat) -> CGFloat {
        let endPoint = pointAtParameter(endParameter)
        let targetX = endPoint.x - xDistance

        // Find the samples that bracket the target X position
        var lowerSample: Sample?
        var upperSample: Sample?

        for sample in samples {
            guard sample.u <= endParameter else { break }

            let x = sample.point.x

            // Find the sample just before or at the target X
            if x <= targetX {
                if lowerSample == nil || x > lowerSample!.point.x {
                    lowerSample = sample
                }
            }

            // Find the sample just after the target X
            if x >= targetX {
                if upperSample == nil || x < upperSample!.point.x {
                    upperSample = sample
                }
            }
        }

        // If we have both lower and upper samples, interpolate
        if let lower = lowerSample, let upper = upperSample, upper.point.x != lower.point.x {
            let t = (targetX - lower.point.x) / (upper.point.x - lower.point.x)
            return lower.u + t * (upper.u - lower.u)
        }

        // If we only have one sample, use it
        if let lower = lowerSample {
            return lower.u
        }
        if let upper = upperSample {
            return upper.u
        }

        // Fallback to the beginning
        return 0
    }
}

