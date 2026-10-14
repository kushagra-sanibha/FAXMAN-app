import CoreImage
import CoreImage.CIFilterBuiltins
import ImageIO
import UIKit
import UniformTypeIdentifiers

/// On-device conversion to the faithful black-and-white rendering shown in
/// the Review preview — this is meant to represent exactly what the
/// recipient's fax machine will print, not a cosmetic filter.
///
/// Every function here is `nonisolated` and pure (image in, image out) so
/// the import pipeline can run it off the main actor, and every output is
/// an `.up`-oriented bitmap so later geometry edits never have to reason
/// about EXIF orientation again.
enum FaxImageProcessor {
    private nonisolated static let context = CIContext(options: [.cacheIntermediates: false])

    /// Fine fax resolution is ~200 dpi; a US Letter page at 200 dpi is
    /// 1700 × 2200 px. Anything bigger is wasted memory (a 48 MP photo is
    /// ~190 MB decoded) and makes every edit slower without improving what
    /// the recipient's machine prints.
    nonisolated static let faxDPI: CGFloat = 200
    nonisolated static let maxPixelDimension: CGFloat = 11 * faxDPI

    // MARK: - Normalization

    /// Bakes in the UIImage's orientation and caps its size. Photos from the
    /// camera roll and Files often carry EXIF orientation (`.right` etc.)
    /// with sideways raw pixels; Core Image ignores that metadata, so without
    /// this every filter/crop on an uploaded photo came out rotated.
    nonisolated static func normalized(_ image: UIImage, maxPixelDimension: CGFloat = maxPixelDimension) -> UIImage {
        let pixelSize = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        let longest = max(pixelSize.width, pixelSize.height)
        guard longest > 0 else { return image }
        let factor = min(1, maxPixelDimension / longest)
        if image.imageOrientation == .up, factor == 1, image.cgImage != nil { return image }

        let target = CGSize(width: (pixelSize.width * factor).rounded(), height: (pixelSize.height * factor).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: target, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: target))
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }

    /// Decodes an image file straight to a capped, orientation-applied
    /// bitmap via ImageIO — never decodes the full-size original first.
    nonisolated static func downsampledImage(at url: URL, maxPixelDimension: CGFloat = maxPixelDimension) -> UIImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary) else { return nil }
        return downsampledImage(from: source, maxPixelDimension: maxPixelDimension)
    }

    nonisolated static func downsampledImage(from data: Data, maxPixelDimension: CGFloat = maxPixelDimension) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary) else { return nil }
        return downsampledImage(from: source, maxPixelDimension: maxPixelDimension)
    }

    private nonisolated static func downsampledImage(from source: CGImageSource, maxPixelDimension: CGFloat) -> UIImage? {
        guard CGImageSourceGetCount(source) > 0 else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(maxPixelDimension)
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        // Flatten onto white: transparent PNGs would otherwise turn black
        // once the fax filter drops the alpha channel.
        return normalized(flattenedOnWhite(UIImage(cgImage: cgImage)))
    }

    private nonisolated static func flattenedOnWhite(_ image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        switch cgImage.alphaInfo {
        case .none, .noneSkipFirst, .noneSkipLast: return image
        default: break
        }
        let size = CGSize(width: cgImage.width, height: cgImage.height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    // MARK: - Filters

    /// The default "Fax" level, which is also the lightest: pages start
    /// light, and the slider only darkens from here.
    nonisolated static let defaultFaxThreshold: Double = 0.65
    /// Upper end stays below 1 − `faxRampHalfWidth` so paper always stays white.
    nonisolated static let faxThresholdRange: ClosedRange<Double> = defaultFaxThreshold...0.82

    /// Fax look: grayscale → even out shadows and uneven light → a steep
    /// tone curve. Lighting is evened out by dividing by a background
    /// estimate (text erased with a max filter, then heavily blurred on a
    /// small copy), so a shadowed corner turns white instead of black.
    ///
    /// The curve makes paper pure white and ink black but keeps a thin gray
    /// ramp at letter edges (like other scanner apps' B&W), so pen strokes
    /// stay thin, smooth and natural. It works on perceived brightness:
    /// done in linear light, the faint blur just outside every stroke counted
    /// as dark and strokes came out fat and heavy. The ramp is centered on
    /// `threshold`. Pages are still sent as pure black and white, converted
    /// at fax resolution (oneBitPNGData). Higher `threshold` = darker.
    nonisolated static func faxBlackAndWhite(_ image: UIImage, threshold: Double) -> UIImage {
        guard let input = ciImage(from: image) else { return image }
        let gray = input.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0])
        let extent = gray.extent
        let scale = min(1, 400 / max(extent.width, extent.height))
        let small = gray.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let background = small.clampedToExtent()
            .applyingFilter("CIMorphologyMaximum", parameters: [kCIInputRadiusKey: 4])
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 10])
            .cropped(to: small.extent)
            .transformed(by: CGAffineTransform(scaleX: 1 / scale, y: 1 / scale))
            .cropped(to: extent)
        // CIDivideBlendMode outputs background ÷ input, so the page goes in as the background.
        let evened = background.applyingFilter("CIDivideBlendMode", parameters: [kCIInputBackgroundImageKey: gray])
        let contrasted = evened.applyingFilter("CIColorControls", parameters: [kCIInputContrastKey: 1.1])
        // Ramp from `ink` (black) to `paper` (white) on perceived brightness, clamped.
        let ink = threshold - faxRampHalfWidth, paper = threshold + faxRampHalfWidth
        let gain = 1 / (paper - ink)
        let ramped = contrasted
            .applyingFilter("CILinearToSRGBToneCurve")
            .applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: gain, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: gain, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: gain, w: 0),
                "inputBiasVector": CIVector(x: -ink * gain, y: -ink * gain, z: -ink * gain, w: 0)
            ])
            .applyingFilter("CIColorClamp")
            .applyingFilter("CISRGBToneCurveToLinear")
        return render(ramped.cropped(to: extent), fallback: image)
    }

    /// Half the width of the gray ramp at letter edges. At the default level
    /// the ramp runs 0.55 → 0.75: stroke cores black, paper white, edges
    /// smooth, and stroke width close to the real pen's.
    nonisolated static let faxRampHalfWidth: Double = 0.10

    /// Desaturates without the fax contrast boost — the softer "Grayscale" option.
    nonisolated static func desaturated(_ image: UIImage) -> UIImage {
        colorControls(image, saturation: 0, brightness: 0, contrast: 1.0)
    }

    // MARK: - Fax page output

    /// The page as transmitted: fitted onto a standard fax page at 200 dpi,
    /// centered on white with its aspect ratio kept. Landscape pages are
    /// turned to portrait first, since fax machines print portrait.
    nonisolated static func faxPage(_ image: UIImage, paper: FaxPaperSize) -> UIImage {
        let page = image.size.width > image.size.height ? rotated(image, .clockwise) : image
        let canvas = paper.pixelSize
        let fit = min(canvas.width / page.size.width, canvas.height / page.size.height)
        let drawn = CGSize(width: page.size.width * fit, height: page.size.height * fit)
        let origin = CGPoint(x: (canvas.width - drawn.width) / 2, y: (canvas.height - drawn.height) / 2)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: canvas, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: canvas))
            // Smooth resampling, so a black-and-white page's letter edges
            // stay clean when fitted to the fax page (then re-thresholded).
            context.cgContext.interpolationQuality = .high
            page.draw(in: CGRect(origin: origin, size: drawn))
        }
    }

    /// A pure black-and-white page as a 1-bit PNG — a fraction of the size
    /// of a JPEG and with no compression smudges on text.
    nonisolated static func oneBitPNGData(_ image: UIImage) -> Data? {
        guard let cgImage = image.cgImage else { return nil }
        let width = cgImage.width, height = cgImage.height
        var gray = [UInt8](repeating: 0, count: width * height)
        let drew = gray.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
                space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else { return false }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drew else { return nil }

        let rowBytes = (width + 7) / 8
        var packed = [UInt8](repeating: 0, count: rowBytes * height)
        for y in 0..<height {
            for x in 0..<width where gray[y * width + x] >= 128 {
                packed[y * rowBytes + x / 8] |= 0x80 >> UInt8(x % 8)
            }
        }
        guard let provider = CGDataProvider(data: Data(packed) as CFData),
              let oneBit = CGImage(
                width: width, height: height, bitsPerComponent: 1, bitsPerPixel: 1, bytesPerRow: rowBytes,
                space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: 0), provider: provider,
                decode: nil, shouldInterpolate: false, intent: .defaultIntent
              ) else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, oneBit, nil)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }

    /// Applied from the amber warning's fix action on a too-dark page.
    nonisolated static func brightened(_ image: UIImage) -> UIImage {
        colorControls(image, saturation: 1, brightness: 0.25, contrast: 1.05)
    }

    /// Applied from the amber warning's fix action on a washed-out page —
    /// pulls faint strokes back toward black so they survive fax transmission.
    nonisolated static func darkened(_ image: UIImage) -> UIImage {
        guard let ciImage = ciImage(from: image) else { return image }
        let exposure = CIFilter.exposureAdjust()
        exposure.inputImage = ciImage
        exposure.ev = -0.7
        let contrast = CIFilter.colorControls()
        contrast.inputImage = exposure.outputImage
        contrast.contrast = 1.35
        return render(contrast.outputImage, fallback: image)
    }

    private nonisolated static func colorControls(_ image: UIImage, saturation: Float, brightness: Float, contrast: Float) -> UIImage {
        guard let ciImage = ciImage(from: image) else { return image }
        let filter = CIFilter.colorControls()
        filter.inputImage = ciImage
        filter.saturation = saturation
        filter.brightness = brightness
        filter.contrast = contrast
        return render(filter.outputImage, fallback: image)
    }

    // MARK: - Geometry

    /// Warps the selected quadrilateral into a straightened rectangle —
    /// the same correction the system document scanner applies. Returns nil
    /// for a degenerate (non-convex / zero-area) selection.
    nonisolated static func perspectiveCorrected(_ image: UIImage, to quad: NormalizedQuad) -> UIImage? {
        guard quad.isValid, let ciImage = ciImage(from: image) else { return nil }
        if quad == .fullImage { return image }

        // NormalizedQuad is top-left-origin unit space; Core Image is
        // bottom-left-origin pixel space.
        let extent = ciImage.extent
        func pixelPoint(_ point: CGPoint) -> CGPoint {
            CGPoint(x: extent.minX + point.x * extent.width, y: extent.minY + (1 - point.y) * extent.height)
        }

        let filter = CIFilter.perspectiveCorrection()
        filter.inputImage = ciImage
        filter.topLeft = pixelPoint(quad.topLeft)
        filter.topRight = pixelPoint(quad.topRight)
        filter.bottomLeft = pixelPoint(quad.bottomLeft)
        filter.bottomRight = pixelPoint(quad.bottomRight)
        guard let output = filter.outputImage, output.extent.width >= 1, output.extent.height >= 1,
              let cgImage = context.createCGImage(output, from: output.extent.integral) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    enum RotationDirection: Sendable {
        case clockwise, counterclockwise
    }

    /// Lossless quarter-turn. Renders at the source's own scale — the
    /// renderer's default (screen scale) silently tripled the pixel
    /// dimensions on every rotate. Keeps transparency (signatures) intact.
    nonisolated static func rotated(_ image: UIImage, _ direction: RotationDirection) -> UIImage {
        let newSize = CGSize(width: image.size.height, height: image.size.width)
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = !hasAlpha(image)
        return UIGraphicsImageRenderer(size: newSize, format: format).image { context in
            let cg = context.cgContext
            switch direction {
            case .clockwise:
                cg.translateBy(x: newSize.width, y: 0)
                cg.rotate(by: .pi / 2)
            case .counterclockwise:
                cg.translateBy(x: 0, y: newSize.height)
                cg.rotate(by: -.pi / 2)
            }
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    private nonisolated static func hasAlpha(_ image: UIImage) -> Bool {
        guard let alphaInfo = image.cgImage?.alphaInfo else { return false }
        switch alphaInfo {
        case .none, .noneSkipFirst, .noneSkipLast: return false
        default: return true
        }
    }

    /// Draws `overlay` (e.g. a transparent signature) onto `image` inside
    /// `normalizedRect` (0...1, top-left origin), at the page's own scale.
    nonisolated static func stamped(_ image: UIImage, with overlay: UIImage, in normalizedRect: CGRect) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = true
        return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
            let rect = CGRect(
                x: normalizedRect.minX * image.size.width,
                y: normalizedRect.minY * image.size.height,
                width: normalizedRect.width * image.size.width,
                height: normalizedRect.height * image.size.height
            )
            overlay.draw(in: rect)
        }
    }

    /// Turns a scanned/photographed signature into black ink on a
    /// transparent background, trimmed to the ink. The paper's brightness
    /// is measured from the image itself, so uneven lighting still
    /// separates ink from paper. Nil when no plausible signature is found.
    nonisolated static func signatureCutout(from image: UIImage, maxPixelDimension: CGFloat = 1500) -> UIImage? {
        guard let cgImage = normalized(image, maxPixelDimension: maxPixelDimension).cgImage else { return nil }
        let width = cgImage.width
        let height = cgImage.height
        let pixelCount = width * height
        guard pixelCount > 0 else { return nil }

        var gray = [UInt8](repeating: 0, count: pixelCount)
        let didDraw = gray.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
                space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else { return false }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard didDraw else { return nil }

        // Paper level = 90th-percentile brightness: robust to the ink itself
        // and to shadows.
        var histogram = [Int](repeating: 0, count: 256)
        for value in gray { histogram[Int(value)] += 1 }
        var paperLevel = 255
        var brighter = 0
        for level in stride(from: 255, through: 0, by: -1) {
            brighter += histogram[level]
            if brighter >= pixelCount / 10 {
                paperLevel = level
                break
            }
        }
        // Fully ink below `inkLevel`, fully clear above `clearLevel`, soft
        // edge in between so strokes stay smooth.
        let inkLevel = Double(paperLevel) * 0.55
        let clearLevel = Double(paperLevel) * 0.75
        guard clearLevel - inkLevel >= 8 else { return nil }

        // Scans often keep a dark sliver of background at the edges.
        let marginX = width / 50
        let marginY = height / 50
        var rgba = [UInt8](repeating: 0, count: pixelCount * 4)
        var inkPixels = 0
        var minX = width, minY = height, maxX = -1, maxY = -1
        for y in marginY..<(height - marginY) {
            for x in marginX..<(width - marginX) {
                let value = Double(gray[y * width + x])
                guard value < clearLevel else { continue }
                let alpha = value <= inkLevel ? 1 : (clearLevel - value) / (clearLevel - inkLevel)
                // Black ink, premultiplied: only alpha is non-zero.
                rgba[(y * width + x) * 4 + 3] = UInt8(alpha * 255)
                if alpha > 0.5 {
                    inkPixels += 1
                    minX = min(minX, x)
                    maxX = max(maxX, x)
                    minY = min(minY, y)
                    maxY = max(maxY, y)
                }
            }
        }
        // Too little ink = blank paper; too much = not a signature on paper.
        guard inkPixels >= pixelCount / 5000, inkPixels <= pixelCount * 2 / 5, maxX >= minX else { return nil }

        let fullImage: CGImage? = rgba.withUnsafeMutableBytes { buffer in
            CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )?.makeImage()
        }
        let padding = 8
        let inkBounds = CGRect(
            x: max(minX - padding, 0),
            y: max(minY - padding, 0),
            width: min(maxX + padding, width - 1) - max(minX - padding, 0) + 1,
            height: min(maxY + padding, height - 1) - max(minY - padding, 0) + 1
        )
        guard let trimmed = fullImage?.cropping(to: inkBounds) else { return nil }
        return UIImage(cgImage: trimmed)
    }

    // MARK: - Fingerprint

    /// A tiny grayscale thumbnail's bytes — identical page content yields
    /// identical bytes regardless of page IDs, so duplicate-send detection
    /// works even when the same file is re-imported.
    nonisolated static func fingerprint(of image: UIImage) -> Data {
        let side = 16
        var pixels = [UInt8](repeating: 0, count: side * side)
        guard let cgImage = image.cgImage,
              let context = CGContext(
                data: &pixels, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side,
                space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue
              ) else { return Data() }
        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))
        // Quantize so JPEG round-trips (drafts) don't change the fingerprint.
        return Data(pixels.map { $0 / 32 })
    }

    // MARK: - Helpers

    /// Orientation-correct CIImage — `CIImage(image:)` alone ignores
    /// `imageOrientation`.
    nonisolated static func ciImage(from image: UIImage) -> CIImage? {
        if let cgImage = image.cgImage {
            return CIImage(cgImage: cgImage).oriented(CGImagePropertyOrientation(image.imageOrientation))
        }
        return CIImage(image: image, options: [.applyOrientationProperty: true])
    }

    private nonisolated static func render(_ output: CIImage?, fallback: UIImage) -> UIImage {
        guard let output, let cgImage = context.createCGImage(output, from: output.extent.integral) else { return fallback }
        return UIImage(cgImage: cgImage)
    }
}

