//
//  PathXAnalyzer.swift
//  Rio
//
//  Created by Edward Sanchez on 9/25/25.
//

import SwiftUI
import SVGPath

/**
 * PathXAnalyzer provides sophisticated analysis and measurement capabilities for CGPath objects.
 *
 * This analyzer is specifically designed for animated cursive text rendering, where precise
 * coordinate transformations and path measurements are essential for smooth animations and
 * accurate positioning calculations.
 *
 * **Core Capabilities**:
 * - **Path Sampling**: Converts complex curves into a series of discrete sample points
 * - **Dual Distance Tracking**: Tracks both Euclidean path length and horizontal X-distance
 * - **Parameter Mapping**: Bidirectional conversion between path parameters and positions
 * - **Window Calculations**: Determines path parameters for sliding window animations
 * - **Coordinate Transformations**: Precise point-to-parameter and parameter-to-point mapping
 *
 * **Mathematical Foundation**:
 * The analyzer uses uniform path-length sampling to create a lookup table of Sample points,
 * each containing the path parameter (u), actual point coordinates, cumulative X-distance,
 * and cumulative path length. This enables efficient O(log n) binary search operations
 * for real-time animation calculations.
 *
 * **Performance Optimization**:
 * - Default 800 samples provide sub-pixel accuracy for most use cases
 * - Binary search algorithms for O(log n) lookup performance
 * - Interpolation between samples for smooth sub-sample precision
 * - Efficient curve tessellation with adaptive step counts
 */
struct PathXAnalyzer {
    /**
     * Sample represents a single point along the path with comprehensive measurement data.
     *
     * Each sample captures both the geometric position and cumulative distance measurements
     * needed for animation calculations and coordinate transformations.
     */
    struct Sample {
        let u: CGFloat                    /// Path parameter [0,1] - position along the complete path
        let point: CGPoint                /// Actual (x,y) coordinates at this path position
        let cumulativeX: CGFloat          /// Total horizontal distance traveled from path start
        let cumulativeLength: CGFloat     /// Total Euclidean path length from path start
    }

    // MARK: - Core Data

    let samples: [Sample]           /// Array of uniformly-spaced path samples for analysis
    let totalXDistance: CGFloat     /// Total horizontal distance covered by the entire path
    let totalPathLength: CGFloat    /// Total Euclidean length of the entire path
    let bounds: CGRect              /// Bounding rectangle of the original path

    /**
     * Initializes a PathXAnalyzer for the given CGPath with specified sampling resolution.
     *
     * The initialization process involves several sophisticated steps:
     * 1. **Path Tessellation**: Converts curves to polyline approximation
     * 2. **Distance Calculation**: Computes both Euclidean and X-distance metrics
     * 3. **Uniform Sampling**: Creates evenly-spaced samples along the path length
     * 4. **Lookup Table Creation**: Builds efficient data structures for real-time queries
     *
     * - Parameters:
     *   - path: The CGPath to analyze (typically from CursiveWordShape)
     *   - sampleCount: Number of samples to generate (default: 800 for sub-pixel accuracy)
     */
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

    /**
     * Internal data structure for polyline representation of the path.
     *
     * This intermediate representation bridges the gap between the original CGPath
     * (which may contain complex curves) and the final Sample array (which provides
     * uniform path-length spacing).
     */
    private struct PolylineData {
        let points: [CGPoint]           /// Tessellated points approximating the path
        let cumulativeLengths: [CGFloat] /// Running total of Euclidean distances
        let cumulativeX: [CGFloat]      /// Running total of horizontal distances
        let totalLength: CGFloat        /// Final total Euclidean path length
        let totalX: CGFloat             /// Final total horizontal distance
    }

