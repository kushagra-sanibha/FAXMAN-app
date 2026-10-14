import Foundation

/// Magic recipient numbers select a deterministic mock scenario, the same
/// way Stripe's test card numbers work — lets the whole status/edge-case
/// matrix be exercised by hand with no backend.
///
/// Dial any other plausible US/Canada number for a quick, happy-path delivery.
enum MockScenario: CaseIterable {
    case success
    case busyThenSuccess
    case noAnswer
    case notAFaxLine
    case disconnected
    case partialDelivery
    case providerUnavailable

    /// Last 4 digits of the recipient number select the scenario.
    static func scenario(forNumber number: String) -> MockScenario {
        let digits = number.filter(\.isNumber)
        let lastFour = String(digits.suffix(4))
        switch lastFour {
        case "0199": return .busyThenSuccess
        case "0188": return .noAnswer
        case "0177": return .notAFaxLine
        case "0166": return .disconnected
        case "0155": return .partialDelivery
        case "0144": return .providerUnavailable
        default: return .success
        }
    }

    var displayHint: String {
        switch self {
        case .success: "Delivers right away"
        case .busyThenSuccess: "Busy, then delivers after retries (…0199)"
        case .noAnswer: "No answer, no retry (…0188)"
        case .notAFaxLine: "Not a fax line, no retry (…0177)"
        case .disconnected: "Number disconnected (…0166)"
        case .partialDelivery: "Partial delivery, 3 of 5 pages (…0155)"
        case .providerUnavailable: "Provider unavailable (…0144)"
        }
    }
}
