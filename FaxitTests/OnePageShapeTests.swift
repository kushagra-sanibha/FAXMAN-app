import CoreGraphics
import XCTest
@testable import Faxit

/// The live border only shows for outlines shaped like one sheet of paper.
final class OnePageShapeTests: XCTestCase {
    private let aspect: CGFloat = 3.0 / 4.0 // portrait frame

    private func quad(_ p: [(CGFloat, CGFloat)]) -> NormalizedQuad {
        NormalizedQuad(
            topLeft: CGPoint(x: p[0].0, y: p[0].1), topRight: CGPoint(x: p[1].0, y: p[1].1),
            bottomRight: CGPoint(x: p[2].0, y: p[2].1), bottomLeft: CGPoint(x: p[3].0, y: p[3].1)
        )
    }

    func testLetterPageSeenWithSomePerspectiveIsAccepted() {
        // Far (top) edge a little shorter than the near one.
        let page = quad([(0.25, 0.22), (0.75, 0.22), (0.82, 0.78), (0.18, 0.78)])
        XCTAssertTrue(DocumentDetector.looksLikeOnePage(page, aspect: aspect))
    }

    func testLopsidedOutlineIsRejected() {
        // One corner dragged far off: the outline latched onto something else.
        let lopsided = quad([(0.25, 0.22), (0.75, 0.22), (0.95, 0.95), (0.18, 0.70)])
        XCTAssertFalse(DocumentDetector.looksLikeOnePage(lopsided, aspect: aspect))
    }

    func testTwoPagesSideBySideAreRejected() {
        // A notebook opened flat: wider than tall.
        let spread = quad([(0.05, 0.35), (0.95, 0.35), (0.95, 0.65), (0.05, 0.65)])
        XCTAssertFalse(DocumentDetector.looksLikeOnePage(spread, aspect: aspect))
    }

    func testThinStripIsRejected() {
        let strip = quad([(0.4, 0.05), (0.55, 0.05), (0.55, 0.95), (0.4, 0.95)])
        XCTAssertFalse(DocumentDetector.looksLikeOnePage(strip, aspect: aspect))
    }
}
