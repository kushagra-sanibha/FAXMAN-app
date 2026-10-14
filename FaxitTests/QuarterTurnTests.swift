import CoreGraphics
import ImageIO
import UIKit
import XCTest
@testable import Faxit

/// Frames are analysed upright and the result mapped back to the camera's
/// own orientation; a wrong mapping puts the outline in the wrong place.
final class QuarterTurnTests: XCTestCase {
    /// Turning the input clockwise by `quarters` and then mapping back must
    /// land on the original point.
    private func uprightPoint(of input: CGPoint, quarters: Int) -> CGPoint {
        var p = input
        for _ in 0..<quarters { p = CGPoint(x: 1 - p.y, y: p.x) } // one clockwise quarter turn
        return p
    }

    func testRoundTripForEveryRotation() {
        let input = CGPoint(x: 0.2, y: 0.7)
        for (angle, quarters) in [(0.0, 0), (90.0, 1), (180.0, 2), (270.0, 3)] {
            let turn = QuarterTurn(angle: angle)
            let upright = uprightPoint(of: input, quarters: quarters)
            let back = turn.toInput(upright)
            XCTAssertEqual(back.x, input.x, accuracy: 1e-9, "angle \(angle)")
            XCTAssertEqual(back.y, input.y, accuracy: 1e-9, "angle \(angle)")
        }
    }

    func testPortraitPhoneUsesRightOrientation() {
        // Back camera, phone held upright: the sensor frame turns 90° clockwise to look upright.
        XCTAssertEqual(QuarterTurn(angle: 90).orientation, .right)
        XCTAssertEqual(QuarterTurn(angle: 0).orientation, .up)
        XCTAssertEqual(QuarterTurn(angle: 180).orientation, .down)
        XCTAssertEqual(QuarterTurn(angle: 270).orientation, .left)
    }

    func testOrientationInitRoundTripsWithAngleInit() {
        // The photo's own orientation must land on the same quarter-turn as
        // the angle that was supposed to produce it — this is what lets
        // ScannedPhotoProcessor trust the photo over a possibly-stale angle.
        let cases: [(CGFloat, UIImage.Orientation)] = [(0, .up), (90, .right), (180, .down), (270, .left)]
        for (angle, orientation) in cases {
            XCTAssertEqual(QuarterTurn(angle: angle).quarters, QuarterTurn(orientation: orientation).quarters, "angle \(angle)")
        }
    }

    func testUprightTopLeftIsSensorBottomLeftInPortrait() {
        // The top-left of what the user sees is the sensor's bottom-left.
        XCTAssertEqual(QuarterTurn(angle: 90).toInput(CGPoint(x: 0, y: 0)), CGPoint(x: 0, y: 1))
    }

    /// The live border (camera frame) must land on the same spot in the
    /// upright photo, or the capture is cropped in the wrong place.
    func testToUprightUndoesToInputForEveryRotation() {
        let upright = CGPoint(x: 0.2, y: 0.7)
        for angle in [0.0, 90, 180, 270] {
            let turn = QuarterTurn(angle: angle)
            let back = turn.toUpright(turn.toInput(upright))
            XCTAssertEqual(back.x, upright.x, accuracy: 1e-9, "angle \(angle)")
            XCTAssertEqual(back.y, upright.y, accuracy: 1e-9, "angle \(angle)")
        }
    }

    /// Sharper full-resolution corners are used only when they agree with
    /// the border the user saw; otherwise the border wins.
    func testCaptureUsesBorderUnlessDetectionAgrees() {
        let live = NormalizedQuad(
            topLeft: CGPoint(x: 0.2, y: 0.1), topRight: CGPoint(x: 0.8, y: 0.1),
            bottomRight: CGPoint(x: 0.8, y: 0.9), bottomLeft: CGPoint(x: 0.2, y: 0.9)
        )
        let close = NormalizedQuad(
            topLeft: CGPoint(x: 0.21, y: 0.11), topRight: CGPoint(x: 0.79, y: 0.1),
            bottomRight: CGPoint(x: 0.8, y: 0.89), bottomLeft: CGPoint(x: 0.2, y: 0.9)
        )
        let elsewhere = NormalizedQuad(
            topLeft: CGPoint(x: 0.0, y: 0.0), topRight: CGPoint(x: 0.5, y: 0.0),
            bottomRight: CGPoint(x: 0.5, y: 0.5), bottomLeft: CGPoint(x: 0.0, y: 0.5)
        )
        XCTAssertEqual(ScannedPhotoProcessor.choose(live: live, detected: close), close)
        XCTAssertEqual(ScannedPhotoProcessor.choose(live: live, detected: elsewhere), live)
        XCTAssertEqual(ScannedPhotoProcessor.choose(live: live, detected: nil), live)
        XCTAssertEqual(ScannedPhotoProcessor.choose(live: nil, detected: close), close)
    }
}