extension CGImagePropertyOrientation {
    nonisolated init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}

/// The filters offered on every page — switchable, always reapplied from the
/// untouched base image so picking one and then another never stacks effects.
/// Raw values are stored in drafts, so they stay as they were.
nonisolated enum PageFilter: String, CaseIterable, Codable, Sendable {
    case color, grayscale, blackAndWhite

    var label: String {
        switch self {
        case .color: "Original"
        case .grayscale: "Grayscale"
        case .blackAndWhite: "Fax"
        }
    }

    /// `faxThreshold` only affects `.blackAndWhite`.
    nonisolated func apply(to image: UIImage, faxThreshold: Double) -> UIImage {
        switch self {
        case .color: image
        case .grayscale: FaxImageProcessor.desaturated(image)
        case .blackAndWhite: FaxImageProcessor.faxBlackAndWhite(image, threshold: faxThreshold)
        }
    }
}

/// The amber warning's one-tap fix, kept as page state (not baked into the
/// pixels) so it survives switching filters, rotating, and cropping.
nonisolated enum ToneAdjustment: String, Codable, Sendable {
    case none, brightened, darkened

    nonisolated func apply(to image: UIImage) -> UIImage {
        switch self {
        case .none: image
        case .brightened: FaxImageProcessor.brightened(image)
        case .darkened: FaxImageProcessor.darkened(image)
        }
    }
}

