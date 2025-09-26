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

    init(path: CGPath, sampleCount: Int = 800) {  // Increased sample count for better accuracy
        var samples: [Sample] = []
        var cumulativeX: CGFloat = 0
        var cumulativeLength: CGFloat = 0
        var previousPoint: CGPoint?

        // Sample the path at regular u intervals
        for i in 0...sampleCount {
            let u = CGFloat(i) / CGFloat(sampleCount)

            // Get point at parameter u
            let point = path.pointAtParameter(u) ?? .zero

            if let prev = previousPoint {
                // Calculate horizontal and path distances
                let dx = abs(point.x - prev.x)
                let pathDist = hypot(point.x - prev.x, point.y - prev.y)

                cumulativeX += dx
                cumulativeLength += pathDist
            }

            samples.append(Sample(
                u: u,
                point: point,
                cumulativeX: cumulativeX,
                cumulativeLength: cumulativeLength
            ))

            previousPoint = point
        }

        self.samples = samples
        self.totalXDistance = cumulativeX
        self.totalPathLength = cumulativeLength
        self.bounds = path.boundingBox
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

        // Find the parameter that best matches this X position
        // But ensure it's not greater than endParameter
        var bestU: CGFloat = 0
        var minDist = CGFloat.infinity

        for sample in samples {
            if sample.u <= endParameter {
                let dist = abs(sample.point.x - targetX)
                if dist < minDist {
                    minDist = dist
                    bestU = sample.u
                }
            }
        }

        return bestU
    }
}

// Extension to get the end point of a trimmed path
extension Path {
    func trimmedEndPoint(from startT: CGFloat, to endT: CGFloat) -> CGPoint? {
        // Get the CGPath and find the point at the trim end
        let cgPath = self.cgPath
        return cgPath.pointAtParameter(endT)
    }
}

// Extension to approximate point at parameter
extension CGPath {
    func pointAtParameter(_ t: CGFloat) -> CGPoint? {
        // Build a list of path segments with their lengths
        var segments: [(start: CGPoint, end: CGPoint, length: CGFloat)] = []
        var totalLength: CGFloat = 0
        var currentPoint = CGPoint.zero
        var firstPoint = CGPoint.zero

        self.applyWithBlock { element in
            switch element.pointee.type {
            case .moveToPoint:
                currentPoint = element.pointee.points[0]
                firstPoint = currentPoint

            case .addLineToPoint:
                let endPoint = element.pointee.points[0]
                let length = hypot(endPoint.x - currentPoint.x, endPoint.y - currentPoint.y)
                segments.append((start: currentPoint, end: endPoint, length: length))
                totalLength += length
                currentPoint = endPoint

            case .addQuadCurveToPoint:
                // Approximate quad curve with line segment
                let endPoint = element.pointee.points[1]
                let length = hypot(endPoint.x - currentPoint.x, endPoint.y - currentPoint.y) * 1.2
                segments.append((start: currentPoint, end: endPoint, length: length))
                totalLength += length
                currentPoint = endPoint

            case .addCurveToPoint:
                // Approximate cubic curve with line segment
                let endPoint = element.pointee.points[2]
                let length = hypot(endPoint.x - currentPoint.x, endPoint.y - currentPoint.y) * 1.3
                segments.append((start: currentPoint, end: endPoint, length: length))
                totalLength += length
                currentPoint = endPoint

            case .closeSubpath:
                if currentPoint != firstPoint {
                    let length = hypot(firstPoint.x - currentPoint.x, firstPoint.y - currentPoint.y)
                    segments.append((start: currentPoint, end: firstPoint, length: length))
                    totalLength += length
                    currentPoint = firstPoint
                }

            @unknown default:
                break
            }
        }

        guard totalLength > 0 && !segments.isEmpty else { return nil }

        // Find the point at parameter t
        let targetLength = t * totalLength
        var accumulatedLength: CGFloat = 0

        for segment in segments {
            if accumulatedLength + segment.length >= targetLength {
                // This segment contains our target point
                let segmentT = (targetLength - accumulatedLength) / segment.length
                return CGPoint(
                    x: segment.start.x + (segment.end.x - segment.start.x) * segmentT,
                    y: segment.start.y + (segment.end.y - segment.start.y) * segmentT
                )
            }
            accumulatedLength += segment.length
        }

        // Return last point if we've gone past the end
        return segments.last?.end ?? currentPoint
    }
}