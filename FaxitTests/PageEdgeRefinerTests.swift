import CoreGraphics
import XCTest
@testable import Faxit

/// The outline must hug the page itself: not white table around it, not the
/// sheets underneath, and never a ruled line on the page.
final class PageEdgeRefinerTests: XCTestCase {
    private let size = CGSize(width: 480, height: 640)

    /// Draws filled quads (top-left-origin pixel points) in order, plus
    /// horizontal ruled lines, into a GrayImage.
    private func render(background: CGFloat, quads: [([CGPoint], CGFloat)], ruledLines: (x: ClosedRange<CGFloat>, ys: [CGFloat])? = nil) -> GrayImage {
        let w = Int(size.width), h = Int(size.height)
        var pixels = [UInt8](repeating: 0, count: w * h)
        pixels.withUnsafeMutableBytes { buffer in
            let context = CGContext(data: buffer.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                                    space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
            // Flip so drawing coordinates are top-left origin like GrayImage.
            context.translateBy(x: 0, y: CGFloat(h))
            context.scaleBy(x: 1, y: -1)
            context.setFillColor(gray: background, alpha: 1)
            context.fill(CGRect(origin: .zero, size: size))
            for (points, gray) in quads {
                context.setFillColor(gray: gray, alpha: 1)
                context.move(to: points[0])
                points.dropFirst().forEach { context.addLine(to: $0) }
                context.closePath()
                context.fillPath()
            }
            if let ruledLines {
                context.setFillColor(gray: 0.5, alpha: 1)
                for y in ruledLines.ys {
                    context.fill(CGRect(x: ruledLines.x.lowerBound, y: y, width: ruledLines.x.upperBound - ruledLines.x.lowerBound, height: 1.5))
                }
            }
        }
        return GrayImage(width: w, height: h, pixels: pixels)
    }

    private func normalized(_ points: [CGPoint]) -> NormalizedQuad {
        let p = points.map { CGPoint(x: $0.x / size.width, y: $0.y / size.height) }
        return NormalizedQuad(topLeft: p[0], topRight: p[1], bottomRight: p[2], bottomLeft: p[3])
    }

    private func maxCornerError(_ a: NormalizedQuad, _ b: NormalizedQuad) -> CGFloat {
        zip(a.points, b.points).map { hypot($0.x - $1.x, $0.y - $1.y) }.max()!
    }

    private let page = [CGPoint(x: 130, y: 170), CGPoint(x: 360, y: 180), CGPoint(x: 390, y: 500), CGPoint(x: 95, y: 492)]
    private var lines: (x: ClosedRange<CGFloat>, ys: [CGFloat]) { (150...340, stride(from: 210, through: 470, by: 12).map { CGFloat($0) }) }

    func testTrimsWhiteTableTheRoughOutlineTookIn() throws {
        let image = render(background: 0.9, quads: [(page, 0.97)], ruledLines: lines)
        // On a phone, Vision's outline lands within a few percent of the
        // page; here it spills about 2% onto the near-white table on every side.
        let rough = normalized([CGPoint(x: 118, y: 158), CGPoint(x: 372, y: 168), CGPoint(x: 402, y: 512), CGPoint(x: 83, y: 504)])
        let refined = try XCTUnwrap(PageEdgeRefiner.refine(rough, in: image))
        XCTAssertEqual(refined.snappedSides, 4)
        XCTAssertLessThan(maxCornerError(refined.quad, normalized(page)), 0.01)
    }

    func testPicksTopPageNotTheStackUnderneath() throws {
        let stack = [CGPoint(x: 115, y: 152), CGPoint(x: 377, y: 160), CGPoint(x: 405, y: 512), CGPoint(x: 80, y: 508)]
        let image = render(background: 0.8, quads: [(stack, 0.9), (page, 0.97)], ruledLines: lines)
        let rough = normalized(stack) // segmentation outlined the whole stack
        let refined = try XCTUnwrap(PageEdgeRefiner.refine(rough, in: image))
        XCTAssertLessThan(maxCornerError(refined.quad, normalized(page)), 0.01)
    }

    func testKeepsAnAccurateOutlineInPlace() throws {
        let image = render(background: 0.6, quads: [(page, 0.97)], ruledLines: lines)
        let refined = try XCTUnwrap(PageEdgeRefiner.refine(normalized(page), in: image))
        XCTAssertLessThan(maxCornerError(refined.quad, normalized(page)), 0.01, "doesn't jump to a ruled line")
    }

    func testNoPaperEdgeMeansNoConfidentOutline() {
        // Flat image: nothing to snap to, so it must never claim a page.
        let image = render(background: 0.9, quads: [])
        XCTAssertNil(PageEdgeRefiner.refine(normalized(page), in: image))
    }

    func testTiltedCornerIsNotClippedByANearbyCrease() throws {
        // At a tilt, a faint crease or shadow a few pixels inside the real
        // top edge can make that one side's fit land short, cutting the
        // corner, even though the other three sides fit the page cleanly.
        let w = Int(size.width), h = Int(size.height)
        var pixels = [UInt8](repeating: 0, count: w * h)
        pixels.withUnsafeMutableBytes { buffer in
            let context = CGContext(data: buffer.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                                    space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
            context.translateBy(x: 0, y: CGFloat(h))
            context.scaleBy(x: 1, y: -1)
            context.setFillColor(gray: 0.6, alpha: 1)
            context.fill(CGRect(origin: .zero, size: size))
            context.setFillColor(gray: 0.97, alpha: 1)
            context.move(to: page[0])
            page.dropFirst().forEach { context.addLine(to: $0) }
            context.closePath()
            context.fillPath()
            // A faint crease 6px inside the top edge (page[0] -> page[1]).
            context.setStrokeColor(gray: 0.7, alpha: 1)
            context.setLineWidth(3)
            context.move(to: CGPoint(x: page[0].x, y: page[0].y + 6))
            context.addLine(to: CGPoint(x: page[1].x, y: page[1].y + 6))
            context.strokePath()
        }
        let image = GrayImage(width: w, height: h, pixels: pixels)
        let refined = try XCTUnwrap(PageEdgeRefiner.refine(normalized(page), in: image))
        XCTAssertLessThan(maxCornerError(refined.quad, normalized(page)), 0.01, "the crease must not clip the corner")
    }

    func testOneMissingSideIsNotConfident() throws {
        // The page runs off the bottom of the frame: three real edges only.
        let cutOff = [CGPoint(x: 130, y: 170), CGPoint(x: 360, y: 180), CGPoint(x: 390, y: 700), CGPoint(x: 95, y: 700)]
        let image = render(background: 0.6, quads: [(cutOff, 0.97)])
        let rough = normalized([CGPoint(x: 130, y: 170), CGPoint(x: 360, y: 180), CGPoint(x: 385, y: 600), CGPoint(x: 100, y: 600)])
        let refined = try XCTUnwrap(PageEdgeRefiner.refine(rough, in: image))
        XCTAssertLessThan(refined.snappedSides, 4)
    }
}