/// Four corners of a crop selection in unit coordinates (0...1) with a
/// top-left origin, relative to the page image. Independent of how big the
/// image happens to be drawn on screen, so it survives rotation/resizes of
/// the crop view and maps directly onto the full-resolution pixels.
nonisolated struct NormalizedQuad: Equatable, Sendable {
    var topLeft: CGPoint
    var topRight: CGPoint
    var bottomRight: CGPoint
    var bottomLeft: CGPoint

    nonisolated static let fullImage = NormalizedQuad(
        topLeft: CGPoint(x: 0, y: 0),
        topRight: CGPoint(x: 1, y: 0),
        bottomRight: CGPoint(x: 1, y: 1),
        bottomLeft: CGPoint(x: 0, y: 1)
    )

    /// Clockwise order on screen.
    nonisolated var points: [CGPoint] { [topLeft, topRight, bottomRight, bottomLeft] }

    /// Shoelace area in unit space (1 = whole image).
    nonisolated var area: CGFloat {
        let p = points
        var sum: CGFloat = 0
        for i in 0..<4 {
            let a = p[i], b = p[(i + 1) % 4]
            sum += a.x * b.y - b.x * a.y
        }
        return abs(sum) / 2
    }

    /// Convex, not self-intersecting, and not vanishingly small. A crossed
    /// quad (e.g. a corner dragged past its neighbour) makes
    /// CIPerspectiveCorrection produce garbage, so it's rejected up front.
    nonisolated var isValid: Bool {
        let p = points
        var sign: CGFloat = 0
        for i in 0..<4 {
            let a = p[i], b = p[(i + 1) % 4], c = p[(i + 2) % 4]
            let cross = (b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x)
            if abs(cross) < 1e-6 { return false }
            if sign == 0 { sign = cross } else if (cross > 0) != (sign > 0) { return false }
        }
        return area > 0.01
    }
}
