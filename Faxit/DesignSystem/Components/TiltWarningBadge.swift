import SwiftUI

/// Shown on a scanned page that came back at an angle and was straightened
/// automatically: says so, with Undo to get the page back as captured.
struct StraightenedNoticeBadge: View {
    let onUndo: () -> Void
    let onKeep: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "wand.and.stars")
                .foregroundStyle(Color.faxitAccent)
                .accessibilityHidden(true)
            Text(CopyDeck.Scan.straightenedNotice)
                .font(.faxitCaption)
                .foregroundStyle(Color.faxitInkPrimary)
            Spacer(minLength: 8)
            Button(CopyDeck.Scan.undo, action: onUndo)
                .font(.faxitCaptionSemibold)
                .foregroundStyle(Color.faxitAccent)
                .frame(minHeight: 44)
            Button(CopyDeck.Scan.ok, action: onKeep)
                .font(.faxitCaptionSemibold)
                .foregroundStyle(Color.faxitAccent)
                .frame(minHeight: 44)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.faxitAccent.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// Fallback when a tilted page was detected but couldn't be straightened
/// automatically. A warning only — never blocks sending.
struct TiltWarningBadge: View {
    let onAdjust: () -> Void
    let onKeepAsIs: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "perspective")
                    .foregroundStyle(Color.faxitStatusAmber)
                    .accessibilityHidden(true)
                Text(CopyDeck.Scan.tiltWarning)
                    .font(.faxitCaption)
                    .foregroundStyle(Color.faxitInkPrimary)
            }
            HStack(spacing: 12) {
                Button(CopyDeck.Scan.adjust, action: onAdjust)
                Button(CopyDeck.Scan.keepAsIs, action: onKeepAsIs)
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
