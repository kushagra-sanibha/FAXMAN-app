import CoreGraphics

/// Turns noisy per-frame page detections into a steady outline.
///
/// 1. Rejects implausible quads (not convex, too small, odd aspect ratio).
/// 2. Smooths each corner with an exponential moving average.
/// 3. Hysteresis: a corner only moves when the new detection is more than
///    `moveThreshold` (fraction of the frame diagonal) away, so the outline
///    doesn't shimmer while the page is still.
/// 4. Keeps the last outline for `holdDuration` after a missed detection.
/// 5. `isStable` once no corner has moved for `stableDuration`.
///
/// Pure value logic with an injected clock (`time`), so it is unit-testable
/// without a camera.
nonisolated final class QuadStabilizer {
    struct Configuration {
        /// Smallest page, as a fraction of the frame area.
        var minimumArea: CGFloat = 0.08
        /// Long side ÷ short side of the page in pixels. Letter is 1.29,
        /// A4 1.41; this leaves room for perspective and receipts.
        var aspectRatioRange: ClosedRange<CGFloat> = 1.0...3.5
        /// High enough that the outline keeps up with the page instead of trailing it.
        var smoothing: CGFloat = 0.6
        var moveThreshold: CGFloat = 0.015
        /// A corner moving this far means the page actually relocated —
        /// picked up, slid, or swapped for a new one — and the held-steady
        /// clock restarts. Below this, it's ordinary per-frame detector
        /// noise: the outline still eases toward it, but the hold isn't
        /// punished for it, or auto-capture would never fire.
        var resetThreshold: CGFloat = 0.05
        var holdDuration: Double = 0.3
        var stableDuration: Double = 0.8
    }

    let configuration: Configuration
    /// Frame width ÷ height, so distances and aspect ratios are measured in pixels.
    let frameAspect: CGFloat

    /// The outline to draw, or nil.
    private(set) var quad: NormalizedQuad?
    private var lastSeen: Double?
    private var steadySince: Double?
    private var isSeenNow = false
    /// A big jump seen once, waiting for a second frame to agree before
    /// it's trusted. One stray frame — Vision briefly latching onto a
    /// background edge, a shadow, the stack behind the page — would
    /// otherwise redraw the outline somewhere wrong for a single frame,
    /// which reads as the border flickering and losing its shape.
    private var pendingQuad: NormalizedQuad?

    init(frameAspect: CGFloat, configuration: Configuration = Configuration()) {
        self.frameAspect = frameAspect
        self.configuration = configuration
    }

    func reset() {
        quad = nil
        lastSeen = nil
        steadySince = nil
        isSeenNow = false
        pendingQuad = nil
    }

    /// Feed every analysed frame, including frames where nothing was found.
    func update(with detection: NormalizedQuad?, at time: Double) {
        guard let detection, isPlausible(detection) else {
            isSeenNow = false
            pendingQuad = nil
            if let lastSeen, time - lastSeen > configuration.holdDuration {
                quad = nil
                steadySince = nil
            }
            return
        }

        isSeenNow = true
        lastSeen = time
        guard let current = quad else {
            quad = detection
            steadySince = time
            pendingQuad = nil
            return
        }

        let maxDelta = zip(current.points, detection.points).map { distance($0, $1) }.max() ?? 0
        if maxDelta > configuration.resetThreshold {
            // Something changed enough that this might not be the same,
            // steady page any more — don't let auto-capture fire on stale
            // framing while that's sorted out.
            steadySince = time
            // But only redraw the outline here once a second, agreeing
            // frame confirms this isn't just one bad reading.
            guard let pendingQuad,
                  zip(pendingQuad.points, detection.points).allSatisfy({ distance($0, $1) <= configuration.moveThreshold }) else {
                pendingQuad = detection
                return
            }
        }
        pendingQuad = nil

        var jittered = false
        let smoothed = zip(current.points, detection.points).map { old, new -> CGPoint in
            guard distance(old, new) > configuration.moveThreshold else { return old }
            jittered = true
            let a = configuration.smoothing
            return CGPoint(x: old.x + (new.x - old.x) * a, y: old.y + (new.y - old.y) * a)
        }
        if jittered {
            quad = NormalizedQuad(topLeft: smoothed[0], topRight: smoothed[1], bottomRight: smoothed[2], bottomLeft: smoothed[3])
        }
    }

    /// Seconds the outline has been seen without moving (0 when not seen).
    func steadyDuration(at time: Double) -> Double {
        guard isSeenNow, let steadySince else { return 0 }
        return time - steadySince
    }

    func isStable(at time: Double) -> Bool {
        steadyDuration(at: time) >= configuration.stableDuration
    }

    // MARK: - Validation

    func isPlausible(_ quad: NormalizedQuad) -> Bool {
        guard quad.isValid, quad.area >= configuration.minimumArea else { return false }
        let p = quad.points.map { CGPoint(x: $0.x * frameAspect, y: $0.y) }
        let width = (length(p[0], p[1]) + length(p[3], p[2])) / 2
        let height = (length(p[0], p[3]) + length(p[1], p[2])) / 2
        guard min(width, height) > 0 else { return false }
        return configuration.aspectRatioRange.contains(max(width, height) / min(width, height))
    }

    /// Distance as a fraction of the frame diagonal.
    func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = (a.x - b.x) * frameAspect, dy = a.y - b.y
        return (dx * dx + dy * dy).squareRoot() / (frameAspect * frameAspect + 1).squareRoot()
    }

    private func length(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        ((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y)).squareRoot()
    }
}
