import CoreImage
import CoreVideo
import UIKit
import Vision

/// Finds the page outline in a camera frame or a still image.
///
/// - Vision sees the image **upright**: camera frames arrive in the sensor's
///   landscape orientation, and Apple's document model is trained on
///   upright pages, so frames are analysed with the orientation the user is
///   looking at (`rotationAngle`) and the result is mapped back.
/// - Document segmentation finds the page outline (on a phone it is close
///   to the real page); each side is then **snapped** a short way onto the
///   strongest nearby edge (PageEdgeRefiner) for a tight fit. Rectangle
///   detection alone is the fallback where segmentation is unavailable.
///   The Simulator runs segmentation on a CPU fallback that returns wrong
///   outlines, so judge detection on a device (or natively on a Mac).
/// - Analysis runs on a copy about 640 px on the long side.
///
/// Results are `NormalizedQuad`s: 0…1, top-left origin, relative to the
/// image exactly as passed in. For a camera frame that is the sensor's own
/// orientation, i.e. AVFoundation's "capture device point" space.
nonisolated final class DocumentDetector: @unchecked Sendable {
    nonisolated enum Method: String, Sendable {
        case segmentation
        case refined
        case rectangles
    }

    nonisolated struct Detection: Sendable {
        let quad: NormalizedQuad
        let method: Method
        /// Width ÷ height of the analysed image (as passed in), for measuring in pixels.
        let imageAspect: CGFloat
        /// Sure this is exactly one page: all four sides sit on real paper
        /// edges and the outline has a page's proportions. The live scanner
        /// only shows its border (and auto-captures) when this is true.
        var isConfident = false
    }

    nonisolated enum FrameResult: Sendable {
        /// A previous frame is still being analysed; this one was skipped.
        case dropped
        case analysed(Detection?)
    }

    static let analysisLongSide: CGFloat = 640

    private let lock = NSLock()
    private var isBusy = false

    /// Live frames. Never queues work: if a request is still running, the
    /// frame is dropped. `rotationAngle` is how the frame must be turned to
    /// look upright to the user (90° for a phone held upright).
    func detect(in pixelBuffer: CVPixelBuffer, rotationAngle: CGFloat) -> FrameResult {
        lock.lock()
        if isBusy {
            lock.unlock()
            return .dropped
        }
        isBusy = true
        lock.unlock()
        defer {
            lock.lock()
            isBusy = false
            lock.unlock()
        }
        return .analysed(Self.detect(in: CIImage(cvPixelBuffer: pixelBuffer), rotationAngle: rotationAngle))
    }

    /// One-off detection (stills, the full-resolution photo). Stills are
    /// already upright, so the default rotation is 0.
    static func detect(in image: CIImage, rotationAngle: CGFloat = 0) -> Detection? {
        let extent = image.extent
        guard extent.width > 0, extent.height > 0 else { return nil }
        let scale = min(1, analysisLongSide / max(extent.width, extent.height))
        let scaled = image
            .transformed(by: CGAffineTransform(translationX: -extent.minX, y: -extent.minY))
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let turn = QuarterTurn(angle: rotationAngle)
        let handler = VNImageRequestHandler(ciImage: scaled, orientation: turn.orientation, options: [:])
        let aspect = extent.width / extent.height
        let uprightAspect = turn.quarters % 2 == 1 ? 1 / aspect : aspect

        // Segmentation's `confidence` doesn't separate right outlines from
        // wrong ones, so it isn't used as a filter.
        let segmentation = VNDetectDocumentSegmentationRequest()
        if (try? handler.perform([segmentation])) != nil,
           let found = segmentation.results?.first,
           let page = upright(from: found, aspect: uprightAspect) {
            // Snap each side onto the real edge where one is found. Any
            // rectangular document counts (paper, screens, cards), so
            // confidence comes from a plausible one-page shape, not from
            // every side snapping onto a bright-paper edge.
            if let gray = grayscale(scaled.oriented(turn.orientation)),
               let snapped = PageEdgeRefiner.refine(page, in: gray) {
                let confident = Self.looksLikeOnePage(snapped.quad, aspect: uprightAspect)
                return Detection(quad: turn.toInput(snapped.quad), method: .refined, imageAspect: aspect, isConfident: confident)
            }
            return Detection(quad: turn.toInput(page), method: .segmentation, imageAspect: aspect,
                             isConfident: Self.looksLikeOnePage(page, aspect: uprightAspect))
        }

        // Fallback only where segmentation isn't available. It finds any
        // rectangle (labels, picture frames), so it needs a large one.
        let rectangles = VNDetectRectanglesRequest()
        rectangles.maximumObservations = 1
        rectangles.minimumSize = 0.3
        rectangles.minimumConfidence = 0.8
        rectangles.quadratureTolerance = 30
        if (try? handler.perform([rectangles])) != nil,
           let found = rectangles.results?.first,
           let page = upright(from: found, aspect: uprightAspect) {
            return Detection(quad: turn.toInput(page), method: .rectangles, imageAspect: aspect)
        }
        return nil
    }

    /// Whether an outline is shaped like one sheet of paper seen from above,
    /// measured in pixels:
    /// - long side ÷ short side 1.1–1.9 (Letter 1.29, A4 1.41, plus
    ///   perspective) — rules out strips, a book opened flat, the table;
    /// - every corner 60°–120° — a lopsided, "disbalanced" outline means one
    ///   side latched onto something else (a cover, the spiral, a shadow);
    /// - opposite sides within 1.6× of each other — perspective shortens the
    ///   far side, but not by more than that when the page is fully in view.
    static func looksLikeOnePage(_ quad: NormalizedQuad, aspect: CGFloat) -> Bool {
        let p = quad.points.map { CGPoint(x: $0.x * aspect, y: $0.y) }
        func length(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }
        let top = length(p[0], p[1]), right = length(p[1], p[2]), bottom = length(p[2], p[3]), left = length(p[3], p[0])
        guard min(top, right, bottom, left) > 0 else { return false }

        let width: CGFloat = (top + bottom) / 2
        let height: CGFloat = (left + right) / 2
        let proportion: CGFloat = max(width, height) / min(width, height)
        guard proportion >= 1.1, proportion <= 1.9 else { return false }
        let horizontalRatio: CGFloat = max(top, bottom) / min(top, bottom)
        let verticalRatio: CGFloat = max(left, right) / min(left, right)
        guard horizontalRatio <= 1.6, verticalRatio <= 1.6 else { return false }

        for i in 0..<4 {
            let a = p[(i + 3) % 4], b = p[i], c = p[(i + 1) % 4]
            let v1 = CGVector(dx: a.x - b.x, dy: a.y - b.y)
            let v2 = CGVector(dx: c.x - b.x, dy: c.y - b.y)
            let dot: CGFloat = v1.dx * v2.dx + v1.dy * v2.dy
            let lengths: CGFloat = hypot(v1.dx, v1.dy) * hypot(v2.dx, v2.dy)
            let cosine: CGFloat = min(max(dot / lengths, -1), 1)
            let degrees: CGFloat = acos(cosine) * 180 / .pi
            guard degrees >= 60, degrees <= 120 else { return false }
        }
        return true
    }

    private static let context = CIContext(options: [.cacheIntermediates: false])

    /// The analysis image as 8-bit gray, top-left origin, for edge snapping.
    private static func grayscale(_ image: CIImage) -> GrayImage? {
        let extent = image.extent.integral
        let width = Int(extent.width), height = Int(extent.height)
        guard width > 0, height > 0 else { return nil }
        var pixels = [UInt8](repeating: 0, count: width * height)
        let gray = image
            .transformed(by: CGAffineTransform(translationX: -extent.minX, y: -extent.minY))
            .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0])
        pixels.withUnsafeMutableBytes { buffer in
            // Core Image renders bottom row first into a buffer whose first
            // row is the top, i.e. top-left origin, as GrayImage expects.
            context.render(gray, toBitmap: buffer.baseAddress!, rowBytes: width,
                           bounds: CGRect(x: 0, y: 0, width: width, height: height), format: .L8, colorSpace: nil)
        }
        return GrayImage(width: width, height: height, pixels: pixels)
    }

    /// Vision is bottom-left-origin; NormalizedQuad is top-left-origin.
    /// Coordinates here are in the upright (oriented) image.
    ///
    /// Vision's own `topLeft`/`topRight`/etc. labels aren't guaranteed to
    /// match "as seen by the user" — for a page that's tilted, steeply
    /// angled, or close to square in frame, which corner it calls
    /// top-left can be ambiguous. Trusting a wrong label doesn't move the
    /// outline anywhere wrong, but it does rotate perspective correction's
    /// *output* by 90°/180° from how the page was actually held, since the
    /// labels — not the points — decide which side becomes the output's
    /// width and which becomes its height. So the 4 points are relabeled
    /// ourselves: whichever cyclic rotation puts the most nearly
    /// horizontal side on top wins, independent of what Vision called it.
    private static func upright(from observation: VNRectangleObservation, aspect: CGFloat) -> NormalizedQuad? {
        func flipped(_ point: CGPoint) -> CGPoint {
            CGPoint(x: min(max(point.x, 0), 1), y: min(max(1 - point.y, 0), 1))
        }
        let quad = NormalizedQuad(
            topLeft: flipped(observation.topLeft),
            topRight: flipped(observation.topRight),
            bottomRight: flipped(observation.bottomRight),
            bottomLeft: flipped(observation.bottomLeft)
        )
        guard quad.isValid else { return nil }
        return canonicalCorners(of: quad, aspect: aspect)
    }

    static func canonicalCorners(of quad: NormalizedQuad, aspect: CGFloat) -> NormalizedQuad {
        let points = quad.points
        var best = quad
        var bestDeviation = CGFloat.infinity
        for shift in 0..<4 {
            let p = (0..<4).map { points[($0 + shift) % 4] }
            let dx = (p[1].x - p[0].x) * aspect, dy = p[1].y - p[0].y
            guard dx != 0 || dy != 0 else { continue }
            // Distance from "pointing right" (0°), not just from the
            // horizontal line — a top edge pointing left (180°) is exactly
            // as upside-down as it looks, not as good as pointing right.
            let deviation = abs(atan2(dy, dx) * 180 / .pi)
            if deviation < bestDeviation {
                bestDeviation = deviation
                best = NormalizedQuad(topLeft: p[0], topRight: p[1], bottomRight: p[2], bottomLeft: p[3])
            }
        }
        return best
    }
}

