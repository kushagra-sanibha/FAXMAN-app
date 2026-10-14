import SwiftUI

/// A warning only — never blocks sending. Offers a next step, per the
/// "a failure has a next step, not just a red flag" rule. The fix offered
/// matches the actual problem: brighten a dark page, darken a washed-out one.
struct AmberWarningBadge: View {
    let issue: BrightnessIssue
    /// False once the fix is already applied, so it isn't offered again.
    var canFix: Bool = true
    let onRemove: () -> Void
    let onFix: () -> Void
    let onKeepAsIs: () -> Void

    private var message: String {
        switch issue {
        case .tooDark: CopyDeck.Review.darkPageWarning
        case .tooLight: CopyDeck.Review.lightPageWarning
        }
    }

    private var fixLabel: String {
        switch issue {
        case .tooDark: CopyDeck.Review.brighten
        case .tooLight: CopyDeck.Review.darken
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.faxitStatusAmber)
                Text(message)
                    .font(.faxitCaption)
                    .foregroundStyle(Color.faxitInkPrimary)
            }
            HStack(spacing: 12) {
                Button(CopyDeck.Review.removePage, action: onRemove)
                if canFix {
                    Button(fixLabel, action: onFix)
                }
                Button(CopyDeck.Review.keepAsIs, action: onKeepAsIs)
            }
            .font(.faxitCaptionSemibold)
            .foregroundStyle(Color.faxitAccent)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.faxitStatusAmber.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
