import Foundation

/// Why a typed number can't be faxed. Format-only (US/Canada numbering
/// plan) — never claims to verify who owns the number.
enum RecipientNumberIssue: Equatable {
    case empty
    case incomplete(missingDigits: Int)
    case tooLong
    /// Area code starts with 0/1 or is an N11 service code (911, 411…).
    case invalidAreaCode
    /// Digits 4–6 start with 0/1 or are an N11 service code.
    case invalidExchange

    /// Still being typed — only worth flagging once they try to send.
    var isStillTyping: Bool {
        switch self {
        case .empty, .incomplete: true
        case .tooLong, .invalidAreaCode, .invalidExchange: false
        }
    }
}

enum PhoneNumberFormatter {
    static func isPlausibleUSOrCanadaNumber(_ raw: String) -> Bool {
        recipientIssue(raw) == nil
    }

    /// Nil for a dialable 10-digit US/Canada number, with or without the
    /// leading 1. Area codes never start with 1, so a leading 1 is always
    /// the country code.
    static func recipientIssue(_ raw: String) -> RecipientNumberIssue? {
        var digits = Array(raw.filter(\.isNumber))
        let typedAnything = !digits.isEmpty
        if digits.first == "1" { digits.removeFirst() }
        switch digits.count {
        case 0:
            return typedAnything ? .incomplete(missingDigits: 10) : .empty
        case 1..<10:
            return .incomplete(missingDigits: 10 - digits.count)
        case 10:
            break
        default:
            return .tooLong
        }
        if !isValidNXX(digits[0..<3]) { return .invalidAreaCode }
        if !isValidNXX(digits[3..<6]) { return .invalidExchange }
        return nil
    }

    /// N = 2–9 first digit, and not an N11 service code.
    private static func isValidNXX(_ code: ArraySlice<Character>) -> Bool {
        let d = Array(code)
        guard d[0] != "0", d[0] != "1" else { return false }
        return !(d[1] == "1" && d[2] == "1")
    }

    static func displayString(_ raw: String) -> String {
        let digits = raw.filter(\.isNumber).suffix(10)
        guard digits.count == 10 else { return raw }
        let area = digits.prefix(3)
        let exchange = digits.dropFirst(3).prefix(3)
        let line = digits.suffix(4)
        return "+1 (\(area)) \(exchange)-\(line)"
    }

    /// "(205) 496-8688" — national format without the +1, for places where
    /// the country is already shown.
    static func localDisplayString(_ raw: String) -> String {
        let digits = raw.filter(\.isNumber).suffix(10)
        guard digits.count == 10 else { return raw }
        return "(\(digits.prefix(3))) \(digits.dropFirst(3).prefix(3))-\(digits.suffix(4))"
    }
}
