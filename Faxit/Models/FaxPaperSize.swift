import CoreGraphics

/// The page size every transmitted page is fitted onto, at fax "fine"
/// resolution (200 dpi).
nonisolated enum FaxPaperSize: String, CaseIterable, Codable, Sendable, Identifiable {
    case letter
    case a4

    var id: String { rawValue }

    var title: String {
        switch self {
        case .letter: "US Letter"
        case .a4: "A4"
        }
    }

    /// 8.5 × 11 in and 210 × 297 mm at 200 dpi.
    var pixelSize: CGSize {
        switch self {
        case .letter: CGSize(width: 1700, height: 2200)
        case .a4: CGSize(width: 1654, height: 2339)
        }
    }
}
