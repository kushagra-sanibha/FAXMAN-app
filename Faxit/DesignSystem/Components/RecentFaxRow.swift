import SwiftUI

/// One sent fax in the Recent faxes list: number and details, then three
/// trailing actions — delivery report, favorite, and the delivery result.
struct RecentFaxRow: View {
    let title: String
    let subtitle: String
    let status: FaxStatus
    let isFavorite: Bool
    let onShowReport: () -> Void
    let onToggleFavorite: () -> Void
    let onShowStatus: () -> Void

    /// A report only says something once the fax has an outcome.
    private var hasReport: Bool { status.isTerminal }

    /// Never blank: an empty or unparseable number still says so.
    private var displayTitle: String {
        title.trimmingCharacters(in: .whitespaces).isEmpty ? "Unknown number" : title
    }

    var body: some View {
        // Always one line: number and details on the left, the three
        // actions on the right. The actions keep their size, the number has
        // first claim on the remaining width (shrinking slightly at very
        // large text sizes rather than truncating its last digits), and only
        // the date line wraps if space is tight.
        HStack(spacing: 8) {
            details
                .layoutPriority(1)
            Spacer(minLength: 0)
            actions
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(displayTitle)
                .font(.faxitBodySemibold)
                .foregroundStyle(Color.faxitInkPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(subtitle)
                .font(.faxitCaption)
                .foregroundStyle(Color.faxitInkSecondary)
                .lineLimit(2)
        }
        .accessibilityElement(children: .combine)
    }

    private var actions: some View {
        HStack(spacing: 4) {
            iconButton(
                systemImage: "doc.text.fill",
                tint: hasReport ? .faxitAccent : .faxitInkSecondary.opacity(0.35),
                label: "Delivery report",
                action: onShowReport
            )
            .disabled(!hasReport)

            iconButton(
                systemImage: isFavorite ? "heart.fill" : "heart",
                tint: isFavorite ? .faxitStatusRed : .faxitInkSecondary,
                label: isFavorite ? "Remove from favorites" : "Add to favorites",
                action: onToggleFavorite
            )
            .symbolEffect(.bounce, value: isFavorite)
            .contentTransition(.symbolEffect(.replace))
            .sensoryFeedback(.selection, trigger: isFavorite)

            ResultTick(status: status, action: onShowStatus)
        }
        .fixedSize()
    }

    private func iconButton(systemImage: String, tint: Color, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(label)
    }
}

/// Green tick for delivered, red cross for failed — distinct shapes as well
/// as colors, so the result is never conveyed by color alone.
private struct ResultTick: View {
    let status: FaxStatus
    let action: () -> Void

    private var symbol: String {
        switch status {
        case .delivered: "checkmark.circle.fill"
        case .notDelivered, .providerUnavailable, .cancelled: "xmark.circle.fill"
        case .partiallyDelivered: "exclamationmark.circle.fill"
        case .preparing, .uploading, .sending, .retrying: "clock.fill"
        }
    }

    private var tint: Color {
        switch status {
        case .delivered: .faxitStatusGreen
        case .notDelivered, .providerUnavailable, .cancelled: .faxitStatusRed
        case .partiallyDelivered, .retrying: .faxitStatusAmber
        case .preparing, .uploading, .sending: .faxitInkSecondary
        }
    }

    private var accessibilityText: String {
        switch status {
        case .delivered: "Delivered"
        case .partiallyDelivered(let delivered, let total): "\(delivered) of \(total) pages delivered"
        case .notDelivered, .providerUnavailable: "Not delivered"
        case .cancelled: "Cancelled"
        case .preparing, .uploading, .sending, .retrying: "Still sending"
        }
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 22))
                .foregroundStyle(tint)
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.pulse, isActive: !status.isTerminal)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(accessibilityText)
        .accessibilityHint("Shows the fax's status")
    }
}

#Preview {
    VStack(spacing: 0) {
        RecentFaxRow(title: "+1 (555) 123-4567", subtitle: "3 pages · Oct 9, 2:41 PM", status: .delivered, isFavorite: true, onShowReport: {}, onToggleFavorite: {}, onShowStatus: {})
        Divider()
        RecentFaxRow(title: "+1 (555) 123-0188", subtitle: "1 page · Oct 9, 1:02 PM", status: .notDelivered(reason: .noAnswer), isFavorite: false, onShowReport: {}, onToggleFavorite: {}, onShowStatus: {})
        Divider()
        RecentFaxRow(title: "+1 (555) 222-0101", subtitle: "2 pages · Oct 9, 3:10 PM", status: .sending, isFavorite: false, onShowReport: {}, onToggleFavorite: {}, onShowStatus: {})
        Divider()
        // Long, locale-style date line (as seen on device) must not push the
        // actions onto a second line.
        RecentFaxRow(title: "99999999", subtitle: "1 page · 9 Oct 2026 at 10:05 AM", status: .delivered, isFavorite: false, onShowReport: {}, onToggleFavorite: {}, onShowStatus: {})
    }
    .background(Color.faxitCardBackground)
}
