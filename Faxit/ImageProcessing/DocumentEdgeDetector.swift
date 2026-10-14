import UIKit

/// Finds the paper's four corners in a photo — for uploaded photos (so the
/// crop tool starts from the detected page) and for checking scans.
/// Detection itself is DocumentDetector, shared with the live camera.
enum DocumentEdgeDetector {
    nonisolated static func detectDocument(in image: UIImage) -> NormalizedQuad? {
        // Oriented upright, so the quad matches the image as displayed.
        guard let ciImage = FaxImageProcessor.ciImage(from: image),
              let quad = DocumentDetector.detect(in: ciImage)?.quad else { return nil }
        // A tiny detection is usually a sticker/label, not the page.
        return quad.area > 0.15 ? quad : nil
    }

    /// For a page the scanner returned: the page outline if the page is
    /// clearly still sitting at an angle inside the photo. VisionKit crops
    /// and straightens pages whose edges it finds, so a visible, skewed
    /// outline means it didn't (steep angle, too far away, low contrast).
    /// An upright box printed on the page (a form border) has square
    /// corners and level edges, so it isn't mistaken for a tilted page.
    nonisolated static func tiltedPageOutline(in image: UIImage) -> NormalizedQuad? {
        guard let quad = detectDocument(in: image), quad.area < 0.9 else { return nil }

        let margin: CGFloat = 0.03
        let insideCorners = quad.points.filter { point in
            point.x > margin && point.x < 1 - margin && point.y > margin && point.y < 1 - margin
        }
        guard insideCorners.count >= 2 else { return nil }

        // Measure in pixels: normalized space stretches angles by the aspect ratio.
        let size = image.size
        let p = quad.points.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }
        func angle(at index: Int) -> CGFloat {
            let a = p[(index + 3) % 4], b = p[index], c = p[(index + 1) % 4]
            let v1 = CGVector(dx: a.x - b.x, dy: a.y - b.y), v2 = CGVector(dx: c.x - b.x, dy: c.y - b.y)
            let cosine = (v1.dx * v2.dx + v1.dy * v2.dy) / (hypot(v1.dx, v1.dy) * hypot(v2.dx, v2.dy))
            return acos(min(max(cosine, -1), 1)) * 180 / .pi
        }
        let cornerSkew = (0..<4).map { abs(angle(at: $0) - 90) }.max() ?? 0
        let topEdgeTilt = abs(atan2(p[1].y - p[0].y, p[1].x - p[0].x) * 180 / .pi)
        return cornerSkew > 4 || topEdgeTilt > 3 ? quad : nil
    }
}
