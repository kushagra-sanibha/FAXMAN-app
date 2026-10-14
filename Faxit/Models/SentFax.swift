import Foundation
import SwiftData

/// How a send was paid for.
enum FaxPaymentMethod: String, Codable {
    /// Paid per fax. No longer sold; kept so faxes sent before plans-only
    /// still read correctly.
    case oneTimePass
    /// Sent on a Weekly, Monthly or Yearly plan's page allowance. (Raw value
    /// kept from when only a monthly plan existed, so stored faxes still match.)
    case planAllowance = "monthlyPlanAllowance"
}

@Model
final class SentFax {
    var id: UUID
    var recipientNumber: String
    var pageCount: Int

    private var statusData: Data
    var statusKind: String

    var retryCount: Int
    var createdAt: Date
    var updatedAt: Date

    var pricePaidCents: Int?
    var paymentMethodRaw: String
    var documentContentHash: String
    var deliveryReportFileURL: URL?
    var providerHandleID: String

    /// File names (relative, resolved via PageFileStore) of the persisted
    /// page images — needed so a failed/retried send can actually be
    /// resubmitted with the same pages rather than empty data.
    var pageImageFileNames: [String]

    /// Starred from the Recent faxes list. Defaulted so existing stores
    /// migrate without a schema version bump.
    var isFavorite: Bool = false

    /// Pages this fax used from the send plan: its document pages (the
    /// cover is free). 0 for faxes from before plans had page limits.
    var planPageCount: Int = 0

    init(
        id: UUID = UUID(),
        recipientNumber: String,
        pageCount: Int,
        status: FaxStatus = .preparing,
        retryCount: Int = 0,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        pricePaidCents: Int? = nil,
        paymentMethod: FaxPaymentMethod = .planAllowance,
        planPageCount: Int = 0,
        documentContentHash: String,
        deliveryReportFileURL: URL? = nil,
        providerHandleID: String = "",
        pageImageFileNames: [String] = []
    ) {
        self.id = id
        self.recipientNumber = recipientNumber
        self.pageCount = pageCount
        self.statusData = try! JSONEncoder().encode(status)
        self.statusKind = status.kind
        self.retryCount = retryCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.pricePaidCents = pricePaidCents
        self.paymentMethodRaw = paymentMethod.rawValue
        self.documentContentHash = documentContentHash
        self.deliveryReportFileURL = deliveryReportFileURL
        self.providerHandleID = providerHandleID
        self.planPageCount = planPageCount
        self.pageImageFileNames = pageImageFileNames
    }

    var status: FaxStatus {
        get { (try? JSONDecoder().decode(FaxStatus.self, from: statusData)) ?? .preparing }
        set {
            statusData = try! JSONEncoder().encode(newValue)
            statusKind = newValue.kind
            updatedAt = .now
        }
    }

    var paymentMethod: FaxPaymentMethod {
        get { FaxPaymentMethod(rawValue: paymentMethodRaw) ?? .planAllowance }
        set { paymentMethodRaw = newValue.rawValue }
    }

    var pageImageURLs: [URL] {
        PageFileStore.urls(forFileNames: pageImageFileNames)
    }
}
