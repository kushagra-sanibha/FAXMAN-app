import CryptoKit
import Foundation
import SwiftData

/// What the user chose to send — pages plus optional cover page — and the
/// one shared path that turns it into a persisted `SentFax`. Used by both
/// ReviewSendView (draft/compose flow) and PaywallView (home screen), which
/// previously each had their own copy of this logic.
struct FaxSubmission {
    let pages: [ScannedPage]
    let recipientNumber: String
    let coverPageStyle: CoverPageStyle?
    let coverPageDetails: CoverPageDetails

    private var effectiveCoverStyle: CoverPageStyle? {
        guard let coverPageStyle, coverPageStyle != .none else { return nil }
        return coverPageStyle
    }

    /// Last line of defense: nothing is charged or sent to a number that
    /// isn't a complete US/Canada number, whatever screen it came from.
    var hasValidRecipient: Bool { PhoneNumberFormatter.isPlausibleUSOrCanadaNumber(recipientNumber) }

    /// Document pages only — the cover page is free (see CopyDeck.Compose.coverPageNote).
    /// This is what a send uses from the plan's page allowance.
    var billablePageCount: Int { pages.count }

    var transmittedPageCount: Int { pages.count + (effectiveCoverStyle == nil ? 0 : 1) }

    /// Identical content to the same number hashes identically even if the
    /// pages were re-imported (new IDs) or the number was typed with
    /// different punctuation — the old hash used page UUIDs and the raw
    /// number string, so it could never actually catch a duplicate send.
    var contentHash: String {
        var hasher = SHA256()
        hasher.update(data: Data(Self.digits(recipientNumber).utf8))
        for page in pages {
            hasher.update(data: FaxImageProcessor.fingerprint(of: page.image))
        }
        if let style = effectiveCoverStyle {
            hasher.update(data: Data(style.rawValue.utf8))
            // Sorted keys: JSONEncoder's default key order isn't stable,
            // which would make identical cover pages hash differently.
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            if let details = try? encoder.encode(coverPageDetails) { hasher.update(data: details) }
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    func isRecentDuplicate(of recentFaxes: [SentFax], within interval: TimeInterval = 600) -> Bool {
        let hash = contentHash
        let number = Self.digits(recipientNumber)
        return recentFaxes.contains {
            Self.digits($0.recipientNumber) == number &&
            $0.documentContentHash == hash &&
            $0.createdAt.timeIntervalSinceNow > -interval
        }
    }

    /// Renders the cover page (if any), writes every page to disk and
    /// inserts the SentFax that FaxSendRunner will transmit, counted
    /// against the send plan's page allowance.
    func makeSentFax(modelContext: ModelContext) -> SentFax {
        var transmitted = pages
        if let style = effectiveCoverStyle {
            let senderName = (try? modelContext.fetch(FetchDescriptor<SenderProfile>()))?.first?.name ?? ""
            let cover = CoverPageRenderer.render(.init(
                style: style,
                details: coverPageDetails,
                recipientNumber: recipientNumber,
                senderName: senderName,
                totalPageCount: transmittedPageCount
            ))
            transmitted.insert(ScannedPage(baseImage: cover, source: .coverPage, filter: .color), at: 0)
        }

        let id = UUID()
        let paper = (try? modelContext.fetch(FetchDescriptor<AppSettingsModel>()))?.first?.faxPaperSize ?? .letter
        let fileNames = PageFileStore.saveForTransmission(transmitted, forFaxID: id, paper: paper)
        let fax = SentFax(
            id: id,
            recipientNumber: recipientNumber,
            pageCount: fileNames.count,
            paymentMethod: .planAllowance,
            planPageCount: billablePageCount,
            documentContentHash: contentHash,
            pageImageFileNames: fileNames
        )
        modelContext.insert(fax)
        try? modelContext.save()
        return fax
    }

    private static func digits(_ number: String) -> String {
        let digits = number.filter(\.isNumber)
        // "1 555…" and "555…" are the same US/Canada number.
        return digits.count == 11 && digits.first == "1" ? String(digits.dropFirst()) : digits
    }
}
