import UIKit

/// Where a page came from. Every source gets the exact same editing tools;
/// this only picks sensible defaults (e.g. the crop tool auto-detects the
/// paper's edges on photos, while scans are already perspective-corrected
/// by VisionKit and PDF pages are already flat).
nonisolated enum PageSource: String, Codable, Sendable {
    case scan
    case photo
    case imageFile
    case pdf
    case coverPage

    var suggestsEdgeDetection: Bool {
        self == .photo || self == .imageFile
    }
}

/// One fax page with non-destructive edits.
///
/// `baseImage` is the full-color page with geometric edits (crop, rotate)
/// committed into it; `filter` and `tone` are kept as settings and
/// re-applied on top of it, producing `image` — the exact pixels that get
/// previewed, saved and sent. Previously crop/rotate were applied to the
/// already-filtered image and then overwrote the original, so after one
/// rotate "Color" could never bring the color back.
struct ScannedPage: Identifiable, Equatable {
    let id: UUID
    let source: PageSource
    private(set) var baseImage: UIImage
    private(set) var filter: PageFilter
    private(set) var tone: ToneAdjustment
    /// The "Fax" filter's Lighter/Darker setting (see FaxImageProcessor.faxBlackAndWhite).
    private(set) var faxThreshold: Double
    /// Rendered output — always `filter(tone(baseImage))`.
    private(set) var image: UIImage
    private(set) var brightnessIssue: BrightnessIssue?
    /// "Keep as is" on the amber warning.
    private(set) var isWarningDismissed: Bool
    /// A scan that came back at an angle is straightened automatically; this
    /// keeps the page as captured so "Undo" can restore it. Any later
    /// geometry edit (crop, rotate, signature) commits the straightening.
    private(set) var unstraightenedBase: UIImage?
    /// Set when a tilted page was detected but couldn't be straightened
    /// automatically; the preview then offers Adjust. Cleared by geometry edits.
    private(set) var tiltCorrection: NormalizedQuad?
    private(set) var isTiltWarningDismissed = false
    /// Bumped on every edit. `==` compares this too: comparing only `id`
    /// told SwiftUI an edited page was unchanged, so views holding pages
    /// skipped redraws after a crop/filter.
    private(set) var revision: Int = 0

    /// Pages imported together — one PDF file, one scan session, or one
    /// photo-picker selection — share a documentID and documentName so the
    /// home screen can group and label them as a single document.
    var documentID: UUID
    var documentName: String

    nonisolated init(
        id: UUID = UUID(),
        baseImage: UIImage,
        source: PageSource,
        filter: PageFilter = .blackAndWhite,
        tone: ToneAdjustment = .none,
        faxThreshold: Double = FaxImageProcessor.defaultFaxThreshold,
        isWarningDismissed: Bool = false,
        documentID: UUID = UUID(),
        documentName: String = "Document",
        // Outline of a scan that came back at an angle (see
        // DocumentEdgeDetector.tiltedPageOutline); straightened here.
        detectedTilt: NormalizedQuad? = nil
    ) {
        var base = FaxImageProcessor.normalized(baseImage)
        var unstraightened: UIImage?
        var unresolvedTilt: NormalizedQuad?
        if let detectedTilt {
            if let corrected = FaxImageProcessor.perspectiveCorrected(base, to: detectedTilt) {
                unstraightened = base
                base = corrected
            } else {
                unresolvedTilt = detectedTilt
            }
        }
        let rendered = Self.render(base, filter: filter, tone: tone, faxThreshold: faxThreshold)
        self.id = id
        self.source = source
        self.baseImage = base
        self.filter = filter
        self.tone = tone
        self.faxThreshold = faxThreshold
        self.image = rendered
        self.brightnessIssue = BrightnessAnalyzer.issue(in: rendered)
        self.isWarningDismissed = isWarningDismissed
        self.documentID = documentID
        self.documentName = documentName
        self.unstraightenedBase = unstraightened
        self.tiltCorrection = unresolvedTilt
    }

