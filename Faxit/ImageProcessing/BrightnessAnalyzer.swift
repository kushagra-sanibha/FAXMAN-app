import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

/// Why a page got the amber warning — decides both the message and which
/// one-tap fix is offered (brighten vs. darken).
nonisolated enum BrightnessIssue: String, Codable, Sendable {
    case tooDark
    case tooLight

    var fix: ToneAdjustment {
        switch self {
        case .tooDark: .brightened
        case .tooLight: .darkened
        }
    }
}

/// Flags pages outside a readable luminance band with the amber warning —
/// a warning only, it never blocks sending.
enum BrightnessAnalyzer {
    /// Color management off: histogram bins are the image's encoded sRGB
    /// values, i.e. perceptual brightness. The previous version read the
    /// average back in Core Image's *linear* working space, where a
    /// perfectly normal mid-gray (sRGB 0.5) reads as ~0.21, so ordinary
    /// photos were being flagged as too dark.
    private nonisolated static let context = CIContext(options: [
        .workingColorSpace: NSNull(),
        .outputColorSpace: NSNull(),
        .cacheIntermediates: false
    ])

    private nonisolated static let binCount = 64
    private nonisolated static let analysisMaxDimension: CGFloat = 1024

    /// Mean perceptual brightness below this reads as an underexposed page.
    nonisolated static let darkMeanThreshold: Double = 0.38
    /// A pixel this dark or darker counts as "ink".
    nonisolated static let inkLevel: Double = 0.55
    /// A page with less ink than this fraction of its area is blank or so
    /// washed out the fax machine will print nothing legible. (Only looking
    /// at the average, as before, flagged every clean digital PDF — a
    /// sparse text page legitimately averages above 0.95.)
    nonisolated static let minimumInkFraction: Double = 0.0015

    nonisolated static func issue(in image: UIImage) -> BrightnessIssue? {
        guard let histogram = luminanceHistogram(of: image) else { return nil }
        let total = histogram.reduce(0, +)
        guard total > 0 else { return nil }

        var mean = 0.0
        var inkFraction = 0.0
        for (bin, weight) in histogram.enumerated() {
            let level = (Double(bin) + 0.5) / Double(binCount)
            mean += level * weight / total
            if level <= inkLevel { inkFraction += weight / total }
        }

        if mean < darkMeanThreshold { return .tooDark }
        if inkFraction < minimumInkFraction { return .tooLight }
        return nil
    }

    private nonisolated static func luminanceHistogram(of image: UIImage) -> [Double]? {
        guard var ciImage = FaxImageProcessor.ciImage(from: image) else { return nil }
        let longest = max(ciImage.extent.width, ciImage.extent.height)
        guard longest > 0 else { return nil }
        if longest > analysisMaxDimension {
            let scale = analysisMaxDimension / longest
            ciImage = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        }

        let gray = CIFilter.colorControls()
        gray.inputImage = ciImage
        gray.saturation = 0

        let histogram = CIFilter.areaHistogram()
        histogram.inputImage = gray.outputImage
        histogram.extent = ciImage.extent
        histogram.count = binCount
        histogram.scale = 1
        guard let output = histogram.outputImage else { return nil }

        var bitmap = [Float](repeating: 0, count: binCount * 4)
        context.render(
            output,
            toBitmap: &bitmap,
            rowBytes: binCount * 4 * MemoryLayout<Float>.size,
            bounds: CGRect(x: 0, y: 0, width: binCount, height: 1),
            format: .RGBAf,
            colorSpace: nil
        )
        // Grayscale input: R == G == B, so the red channel is the histogram.
        return stride(from: 0, to: bitmap.count, by: 4).map { Double(bitmap[$0]) }
    }
}
