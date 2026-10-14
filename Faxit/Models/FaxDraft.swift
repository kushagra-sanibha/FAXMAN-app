import Foundation
import SwiftData

/// A fax someone started (scanned or uploaded pages, maybe entered a number)
/// but chose to finish sending later. Pages are written to disk via
/// PageFileStore only — same as a sent fax — and are never transmitted to
/// the fax provider until the draft is resumed and actually sent.
@Model
final class FaxDraft {
    var id: UUID
    var recipientNumberRaw: String
    var pageImageFileNames: [String]
    var coverPageStyleRaw: String?
    var coverPageDetailsData: Data?
    var createdAt: Date
    var lastEditedAt: Date

    init(
        id: UUID = UUID(),
        recipientNumberRaw: String = "",
        pageImageFileNames: [String] = [],
        coverPageStyle: CoverPageStyle? = nil,
        coverPageDetails: CoverPageDetails = CoverPageDetails(),
        createdAt: Date = .now,
        lastEditedAt: Date = .now
    ) {
        self.id = id
        self.recipientNumberRaw = recipientNumberRaw
        self.pageImageFileNames = pageImageFileNames
        self.coverPageStyleRaw = coverPageStyle?.rawValue
        self.coverPageDetailsData = try? JSONEncoder().encode(coverPageDetails)
        self.createdAt = createdAt
        self.lastEditedAt = lastEditedAt
    }

    var coverPageStyle: CoverPageStyle? {
        get { coverPageStyleRaw.flatMap(CoverPageStyle.init(rawValue:)) }
        set { coverPageStyleRaw = newValue?.rawValue }
    }

    var coverPageDetails: CoverPageDetails {
        get { coverPageDetailsData.flatMap { try? JSONDecoder().decode(CoverPageDetails.self, from: $0) } ?? CoverPageDetails() }
        set { coverPageDetailsData = try? JSONEncoder().encode(newValue) }
    }

    var pageImageURLs: [URL] {
        PageFileStore.urls(forFileNames: pageImageFileNames)
    }

    var pageCount: Int { pageImageFileNames.count }
}
