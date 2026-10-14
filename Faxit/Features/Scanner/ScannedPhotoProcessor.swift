import UIKit

/// Turns a captured photo into a flat page, cropped to what the live border
/// showed. The page is detected again on the full-resolution photo for
/// sharper corners; that result is used only when it agrees with the live
/// border, so the capture is always the page the user saw outlined. With
/// neither, the photo is kept whole — the preview's Adjust tool can crop it.
nonisolated enum ScannedPhotoProcessor {
    /// Full-resolution corners may differ from the live border by at most
    /// this much (fraction of the frame) at any corner and still be used.
    static let agreement: CGFloat = 0.06

    /// - Parameters:
    ///   - liveQuad: the border on screen at capture, in camera-frame space.
    static func page(fromPhotoData data: Data, liveQuad: NormalizedQuad?) -> UIImage? {
        guard let photo = UIImage(data: data) else { return nil }
        let upright = FaxImageProcessor.normalized(photo)
        let aspect = upright.size.width / upright.size.height
        // The photo's own orientation, not the angle that was requested at
        // capture time — they can disagree (an unsupported rotation angle
        // silently not applied, a device turn mid-capture), and that
        // mismatch is what sends the border to the wrong spot in the
        // upright photo, cropping out a rotated-looking page.
        //
        // Both quads are also relabeled to the same canonical convention
        // (see DocumentDetector.canonicalCorners) before comparing them:
        // `choose` matches corners by position in the list, so if the two
        // happened to use different labelings for the same physical page,
        // they'd look like they disagree and the wrong one could win —
        // and whichever one is used must be canonical anyway, or the
        // flattened page comes out rotated.
        let live = liveQuad
            .map { QuarterTurn(orientation: photo.imageOrientation).toUpright($0) }
            .map { DocumentDetector.canonicalCorners(of: $0, aspect: aspect) }
        let detected = DocumentEdgeDetector.detectDocument(in: upright)
            .map { DocumentDetector.canonicalCorners(of: $0, aspect: aspect) }
        guard let quad = choose(live: live, detected: detected),
              let flattened = sharpFlattened(photo, to: quad) else {
            return upright
        }
        return flattened
    }

    /// Simulator fallback: a still image, no live border.
    static func page(from photo: UIImage) -> UIImage {
        let upright = FaxImageProcessor.normalized(photo)
        guard let quad = DocumentEdgeDetector.detectDocument(in: upright),
              let flattened = sharpFlattened(photo, to: quad) else {
            return upright
        }
        return flattened
    }

    /// Crops the page out of the photo at its **full** resolution, then caps
    /// the flattened page at fax size. Cropping the already-downscaled photo
    /// (2200 px for the whole frame) left a page that filled half the frame
    /// at ~1100 px — under fax resolution, so text came out soft and blocky
    /// once thresholded to black and white. Corners are normalized, so the
    /// quad found on the small copy maps straight onto the full photo.
    private static func sharpFlattened(_ photo: UIImage, to quad: NormalizedQuad) -> UIImage? {
        let fullResolution = FaxImageProcessor.normalized(photo, maxPixelDimension: .greatestFiniteMagnitude)
        return FaxImageProcessor.perspectiveCorrected(fullResolution, to: quad).map { FaxImageProcessor.normalized($0) }
    }

    static func choose(live: NormalizedQuad?, detected: NormalizedQuad?) -> NormalizedQuad? {
        guard let live else { return detected }
        guard let detected else { return live }
        let worst = zip(live.points, detected.points).map { hypot($0.x - $1.x, $0.y - $1.y) }.max() ?? .infinity
        return worst <= agreement ? detected : live
    }
}
