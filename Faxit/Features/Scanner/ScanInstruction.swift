import CoreGraphics

/// Whether the page in view is good enough to auto-capture, and if not,
/// the one thing to fix. A page is captured automatically when it is fully
/// in view, big enough, not at an extreme angle, and steady. A moderate
/// angle is fine: the capture is flattened.
nonisolated enum ScanInstruction: Equatable, Sendable {
    case findPage
    case holdFlat
    case fitCorners
    case moveCloser
    case holdSteady
    case ready
    /// After an auto-capture: waits for the next page so the same one isn't captured twice.
    case nextPage

    /// The page must fill at least this much of the frame.
    static let minPageArea: CGFloat = 0.2
    /// A corner this close to the frame edge means the page is cut off.
    static let edgeMargin: CGFloat = 0.015
    /// Seen straight-on, a page's corners are square; at an angle, its
    /// outline becomes a trapezoid. Moderate angles are flattened on
    /// capture; past this, text at the far edge gets too small to read.
    /// Judged from the page itself, so it works however the phone and page
    /// are oriented.
    static let maxCornerSkewDegrees: CGFloat = 25

    /// - Parameter frameAspect: width ÷ height of the frame the quad is in,
    ///   so angles are measured in pixels.
    static func evaluate(quad: NormalizedQuad?, frameAspect: CGFloat, isStable: Bool) -> ScanInstruction {
        guard let quad else { return .findPage }
        let touchesEdge = quad.points.contains { point in
            point.x < edgeMargin || point.x > 1 - edgeMargin || point.y < edgeMargin || point.y > 1 - edgeMargin
        }
        if touchesEdge { return .fitCorners }
        if quad.area < minPageArea { return .moveCloser }
        if cornerSkew(quad, aspect: frameAspect) > maxCornerSkewDegrees { return .holdFlat }
        return isStable ? .ready : .holdSteady
    }

    /// Largest difference from a right angle at any corner, in degrees.
    static func cornerSkew(_ quad: NormalizedQuad, aspect: CGFloat) -> CGFloat {
        let p = quad.points.map { CGPoint(x: $0.x * aspect, y: $0.y) }
        var worst: CGFloat = 0
        for i in 0..<4 {
            let a = p[(i + 3) % 4], b = p[i], c = p[(i + 1) % 4]
            let v1 = CGVector(dx: a.x - b.x, dy: a.y - b.y)
            let v2 = CGVector(dx: c.x - b.x, dy: c.y - b.y)
            let dot: CGFloat = v1.dx * v2.dx + v1.dy * v2.dy
            let lengths: CGFloat = hypot(v1.dx, v1.dy) * hypot(v2.dx, v2.dy)
            guard lengths > 0 else { return 90 }
            let degrees: CGFloat = acos(min(max(dot / lengths, -1), 1)) * 180 / .pi
            worst = max(worst, abs(degrees - 90))
        }
        return worst
    }
}
