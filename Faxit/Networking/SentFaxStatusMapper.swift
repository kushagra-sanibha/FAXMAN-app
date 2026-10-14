import Foundation

/// Pure conversion from the provider's vocabulary to the persisted FaxStatus,
/// so SwiftData models never depend on provider-specific types.
enum SentFaxStatusMapper {
    static func map(_ providerStatus: FaxProviderStatus) -> FaxStatus {
        switch providerStatus {
        case .preparing: .preparing
        case .uploading: .uploading
        case .sending: .sending
        case .retrying(let attempt, let max): .retrying(attempt: attempt, maxAttempts: max)
        case .delivered: .delivered
        case .partiallyDelivered(let delivered, let total): .partiallyDelivered(delivered: delivered, total: total)
        case .notDelivered(let reason): .notDelivered(reason: reason)
        case .providerUnavailable: .providerUnavailable
        }
    }
}
