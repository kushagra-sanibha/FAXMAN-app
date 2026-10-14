import SwiftUI

/// Status is never conveyed by color alone — every chip pairs an icon with a word.
struct StatusChip: View {
    let status: FaxStatus

    private var label: String {
        switch status {
        case .preparing: "Preparing"
        case .uploading: "Uploading"
        case .sending: "Sending"
        case .retrying(let attempt, let max): "Retrying \(attempt)/\(max)"
        case .partiallyDelivered(let delivered, let total): "\(delivered)/\(total) delivered"
        case .delivered: "Delivered"
        case .notDelivered: "Not delivered"
        case .providerUnavailable: "Unavailable"
        case .cancelled: "Cancelled"
        }
    }

    private var symbol: String {
        switch status {
        case .preparing, .uploading, .sending: "clock"
        case .retrying: "arrow.clockwise"
        case .partiallyDelivered: "exclamationmark.circle"
        case .delivered: "checkmark.circle.fill"
        case .notDelivered: "xmark.circle.fill"
        case .providerUnavailable: "wifi.slash"
        case .cancelled: "slash.circle"
        }
    }

    private var tint: Color {
        switch status {
        case .delivered: .faxitStatusGreen
        case .retrying, .partiallyDelivered: .faxitStatusAmber
        case .notDelivered, .providerUnavailable: .faxitStatusRed
        case .preparing, .uploading, .sending, .cancelled: .faxitInkSecondary
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
            Text(label)
        }
        .font(.faxitCaptionSemibold)
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(tint.opacity(0.12))
        .clipShape(Capsule())
    }
}