    var isFlaggedDarkOrLight: Bool { brightnessIssue != nil && !isWarningDismissed }

    /// "Straightened automatically · Undo" in the preview.
    var showsStraightenedNotice: Bool { unstraightenedBase != nil }

    var isFlaggedTilted: Bool { tiltCorrection != nil && !isTiltWarningDismissed }

    /// The scanner returned this page at an angle (fixed or not).
    var wasCapturedTilted: Bool { unstraightenedBase != nil || tiltCorrection != nil }

    static func == (lhs: ScannedPage, rhs: ScannedPage) -> Bool {
        lhs.id == rhs.id && lhs.revision == rhs.revision
    }

    // MARK: - Edits

    mutating func setFilter(_ newFilter: PageFilter) {
        guard newFilter != filter else { return }
        filter = newFilter
        rerender()
    }

    mutating func setFaxThreshold(_ threshold: Double) {
        let clamped = min(max(threshold, FaxImageProcessor.faxThresholdRange.lowerBound), FaxImageProcessor.faxThresholdRange.upperBound)
        guard clamped != faxThreshold else { return }
        faxThreshold = clamped
        rerender()
    }

    /// Rotation is lossless, so the rendered output is rotated directly
    /// instead of re-running every filter.
    mutating func rotate(_ direction: FaxImageProcessor.RotationDirection) {
        baseImage = FaxImageProcessor.rotated(baseImage, direction)
        image = FaxImageProcessor.rotated(image, direction)
        tiltCorrection = nil
        unstraightenedBase = nil
        revision += 1
    }

    /// Returns false (and leaves the page untouched) for an invalid quad.
    @discardableResult
    mutating func crop(to quad: NormalizedQuad) -> Bool {
        guard quad != .fullImage else { return true }
        guard let corrected = FaxImageProcessor.perspectiveCorrected(baseImage, to: quad) else { return false }
        baseImage = corrected
        tiltCorrection = nil
        unstraightenedBase = nil
        rerender()
        return true
    }

    /// Puts the page back exactly as the scanner captured it.
    mutating func undoStraighten() {
        guard let unstraightenedBase else { return }
        baseImage = unstraightenedBase
        self.unstraightenedBase = nil
        rerender()
    }

    /// Keeps the straightened page and frees the captured original.
    mutating func acceptStraighten() {
        unstraightenedBase = nil
        revision += 1
    }

    mutating func dismissTiltWarning() {
        isTiltWarningDismissed = true
        revision += 1
    }

    /// Burns the signature into the base image, so later crops, rotations
    /// and filter changes treat it as part of the page.
    mutating func addSignature(_ signature: UIImage, in normalizedRect: CGRect) {
        baseImage = FaxImageProcessor.stamped(baseImage, with: signature, in: normalizedRect)
        unstraightenedBase = nil
        rerender()
    }

    /// The amber warning's fix: brighten a dark page, darken a washed-out one.
    mutating func fixBrightness() {
        guard let brightnessIssue else { return }
        tone = brightnessIssue.fix
        rerender()
    }

    /// True once the fix for the current issue is already applied — the
    /// warning then only offers "Keep as is" instead of repeating a no-op.
    var canFixBrightness: Bool {
        guard let brightnessIssue else { return false }
        return tone != brightnessIssue.fix
    }

    mutating func dismissWarning() {
        isWarningDismissed = true
        revision += 1
    }

    private mutating func rerender() {
        image = Self.render(baseImage, filter: filter, tone: tone, faxThreshold: faxThreshold)
        brightnessIssue = BrightnessAnalyzer.issue(in: image)
        revision += 1
    }

    private nonisolated static func render(_ base: UIImage, filter: PageFilter, tone: ToneAdjustment, faxThreshold: Double) -> UIImage {
        filter.apply(to: tone.apply(to: base), faxThreshold: faxThreshold)
    }
}
