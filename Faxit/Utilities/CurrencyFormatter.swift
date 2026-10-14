import Foundation

enum CurrencyFormatter {
    static func string(fromCents cents: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = .current
        return formatter.string(from: NSNumber(value: Double(cents) / 100)) ?? "$\(cents / 100)"
    }
}
