import Foundation

struct OutgoingFaxRequest {
    let recipientNumber: String
    let pageImageURLs: [URL]
    let coverPage: CoverPageStyle?
}

struct FaxProviderHandle: Hashable {
    let id: String
}

enum FaxProviderStatus: Equatable {
    case preparing
    case uploading
    case sending
    case retrying(attempt: Int, max: Int)
    case delivered
    case partiallyDelivered(delivered: Int, total: Int)
    case notDelivered(reason: FailureReason)
    case providerUnavailable
}

struct ReceivedFaxPayload {
    let senderNumberIfAvailable: String?
    let receivedAt: Date
    let pageCount: Int
    let pdfFileURL: URL
}

enum FaxProviderError: Error {
    case cancelled
    case notFound
    case noNumbersAvailable
    /// Too many requests from this device or to this address; try later.
    case rateLimited
    case offline
}

enum FeedbackKind: String, CaseIterable, Sendable {
    case idea
    case problem
}

/// An export is emailed as a secure download link — never an attachment.
struct DataExportReceipt: Sendable {
    let linkExpiresAt: Date
}

/// When server-side deletion will be finished (30-day internal target).
struct DataDeletionReceipt: Sendable {
    let completesBy: Date
}

/// What someone is looking for when renting a number. `nil` area code and
/// region = "Give me any number".
struct FaxNumberSearch: Hashable, Sendable {
    var country: FaxNumberCountry
    var areaCodes: [String] = []
    var regionName: String?

    static func any(in country: FaxNumberCountry) -> FaxNumberSearch {
        FaxNumberSearch(country: country)
    }

    var isAnyNumber: Bool { areaCodes.isEmpty }
}

/// A number the provider can rent out right now.
struct AvailableFaxNumber: Identifiable, Hashable, Sendable {
    /// E.164, e.g. "+14155550123".
    let e164: String
    let areaCode: String
    let locality: String

    var id: String { e164 }
    var displayString: String { PhoneNumberFormatter.displayString(e164) }

    private var nationalDigits: String { String(e164.filter(\.isNumber).suffix(10)) }
    /// Middle three digits, e.g. "496" in (205) 496-8688.
    var exchange: String { String(nationalDigits.dropFirst(3).prefix(3)) }
    /// Last four digits, e.g. "8688".
    var lineNumber: String { String(nationalDigits.suffix(4)) }
}

/// Abstraction over whatever real fax API Faxit eventually integrates with.
/// Views and view models only ever see this protocol's vocabulary, never a
/// provider-specific type, so the real implementation can be swapped in later
/// (Phase 6) without touching UI code.
protocol FaxProvider {
    func send(_ request: OutgoingFaxRequest) async throws -> FaxProviderHandle
    func status(for handle: FaxProviderHandle) -> AsyncStream<FaxProviderStatus>
    func cancel(_ handle: FaxProviderHandle) async throws
    func fetchReceivedFaxes(since: Date?) async throws -> [ReceivedFaxPayload]
    func searchAvailableNumbers(_ search: FaxNumberSearch) async throws -> [AvailableFaxNumber]
    /// Claims `preferred` if it's still free; otherwise another number
    /// matching `search` — the rental has already been paid for by the time
    /// this runs, so it never fails just because the picked number was
    /// taken in the meantime. Returns the number actually assigned.
    func provisionNumber(preferred: AvailableFaxNumber?, matching search: FaxNumberSearch) async throws -> AvailableFaxNumber
    func releaseNumber() async throws
    /// Uploads `file` and emails `email` an expiring download link to it.
    /// The address is used only for this one delivery and never stored.
    func requestDataExport(file: URL, email: String, anonymousID: String) async throws -> DataExportReceipt
    func sendFeedback(kind: FeedbackKind, message: String, replyEmail: String?, anonymousID: String) async throws
    /// Deletes everything stored on our servers under `anonymousID`.
    func requestDataDeletion(anonymousID: String) async throws -> DataDeletionReceipt
}