    /**
     * Creates uniformly-spaced samples along the path for efficient analysis and lookup.
     *
     * This method implements the core sampling algorithm that converts an arbitrary CGPath
     * into a uniform grid of analysis points. The process involves:
     *
     * **1. Tessellation**: Convert the path to a high-resolution polyline approximation
     * **2. Uniform Sampling**: Create samples at equal path-length intervals (not equal parameter intervals)
     * **3. Interpolation**: Calculate precise positions between tessellation points
     *
     * The uniform path-length spacing is crucial for animation calculations, as it ensures
     * that parameter differences correspond to equal visual distances along the path.
     *
     * - Parameters:
     *   - path: The CGPath to sample
     *   - sampleCount: Number of samples to generate
     * - Returns: Tuple containing samples array and total distance measurements
     */
    private static func prepareSamples(for path: CGPath, sampleCount: Int) -> (samples: [Sample], totalXDistance: CGFloat, totalPathLength: CGFloat) {
        let divisions = max(sampleCount, 1)
        // Adaptive tessellation: more steps for higher sample counts, but capped for performance
        let stepsPerCurve = min(200, max(24, sampleCount / 4))
        let polyline = polylineData(for: path, stepsPerCurve: stepsPerCurve)

        // Handle degenerate cases (empty or single-point paths)
        guard polyline.totalLength > 0, polyline.points.count > 1 else {
            let origin = polyline.points.first ?? .zero
            let defaultSample = Sample(u: 0, point: origin, cumulativeX: 0, cumulativeLength: 0)
            return ([defaultSample], 0, 0)
        }

        var samples: [Sample] = []
        samples.reserveCapacity(divisions + 1)

        // Create samples at uniform path-length intervals
        for index in 0...divisions {
            let fraction = CGFloat(index) / CGFloat(divisions)  // Parameter from 0 to 1
            let targetLength = fraction * polyline.totalLength  // Corresponding path length
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

    /**
     * Converts a CGPath to a high-resolution polyline approximation with distance calculations.
     *
     * This method performs path tessellation, converting complex curves (quadratic and cubic Bézier)
     * into a series of line segments that closely approximate the original path. The tessellation
     * quality is controlled by stepsPerCurve, balancing accuracy with performance.
     *
     * **Tessellation Process**:
     * - **Lines**: Added directly (already linear)
     * - **Quadratic curves**: Subdivided using parametric evaluation
     * - **Cubic curves**: Subdivided with higher resolution (2x steps)
     * - **Subpath handling**: Properly manages move-to and close-subpath operations
     *
     * **Distance Tracking**: Simultaneously calculates both Euclidean path length and
     * horizontal X-distance for each segment, building cumulative totals.
     *
     * - Parameters:
     *   - path: The CGPath to tessellate
     *   - stepsPerCurve: Number of linear segments per curve (higher = more accurate)
     * - Returns: PolylineData containing tessellated points and distance measurements
     */
    private static func polylineData(for path: CGPath, stepsPerCurve: Int) -> PolylineData {
        var points: [CGPoint] = []
        points.reserveCapacity(max(stepsPerCurve * 8, 16))

        var currentPoint: CGPoint = .zero
        var subpathStart: CGPoint = .zero

        // Helper to avoid duplicate consecutive points
        func appendPoint(_ point: CGPoint) {
            if let last = points.last, last == point {
                return
            }
            points.append(point)
        }

        // Traverse the path and tessellate each element
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
                // Tessellate quadratic Bézier curve
                let control = element.pointee.points[0]
                let end = element.pointee.points[1]
                let steps = max(2, stepsPerCurve)
                for step in 1...steps {
                    let t = CGFloat(step) / CGFloat(steps)
                    appendPoint(quadPoint(p0: currentPoint, p1: control, p2: end, t: t))
                }
                currentPoint = end
            case .addCurveToPoint:
                // Tessellate cubic Bézier curve (higher resolution for complexity)
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

        // Ensure we have at least one point
        if points.isEmpty {
            points.append(.zero)
        }

        // Calculate cumulative distances for both Euclidean length and X-distance
        var cumulativeLengths: [CGFloat] = [0]
        var cumulativeX: [CGFloat] = [0]
        cumulativeLengths.reserveCapacity(points.count)
        cumulativeX.reserveCapacity(points.count)

        var totalLength: CGFloat = 0
        var totalX: CGFloat = 0

        // Process each segment to build cumulative distance arrays
        for index in 1..<points.count {
            let start = points[index - 1]
            let end = points[index]

            // Euclidean distance (actual path length)
            let segmentLength = hypot(end.x - start.x, end.y - start.y)
            // Horizontal distance (X-axis projection)
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

    /**
     * Finds the point and cumulative X-distance at a specific path length along the polyline.
     *
     * This method uses binary search to efficiently locate the polyline segment containing
     * the target length, then performs linear interpolation to find the precise position.
     * This is a critical operation for creating uniform path-length samples.
     *
     * **Algorithm**:
     * 1. **Binary Search**: O(log n) search to find the segment containing target length
     * 2. **Interpolation**: Linear interpolation between segment endpoints for precision
     * 3. **Dual Calculation**: Computes both point coordinates and cumulative X-distance
     *
     * - Parameters:
     *   - polyline: The tessellated polyline data
     *   - targetLength: The desired path length from the start
     * - Returns: Tuple of (interpolated point, cumulative X-distance at that point)
     */
    private static func point(on polyline: PolylineData, atLength targetLength: CGFloat) -> (CGPoint, CGFloat) {
        guard let totalLength = polyline.cumulativeLengths.last, totalLength > 0 else {
            let point = polyline.points.first ?? .zero
            return (point, 0)
        }

        let clamped = min(max(targetLength, 0), totalLength)

        // Binary search to find the segment containing the target length
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

        // Handle exact matches or boundary cases
        if low == 0 || polyline.cumulativeLengths[low] == clamped {
            let xValue = polyline.cumulativeX[min(low, polyline.cumulativeX.count - 1)]
            return (polyline.points[min(low, polyline.points.count - 1)], xValue)
        }

        // Interpolate between the two bracketing points
        let prevIndex = low - 1
        let prevLength = polyline.cumulativeLengths[prevIndex]
        let nextLength = polyline.cumulativeLengths[low]
        let denom = nextLength - prevLength

        let t = denom > 0 ? (clamped - prevLength) / denom : 0

        let startPoint = polyline.points[prevIndex]
        let endPoint = polyline.points[low]
        let startX = polyline.cumulativeX[prevIndex]
        let endX = polyline.cumulativeX[low]

        // Linear interpolation for both point coordinates and cumulative X
        let interpolatedPoint = CGPoint(
            x: startPoint.x + (endPoint.x - startPoint.x) * t,
            y: startPoint.y + (endPoint.y - startPoint.y) * t
        )
        let interpolatedX = startX + (endX - startX) * t

        return (interpolatedPoint, interpolatedX)
    }

    /**
     * Evaluates a quadratic Bézier curve at parameter t using the standard parametric formula.
     *
     * Quadratic Bézier curves are defined by three control points and use the formula:
     * B(t) = (1-t)²P₀ + 2(1-t)tP₁ + t²P₂
     *
     * This is used during path tessellation to convert quadratic curve segments into
     * linear approximations for distance calculations.
     *
     * - Parameters:
     *   - p0: Start point of the curve
     *   - p1: Control point (influences curve shape)
     *   - p2: End point of the curve
     *   - t: Parameter from 0.0 to 1.0 (0=start, 1=end)
     * - Returns: Point on the curve at parameter t
     */
    private static func quadPoint(p0: CGPoint, p1: CGPoint, p2: CGPoint, t: CGFloat) -> CGPoint {
        let oneMinusT = 1 - t
        let x = oneMinusT * oneMinusT * p0.x + 2 * oneMinusT * t * p1.x + t * t * p2.x
        let y = oneMinusT * oneMinusT * p0.y + 2 * oneMinusT * t * p1.y + t * t * p2.y
        return CGPoint(x: x, y: y)
    }

    /**
     * Evaluates a cubic Bézier curve at parameter t using the standard parametric formula.
     *
     * Cubic Bézier curves are defined by four control points and use the formula:
     * B(t) = (1-t)³P₀ + 3(1-t)²tP₁ + 3(1-t)t²P₂ + t³P₃
     *
     * This is used during path tessellation to convert cubic curve segments into
     * linear approximations. Cubic curves are more complex than quadratic curves
     * and typically require higher tessellation resolution.
     *
     * - Parameters:
     *   - p0: Start point of the curve
     *   - p1: First control point
     *   - p2: Second control point
     *   - p3: End point of the curve
     *   - t: Parameter from 0.0 to 1.0 (0=start, 1=end)
     * - Returns: Point on the curve at parameter t
     */
    private static func cubicPoint(p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint, t: CGFloat) -> CGPoint {
        let oneMinusT = 1 - t
        let oneMinusTSquared = oneMinusT * oneMinusT
        let tSquared = t * t

        // Bernstein polynomial coefficients for cubic Bézier
        let a = oneMinusTSquared * oneMinusT  // (1-t)³
        let b = 3 * oneMinusTSquared * t       // 3(1-t)²t
        let c = 3 * oneMinusT * tSquared       // 3(1-t)t²
        let d = tSquared * t                   // t³

        let x = a * p0.x + b * p1.x + c * p2.x + d * p3.x
        let y = a * p0.y + b * p1.y + c * p2.y + d * p3.y

        return CGPoint(x: x, y: y)
    }


    // MARK: - Public Analysis Methods

    /**
     * Calculates the Euclidean path length between two X positions.
     *
     * This method is useful for determining how much actual path distance corresponds
     * to a given horizontal span, which is important for window width calculations
     * in the animated text system.
     *
     * - Parameters:
     *   - startX: Starting X coordinate
     *   - endX: Ending X coordinate
     * - Returns: Euclidean path length between the two X positions
     */
    func pathLengthBetweenX(from startX: CGFloat, to endX: CGFloat) -> CGFloat {
        // Find samples at or near the x positions
        let startSample = sampleAtX(startX)
        let endSample = sampleAtX(endX)

        return abs(endSample.cumulativeLength - startSample.cumulativeLength)
    }

    /**
     * Finds the sample point closest to a given X coordinate.
     *
     * This method performs a linear search through all samples to find the one
     * with the minimum X-distance to the target. While O(n), it's acceptable
     * given the typical sample count and infrequent usage.
     *
     * - Parameter targetX: The target X coordinate
     * - Returns: The sample with the closest X coordinate
     */
    private func sampleAtX(_ targetX: CGFloat) -> Sample {
        // Linear search for the closest x position
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

