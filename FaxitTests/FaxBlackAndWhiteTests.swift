import UIKit
import XCTest
@testable import Faxit

/// The "Fax" filter: paper pure white, ink near-black, and letter edges kept
/// smooth (a thin gray ramp) instead of snapped to jagged black/white.
final class FaxBlackAndWhiteTests: XCTestCase {
    private let size = CGSize(width: 1000, height: 1300)
    private let stroke = CGRect(x: 100, y: 400, width: 600, height: 8)
    /// A soft edge, as a slightly out-of-focus letter has: ink to paper over 24 px.
    private let softEdge = CGRect(x: 100, y: 800, width: 24, height: 60)

    private func page() -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor(white: 0.9, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor(white: 0.15, alpha: 1).setFill()
            context.fill(stroke)
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceGray(),
                                      colors: [UIColor(white: 0.15, alpha: 1).cgColor, UIColor(white: 0.9, alpha: 1).cgColor] as CFArray,
                                      locations: [0, 1])!
            context.cgContext.saveGState()
            context.cgContext.clip(to: softEdge)
            context.cgContext.drawLinearGradient(gradient, start: CGPoint(x: softEdge.minX, y: 0), end: CGPoint(x: softEdge.maxX, y: 0), options: [])
            context.cgContext.restoreGState()
        }
    }

    /// Gray value 0…255 at a point (top-left origin).
    private func gray(_ image: UIImage, at point: CGPoint) -> UInt8 {
        let cg = image.cgImage!
        var pixel: UInt8 = 0
        let context = CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 1,
                                space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
        context.draw(cg, in: CGRect(x: -point.x, y: point.y - CGFloat(cg.height) + 1, width: CGFloat(cg.width), height: CGFloat(cg.height)))
        return pixel
    }

    private var output: UIImage {
        FaxImageProcessor.faxBlackAndWhite(page(), threshold: FaxImageProcessor.defaultFaxThreshold)
    }

    func testPaperBecomesPureWhite() {
        let output = output
        for point in [CGPoint(x: 500, y: 150), CGPoint(x: 800, y: 900), CGPoint(x: 500, y: 1200)] {
            XCTAssertGreaterThanOrEqual(gray(output, at: point), 250, "paper not white at \(point)")
        }
    }

    func testInkBecomesNearBlack() {
        XCTAssertLessThanOrEqual(gray(output, at: CGPoint(x: stroke.midX, y: stroke.midY)), 30)
    }

    func testSoftLetterEdgeKeepsAGrayRampInsteadOfAHardCut() {
        let output = output
        let values = stride(from: softEdge.minX, to: softEdge.maxX, by: 1).map { gray(output, at: CGPoint(x: $0 + 0.5, y: softEdge.midY)) }
        XCTAssertTrue(values.contains { $0 > 40 && $0 < 215 }, "edge snapped to pure black/white: \(values)")
        XCTAssertLessThanOrEqual(values.first!, 30)
        XCTAssertGreaterThanOrEqual(values.last!, 225)
    }
}
