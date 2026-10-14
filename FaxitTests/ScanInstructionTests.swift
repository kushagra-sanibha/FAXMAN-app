import CoreGraphics
import XCTest
@testable import Faxit

final class ScanInstructionTests: XCTestCase {
    private let aspect: CGFloat = 3.0 / 4.0

    private func quad(_ minX: CGFloat, _ minY: CGFloat, _ maxX: CGFloat, _ maxY: CGFloat) -> NormalizedQuad {
        NormalizedQuad(
            topLeft: CGPoint(x: minX, y: minY), topRight: CGPoint(x: maxX, y: minY),
            bottomRight: CGPoint(x: maxX, y: maxY), bottomLeft: CGPoint(x: minX, y: maxY)
        )
    }

    private var wellPlaced: NormalizedQuad { quad(0.15, 0.1, 0.85, 0.9) }

    private func evaluate(_ quad: NormalizedQuad?, stable: Bool = true) -> ScanInstruction {
        ScanInstruction.evaluate(quad: quad, frameAspect: aspect, isStable: stable)
    }

    func testNoPage() {
        XCTAssertEqual(evaluate(nil), .findPage)
    }

    func testModerateAngleIsCapturedBecauseItIsFlattened() {
        // Photographed at an angle: corners about 19° off square.
        let angled = NormalizedQuad(
            topLeft: CGPoint(x: 0.4, y: 0.2), topRight: CGPoint(x: 0.6, y: 0.2),
            bottomRight: CGPoint(x: 0.9, y: 0.85), bottomLeft: CGPoint(x: 0.1, y: 0.85)
        )
        XCTAssertEqual(evaluate(angled, stable: true), .ready)
    }

    func testExtremeAngleIsNeverAutoCaptured() {
        // Far edge a fraction of the near one: corners well past 25° off square.
        let extreme = NormalizedQuad(
            topLeft: CGPoint(x: 0.45, y: 0.3), topRight: CGPoint(x: 0.55, y: 0.3),
            bottomRight: CGPoint(x: 0.95, y: 0.9), bottomLeft: CGPoint(x: 0.05, y: 0.9)
        )
        XCTAssertEqual(evaluate(extreme, stable: true), .holdFlat)
    }

    func testSlightPerspectiveIsStillAccepted() {
        let nearlyFlat = NormalizedQuad(
            topLeft: CGPoint(x: 0.17, y: 0.1), topRight: CGPoint(x: 0.83, y: 0.1),
            bottomRight: CGPoint(x: 0.86, y: 0.9), bottomLeft: CGPoint(x: 0.14, y: 0.9)
        )
        XCTAssertEqual(evaluate(nearlyFlat), .ready)
    }

    func testCutOffPageIsNotCaptured() {
        XCTAssertEqual(evaluate(quad(0, 0.1, 0.85, 0.9)), .fitCorners)
    }

    func testDistantPageIsNotCaptured() {
        XCTAssertEqual(evaluate(quad(0.35, 0.35, 0.65, 0.65)), .moveCloser)
    }

    func testWellPlacedButMovingWaits() {
        XCTAssertEqual(evaluate(wellPlaced, stable: false), .holdSteady)
    }

    func testWellPlacedAndSteadyIsReady() {
        XCTAssertEqual(evaluate(wellPlaced), .ready)
    }
}
