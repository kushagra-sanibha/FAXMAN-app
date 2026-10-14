import CoreGraphics
import XCTest
@testable import Faxit

/// Vision's own corner labels for a detected rectangle aren't guaranteed to
/// match "as seen by the user" — trusting a wrong label sends perspective
/// correction's output out rotated 90°/180° from how the page was actually
/// held, even though the four points describe the right region.
final class DocumentDetectorCanonicalCornersTests: XCTestCase {
    private let aspect: CGFloat = 3.0 / 4.0 // portrait frame

    private func quad(_ p: [(CGFloat, CGFloat)]) -> NormalizedQuad {
        NormalizedQuad(
            topLeft: CGPoint(x: p[0].0, y: p[0].1), topRight: CGPoint(x: p[1].0, y: p[1].1),
            bottomRight: CGPoint(x: p[2].0, y: p[2].1), bottomLeft: CGPoint(x: p[3].0, y: p[3].1)
        )
    }

    func testWellLabeledQuadIsUnchanged() {
        let page = quad([(0.2, 0.15), (0.8, 0.15), (0.8, 0.85), (0.2, 0.85)])
        XCTAssertEqual(DocumentDetector.canonicalCorners(of: page, aspect: aspect), page)
    }

    func testLabelsRotatedOneStepAreCorrected() {
        // Same four physical corners as the well-labeled page above, but
        // Vision called the real top-left corner "topRight" instead (and so
        // on around) — a page sitting upright but reported sideways.
        let trueCorners: [(CGFloat, CGFloat)] = [(0.2, 0.15), (0.8, 0.15), (0.8, 0.85), (0.2, 0.85)]
        let mislabeled = quad([trueCorners[3], trueCorners[0], trueCorners[1], trueCorners[2]])
        let fixed = DocumentDetector.canonicalCorners(of: mislabeled, aspect: aspect)
        XCTAssertEqual(fixed, quad(trueCorners))
    }

    func testLabelsRotated180AreCorrected() {
        let trueCorners: [(CGFloat, CGFloat)] = [(0.2, 0.15), (0.8, 0.15), (0.8, 0.85), (0.2, 0.85)]
        let upsideDown = quad([trueCorners[2], trueCorners[3], trueCorners[0], trueCorners[1]])
        let fixed = DocumentDetector.canonicalCorners(of: upsideDown, aspect: aspect)
        XCTAssertEqual(fixed, quad(trueCorners))
    }

    func testModeratelyTiltedPageIsNotFlipped() {
        // A real, moderately tilted page (well within the live scanner's
        // 25° auto-capture limit) must not be "corrected" into some other
        // rotation just because it isn't perfectly horizontal.
        let tilted = quad([(0.22, 0.2), (0.78, 0.12), (0.85, 0.8), (0.2, 0.86)])
        XCTAssertEqual(DocumentDetector.canonicalCorners(of: tilted, aspect: aspect), tilted)
    }
}
