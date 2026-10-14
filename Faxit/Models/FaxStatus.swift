import Foundation

enum FailureReason: String, Codable, CaseIterable {
    case busy
    case noAnswer
    case notAFaxLine
    case disconnected
    case invalidNumber
    case uploadFailed
    case insufficientStorage
    case unknown

    /// Only a busy line is retried automatically; everything else is terminal.
    var isRetryable: Bool {
        self == .busy
    }
}

enum FaxStatus: Codable, Equatable {
    case preparing
    case uploading
    case sending
    case retrying(attempt: Int, maxAttempts: Int)
    case partiallyDelivered(delivered: Int, total: Int)
    case delivered
    case notDelivered(reason: FailureReason)
    case providerUnavailable
    case cancelled

    /// Discriminator used for SwiftData predicates / fast filtering, independent of associated values.
    var kind: String {
        switch self {
        case .preparing: "preparing"
        case .uploading: "uploading"
        case .sending: "sending"
        case .retrying: "retrying"
        case .partiallyDelivered: "partiallyDelivered"
        case .delivered: "delivered"
        case .notDelivered: "notDelivered"
        case .providerUnavailable: "providerUnavailable"
        case .cancelled: "cancelled"
        }
    }

    var isTerminal: Bool {
        switch self {
        case .delivered, .notDelivered, .providerUnavailable, .cancelled, .partiallyDelivered:
            true
        case .preparing, .uploading, .sending, .retrying:
            false
        }
    }

    /// A fax only counts as a real failure (ledger credit returned) for these two terminal states.
    var isFailure: Bool {
        switch self {
        case .notDelivered, .providerUnavailable:
            true
        default:
            false
        }
    }
}
