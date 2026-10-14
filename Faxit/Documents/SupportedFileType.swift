import UniformTypeIdentifiers

/// Only these are importable in v1 — anything else (Word, Excel, ZIP) is
/// rejected with a plain message rather than attempted. The picker and the
/// importer both read this one list, so they can never disagree.
enum SupportedFileType {
    enum Kind {
        case pdf
        case image
    }

    nonisolated static let importableTypes: [UTType] = [.pdf, .jpeg, .png, .heic]

    /// Classifies a file by its actual content type (falling back to the
    /// extension), not by trial-and-error decoding.
    nonisolated static func kind(of url: URL) -> Kind? {
        let type = (try? url.resourceValues(forKeys: [.contentTypeKey]).contentType)
            ?? UTType(filenameExtension: url.pathExtension)
        guard let type else { return nil }
        return kind(of: type)
    }

    nonisolated static func kind(of type: UTType) -> Kind? {
        guard importableTypes.contains(where: { type.conforms(to: $0) }) else { return nil }
        return type.conforms(to: .pdf) ? .pdf : .image
    }
}