/// How the image as passed in is turned (clockwise) to look upright, and
/// the mapping of normalized top-left-origin points back to it.
nonisolated struct QuarterTurn: Sendable {
    /// 0, 1, 2 or 3 clockwise quarter turns.
    let quarters: Int

    init(angle: CGFloat) {
        quarters = ((Int((angle / 90).rounded()) % 4) + 4) % 4
    }

    /// From a decoded photo's own orientation — the ground truth for how it
    /// was actually rotated, independent of what rotation was requested at
    /// capture time. The back camera never mirrors, so only these four occur.
    init(orientation: UIImage.Orientation) {
        switch orientation {
        case .right: quarters = 1
        case .down: quarters = 2
        case .left: quarters = 3
        default: quarters = 0
        }
    }

    var orientation: CGImagePropertyOrientation {
        switch quarters {
        case 1: .right
        case 2: .down
        case 3: .left
        default: .up
        }
    }

    /// Upright point (u, v) → the same point in the image as passed in.
    func toInput(_ point: CGPoint) -> CGPoint {
        switch quarters {
        case 1: CGPoint(x: point.y, y: 1 - point.x)
        case 2: CGPoint(x: 1 - point.x, y: 1 - point.y)
        case 3: CGPoint(x: 1 - point.y, y: point.x)
        default: point
        }
    }

    /// Keeps corner order (top-left first, clockwise) as seen by the user.
    func toInput(_ quad: NormalizedQuad) -> NormalizedQuad {
        NormalizedQuad(
            topLeft: toInput(quad.topLeft), topRight: toInput(quad.topRight),
            bottomRight: toInput(quad.bottomRight), bottomLeft: toInput(quad.bottomLeft)
        )
    }

    /// Point in the image as passed in → the same point upright (inverse of `toInput`).
    func toUpright(_ point: CGPoint) -> CGPoint {
        switch quarters {
        case 1: CGPoint(x: 1 - point.y, y: point.x)
        case 2: CGPoint(x: 1 - point.x, y: 1 - point.y)
        case 3: CGPoint(x: point.y, y: 1 - point.x)
        default: point
        }
    }

    /// Keeps corner labels, which are already as seen by the user.
    func toUpright(_ quad: NormalizedQuad) -> NormalizedQuad {
        NormalizedQuad(
            topLeft: toUpright(quad.topLeft), topRight: toUpright(quad.topRight),
            bottomRight: toUpright(quad.bottomRight), bottomLeft: toUpright(quad.bottomLeft)
        )
    }
}
