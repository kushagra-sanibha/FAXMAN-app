import PDFKit
import UIKit

/// Shared scan/upload-to-page conversion. Every source — camera scan, photo
/// library, image file, PDF — ends up as the same kind of `ScannedPage`, so
/// crop, rotate, filters and the brightness fix behave identically no
/// matter where the page came from.
enum DocumentImportHelper {
    nonisolated enum ImportFailure: Error, Equatable {
        case unsupportedType(String)
        case unreadable(String)
        case passwordProtected(String)
    }

    nonisolated struct ImportResult {
        var pages: [ScannedPage] = []
        var failures: [ImportFailure] = []
    }

    /// A photo pulled from the picker: encoded data (decoded and downsampled
    /// off the main actor here, not in the picker callback) plus the name
    /// Photos suggests for it.
    nonisolated struct PickedPhoto: Sendable {
        let data: Data
        let suggestedName: String?
    }

    /// The Core Image work (fax conversion, brightness analysis) is
    /// genuinely expensive per page, so this always runs off the main
    /// thread — otherwise importing a multi-page PDF or several photos
    /// blocks the UI and the app appears to hang.
    static func makePages(fromScan images: [UIImage]) async -> [ScannedPage] {
        await Task.detached(priority: .userInitiated) {
            nonisolatedPages(from: images, source: .scan, documentName: scanDocumentName())
        }.value
    }

    static func makePages(fromPhotos photos: [PickedPhoto]) async -> ImportResult {
        await Task.detached(priority: .userInitiated) {
            var result = ImportResult()
            var images: [UIImage] = []
            for (index, photo) in photos.enumerated() {
                if let image = FaxImageProcessor.downsampledImage(from: photo.data) {
                    images.append(image)
                } else {
                    result.failures.append(.unreadable(photo.suggestedName ?? "Photo \(index + 1)"))
                }
            }
            guard !images.isEmpty else { return result }
            let name: String
            if images.count == 1, let suggested = photos.first?.suggestedName, !suggested.isEmpty {
                name = suggested
            } else {
                name = images.count == 1 ? "Photo" : "\(images.count) photos"
            }
            result.pages = nonisolatedPages(from: images, source: .photo, documentName: name)
            return result
        }.value
    }

    /// Renders picked file URLs (every PDF page, or a single image) into
    /// pages; one file = one document. Failures are reported per file with
    /// the reason so the caller can say exactly what went wrong.
    static func importPages(from urls: [URL]) async -> ImportResult {
        await Task.detached(priority: .userInitiated) {
            var result = ImportResult()
            for url in urls {
                let name = url.lastPathComponent
                switch SupportedFileType.kind(of: url) {
                case .pdf:
                    switch renderPDF(at: url) {
                    case .success(let images):
                        result.pages += nonisolatedPages(from: images, source: .pdf, documentName: name)
                    case .failure(let failure):
                        result.failures.append(failure)
                    }
                case .image:
                    if let image = FaxImageProcessor.downsampledImage(at: url) {
                        result.pages += nonisolatedPages(from: [image], source: .imageFile, documentName: name)
                    } else {
                        result.failures.append(.unreadable(name))
                    }
                case nil:
                    result.failures.append(.unsupportedType(name))
                }
                // The picker hands us private copies (asCopy: true); they're
                // dead weight in tmp once rendered.
                try? FileManager.default.removeItem(at: url)
            }
            return result
        }.value
    }

    /// `nonisolated` so `Task.detached` above genuinely runs this off the
    /// main actor — this project defaults unannotated code to MainActor
    /// isolation, which would otherwise silently hop this expensive work
    /// back onto the main thread. Each call mints one documentID shared by
    /// every page in `images`, since one call = one document.
    private nonisolated static func nonisolatedPages(from images: [UIImage], source: PageSource, documentName: String) -> [ScannedPage] {
        let documentID = UUID()
        return images.map { image in
            // Only camera scans: uploads already start the crop tool on the
            // detected page. A tilted scan is straightened automatically.
            let tilt = source == .scan ? DocumentEdgeDetector.tiltedPageOutline(in: FaxImageProcessor.normalized(image)) : nil
            return ScannedPage(baseImage: image, source: source, filter: .blackAndWhite, documentID: documentID, documentName: documentName, detectedTilt: tilt)
        }
    }

    private nonisolated static func scanDocumentName() -> String {
        "Scan \(Date.now.formatted(date: .abbreviated, time: .shortened))"
    }

    /// Renders each page at fax resolution, honoring the page's crop box and
    /// `/Rotate` — drawing the raw media box (as before) rendered rotated
    /// pages sideways and included printer bleed/crop marks.
    private nonisolated static func renderPDF(at url: URL) -> Result<[UIImage], ImportFailure> {
        let name = url.lastPathComponent
        guard let document = PDFDocument(url: url) else { return .failure(.unreadable(name)) }
        // A locked PDF opens but renders blank pages.
        if document.isLocked { return .failure(.passwordProtected(name)) }
        guard document.pageCount > 0 else { return .failure(.unreadable(name)) }

        let scale = FaxImageProcessor.faxDPI / 72
        var images: [UIImage] = []
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            let box = page.bounds(for: .cropBox)
            let quarterTurns = ((page.rotation % 360) + 360) % 360 / 90
            let pointSize = quarterTurns % 2 == 1 ? CGSize(width: box.height, height: box.width) : box.size
            var pixelSize = CGSize(width: pointSize.width * scale, height: pointSize.height * scale)
            // Oversized pages (posters, CAD sheets) still cap at fax size.
            let longest = max(pixelSize.width, pixelSize.height)
            if longest > FaxImageProcessor.maxPixelDimension {
                let factor = FaxImageProcessor.maxPixelDimension / longest
                pixelSize = CGSize(width: pixelSize.width * factor, height: pixelSize.height * factor)
            }
            guard pixelSize.width >= 1, pixelSize.height >= 1 else { continue }
            images.append(page.thumbnail(of: pixelSize, for: .cropBox).flattenedPage(size: pixelSize))
        }
        return images.isEmpty ? .failure(.unreadable(name)) : .success(images)
    }
}

private extension UIImage {
    /// `PDFPage.thumbnail` returns a point-based image at screen scale with
    /// a possibly transparent background; this pins it to an exact,
    /// opaque, scale-1 pixel bitmap on white paper.
    nonisolated func flattenedPage(size: CGSize) -> UIImage {
        let target = CGSize(width: size.width.rounded(), height: size.height.rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: target, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: target))
            draw(in: CGRect(origin: .zero, size: target))
        }
    }
}

extension DocumentImportHelper.ImportFailure {
    @MainActor var message: String {
        switch self {
        case .unsupportedType(let name): "“\(name)”: \(CopyDeck.Compose.unsupportedFileMessage)"
        case .unreadable(let name): "“\(name)” couldn't be opened. It may be damaged."
        case .passwordProtected(let name): "“\(name)” is password-protected. Remove the password and try again."
        }
    }
}
