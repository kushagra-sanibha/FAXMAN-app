import UIKit

/// Persists scanned/imported page images to disk so a sent fax can actually
/// be retried or resent later — in-memory ScannedPage data does not survive
/// past the compose sheet being dismissed.
enum PageFileStore {
    private nonisolated static var directory: URL {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("FaxPages", isDirectory: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }

    /// Writes the pages exactly as they'll be faxed: each fitted onto a
    /// standard `paper` page at 200 dpi. "Fax" pages are stored as 1-bit PNG
    /// (small and crisp); Original/Grayscale pages as JPEG. Returns the file
    /// names (not full paths) written, suitable for storing on a SentFax.
    static func saveForTransmission(_ pages: [ScannedPage], forFaxID id: UUID, paper: FaxPaperSize) -> [String] {
        var fileNames: [String] = []
        for (index, page) in pages.enumerated() {
            let output = FaxImageProcessor.faxPage(page.image, paper: paper)
            let isBlackAndWhite = page.filter == .blackAndWhite
            let fileName = "\(id.uuidString)-\(index).\(isBlackAndWhite ? "png" : "jpg")"
            let data = isBlackAndWhite ? FaxImageProcessor.oneBitPNGData(output) : output.jpegData(compressionQuality: 0.8)
            if let data, write(data, to: fileName) {
                fileNames.append(fileName)
            }
        }
        return fileNames
    }

    /// Saves a draft so it resumes exactly as left: besides the rendered
    /// page it keeps the full-color base image and each page's edit
    /// settings. Previously only the filtered result was saved, so a
    /// resumed draft could never switch back to Color and lost its
    /// document grouping.
    static func saveDraft(_ pages: [ScannedPage], draftID id: UUID) -> [String] {
        var fileNames: [String] = []
        var manifest = DraftManifest(pages: [])
        for (index, page) in pages.enumerated() {
            let fileName = "\(id.uuidString)-\(index).jpg"
            guard write(page.image, to: fileName) else { continue }
            let baseName = baseFileName(for: fileName)
            let hasBase = write(page.baseImage, to: baseName)
            fileNames.append(fileName)
            manifest.pages.append(.init(
                fileName: fileName,
                baseFileName: hasBase ? baseName : nil,
                filter: page.filter,
                tone: page.tone,
                faxThreshold: page.faxThreshold,
                isWarningDismissed: page.isWarningDismissed,
                source: page.source,
                documentID: page.documentID,
                documentName: page.documentName
            ))
        }
        if let data = try? JSONEncoder().encode(manifest) {
            try? data.write(to: directory.appendingPathComponent(manifestFileName(for: id)), options: .atomic)
        }
        return fileNames
    }

    /// Rebuilds editable pages for a resumed draft. Drafts saved before the
    /// manifest existed load their rendered images as-is (Color filter =
    /// no re-filtering, so the B&W conversion isn't doubled up).
    static func loadDraftPages(forDraftID id: UUID, fileNames: [String]) -> [ScannedPage] {
        let manifestURL = directory.appendingPathComponent(manifestFileName(for: id))
        if let data = try? Data(contentsOf: manifestURL),
           let manifest = try? JSONDecoder().decode(DraftManifest.self, from: data) {
            let pages = manifest.pages.compactMap { entry -> ScannedPage? in
                if let baseName = entry.baseFileName, let base = image(named: baseName) {
                    return ScannedPage(
                        baseImage: base,
                        source: entry.source,
                        filter: entry.filter,
                        tone: entry.tone,
                        faxThreshold: entry.faxThreshold ?? FaxImageProcessor.defaultFaxThreshold,
                        isWarningDismissed: entry.isWarningDismissed,
                        documentID: entry.documentID,
                        documentName: entry.documentName
                    )
                }
                return image(named: entry.fileName).map {
                    ScannedPage(baseImage: $0, source: entry.source, filter: .color, documentID: entry.documentID, documentName: entry.documentName)
                }
            }
            if !pages.isEmpty { return pages }
        }

        let documentID = UUID()
        return fileNames.compactMap(image(named:)).map {
            ScannedPage(baseImage: $0, source: .scan, filter: .color, documentID: documentID, documentName: "Draft")
        }
    }

    static func urls(forFileNames fileNames: [String]) -> [URL] {
        fileNames.map { directory.appendingPathComponent($0) }
    }

    static func images(forFileNames fileNames: [String]) -> [UIImage] {
        fileNames.compactMap(image(named:))
    }

    /// Also removes each page's draft base image and the draft manifest.
    static func delete(fileNames: [String]) {
        var related = Set<String>()
        for name in fileNames {
            related.insert(name)
            related.insert(baseFileName(for: name))
            if let id = UUID(uuidString: String(name.prefix(36))) {
                related.insert(manifestFileName(for: id))
            }
        }
        for url in urls(forFileNames: Array(related)) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// Pre-flight check before importing a large document.
    static func hasSufficientStorage(minimumBytes: Int64 = 50_000_000) -> Bool {
        guard let values = try? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
            let available = values.volumeAvailableCapacityForImportantUsage else {
            return true
        }
        return available > minimumBytes
    }

    // MARK: - Private

    private struct DraftManifest: Codable {
        struct Page: Codable {
            let fileName: String
            let baseFileName: String?
            let filter: PageFilter
            let tone: ToneAdjustment
            /// Optional: drafts saved before the slider existed don't have it.
            let faxThreshold: Double?
            let isWarningDismissed: Bool
            let source: PageSource
            let documentID: UUID
            let documentName: String
        }
        var pages: [Page]
    }

    private static func write(_ image: UIImage, to fileName: String) -> Bool {
        guard let data = image.jpegData(compressionQuality: 0.85) else { return false }
        return write(data, to: fileName)
    }

    private static func write(_ data: Data, to fileName: String) -> Bool {
        do {
            try data.write(to: directory.appendingPathComponent(fileName), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            return true
        } catch {
            return false
        }
    }

    private nonisolated static func image(named fileName: String) -> UIImage? {
        UIImage(contentsOfFile: directory.appendingPathComponent(fileName).path)
    }

    private static func baseFileName(for fileName: String) -> String {
        (fileName as NSString).deletingPathExtension + "-base.jpg"
    }

    private static func manifestFileName(for id: UUID) -> String {
        "\(id.uuidString)-draft.json"
    }
}
