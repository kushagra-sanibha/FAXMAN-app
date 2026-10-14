import CoreGraphics
import XCTest
@testable import Faxit

final class QuadStabilizerTests: XCTestCase {
    /// A portrait page filling the middle of a 3:4 frame.
    private let page = NormalizedQuad(
        topLeft: CGPoint(x: 0.2, y: 0.15),
        topRight: CGPoint(x: 0.8, y: 0.15),
        bottomRight: CGPoint(x: 0.8, y: 0.85),
        bottomLeft: CGPoint(x: 0.2, y: 0.85)
    )

    private func makeStabilizer() -> QuadStabilizer {
        QuadStabilizer(frameAspect: 3.0 / 4.0)
    }

    private func shifted(_ quad: NormalizedQuad, by d: CGFloat) -> NormalizedQuad {
        func s(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x + d, y: p.y + d) }
        return NormalizedQuad(topLeft: s(quad.topLeft), topRight: s(quad.topRight), bottomRight: s(quad.bottomRight), bottomLeft: s(quad.bottomLeft))
    }

    func testRejectsTooSmallQuad() {
        let stabilizer = makeStabilizer()
        let tiny = NormalizedQuad(
            topLeft: CGPoint(x: 0.45, y: 0.45), topRight: CGPoint(x: 0.55, y: 0.45),
            bottomRight: CGPoint(x: 0.55, y: 0.6), bottomLeft: CGPoint(x: 0.45, y: 0.6)
        )
        stabilizer.update(with: tiny, at: 0)
        XCTAssertNil(stabilizer.quad)
    }

    func testRejectsNonConvexQuad() {
        let stabilizer = makeStabilizer()
        let bowTie = NormalizedQuad(
            topLeft: CGPoint(x: 0.2, y: 0.15), topRight: CGPoint(x: 0.8, y: 0.85),
            bottomRight: CGPoint(x: 0.8, y: 0.15), bottomLeft: CGPoint(x: 0.2, y: 0.85)
        )
        stabilizer.update(with: bowTie, at: 0)
        XCTAssertNil(stabilizer.quad)
    }

    func testRejectsImplausibleAspectRatio() {
        let stabilizer = makeStabilizer()
        // A long thin strip (a ruler, the edge of a table): about 5.6:1 in pixels.
        let thin = NormalizedQuad(
            topLeft: CGPoint(x: 0.05, y: 0.4), topRight: CGPoint(x: 0.95, y: 0.4),
            bottomRight: CGPoint(x: 0.95, y: 0.52), bottomLeft: CGPoint(x: 0.05, y: 0.52)
        )
        XCTAssertGreaterThanOrEqual(thin.area, 0.08, "big enough, so only the aspect check rejects it")
        stabilizer.update(with: thin, at: 0)
        XCTAssertNil(stabilizer.quad)
    }

    func testSmallJitterDoesNotMoveOutline() {
        let stabilizer = makeStabilizer()
        stabilizer.update(with: page, at: 0)
        // 0.5% shift: well under the 1.5% hysteresis.
        stabilizer.update(with: shifted(page, by: 0.005), at: 0.05)
        XCTAssertEqual(stabilizer.quad, page)
    }

    func testRealMovementIsSmoothedTowardTarget() {
        let stabilizer = makeStabilizer()
        stabilizer.update(with: page, at: 0)
        let target = shifted(page, by: 0.1)
        // A single sighting of a big jump is just held as a pending guess —
        // a stray misread (background clutter) must not redraw the outline.
        stabilizer.update(with: target, at: 0.05)
        XCTAssertEqual(stabilizer.quad, page, "one stray big jump doesn't move the outline yet")
        // A second, agreeing frame confirms it's real.
        stabilizer.update(with: target, at: 0.1)
        let topLeft = try! XCTUnwrap(stabilizer.quad?.topLeft)
        XCTAssertGreaterThan(topLeft.x, page.topLeft.x, "moves toward the new position")
        XCTAssertLessThan(topLeft.x, target.topLeft.x, "but not all the way in one frame")
    }

    func testHoldsOutlineThroughBriefMiss() {
        let stabilizer = makeStabilizer()
        stabilizer.update(with: page, at: 0)
        stabilizer.update(with: nil, at: 0.2)
        XCTAssertNotNil(stabilizer.quad, "kept within 300 ms")
        stabilizer.update(with: nil, at: 0.45)
        XCTAssertNil(stabilizer.quad, "dropped after 300 ms")
    }

    func testBecomesStableAfterSteadyPeriod() {
        let stabilizer = makeStabilizer()
        var time = 0.0
        while time < 0.7 {
            stabilizer.update(with: shifted(page, by: 0.003), at: time)
            time += 0.05
        }
        XCTAssertFalse(stabilizer.isStable(at: time))
        while time < 0.9 {
            stabilizer.update(with: page, at: time)
            time += 0.05
        }
        XCTAssertTrue(stabilizer.isStable(at: time))
    }

    func testModerateJitterDoesNotResetStability() {
        // Real per-frame detector noise: above the 1.5% redraw threshold
        // (so the outline keeps easing toward it) but below the 5%
        // relocation threshold. This must not block auto-capture.
        let stabilizer = makeStabilizer()
        var time = 0.0
        while time <= 1.0 {
            let d: CGFloat = Int(time / 0.05) % 2 == 0 ? 0.02 : -0.02
            stabilizer.update(with: shifted(page, by: d), at: time)
            time += 0.05
        }
        XCTAssertTrue(stabilizer.isStable(at: time))
    }

    func testMovementResetsStability() {
        let stabilizer = makeStabilizer()
        for step in 0...20 { stabilizer.update(with: page, at: Double(step) * 0.05) }
        XCTAssertTrue(stabilizer.isStable(at: 1.0))
        stabilizer.update(with: shifted(page, by: 0.1), at: 1.05)
        XCTAssertFalse(stabilizer.isStable(at: 1.05))
    }

    func testStrayBadFrameDoesNotCorruptOutline() {
        // One frame grabs a quad that includes a background edge (a stack
        // of paper behind the page), then the very next frame sees the
        // page correctly again — the outline must never have jumped to
        // the bad reading in between.
        let stabilizer = makeStabilizer()
        for step in 0...20 { stabilizer.update(with: page, at: Double(step) * 0.05) }
        let badReading = shifted(page, by: 0.2)
        stabilizer.update(with: badReading, at: 1.05)
        XCTAssertEqual(stabilizer.quad, page, "a single stray reading never redraws the outline")
        stabilizer.update(with: page, at: 1.1)
        XCTAssertEqual(stabilizer.quad, page, "and recovery doesn't leave any trace of it")
    }

    func testMissedFrameIsNotStable() {
        let stabilizer = makeStabilizer()
        for step in 0...20 { stabilizer.update(with: page, at: Double(step) * 0.05) }
        stabilizer.update(with: nil, at: 1.05)
        XCTAssertFalse(stabilizer.isStable(at: 1.05), "never 'ready' while the page isn't actually seen")
    }
}
