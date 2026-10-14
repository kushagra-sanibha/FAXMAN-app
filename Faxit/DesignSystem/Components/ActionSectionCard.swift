import SwiftUI

/// A bold, gradient hero card for the home screen's two primary actions —
/// deliberately the most eye-catching thing on first launch. Scan and
/// Upload use the same two brand colors mirrored in opposite directions so
/// they read as a matched pair rather than two unrelated buttons.
struct ActionSectionCard: View {
    let systemImage: String
    let title: String
    let subtitle: String
    var gradientReversed: Bool = false
    let action: () -> Void

    private var gradient: LinearGradient {
        let colors = gradientReversed
            ? [Color.faxitNavyBackground, Color.faxitAccent]
            : [Color.faxitAccent, Color.faxitNavyBackground]
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 24))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(Color.white.opacity(0.18))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.35), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.faxitBodyBold)
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.faxitCaption)
                        .foregroundStyle(.white.opacity(0.85))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.faxitCaptionBold)
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Color.white.opacity(0.18))
                    .clipShape(Circle())
            }
            .padding(18)
        }
        .buttonStyle(ActionCardButtonStyle())
        .background(gradient)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: Color.faxitAccent.opacity(0.35), radius: 16, x: 0, y: 8)
    }
}

/// Gives the hero cards a tactile press-down feel instead of the flat
/// opacity-only feedback used elsewhere.
private struct ActionCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// Small circular "OR" seam that overlaps the two hero cards above and
/// below it, so the pair reads as one connected choice rather than two
/// separate buttons with a plain divider between them.
struct OrSeparatorBadge: View {
    var body: some View {
        Text(CopyDeck.Activity.orDivider)
            .font(.faxitCaptionBold)
            .foregroundStyle(Color.faxitInkSecondary)
            .frame(width: 36, height: 36)
            .background(Color.faxitMintBackground)
            .clipShape(Circle())
            .overlay(
                Circle().stroke(Color.faxitInkSecondary.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
    }
}

#Preview {
    ZStack {
        VStack(spacing: 14) {
            ActionSectionCard(
                systemImage: "camera.fill",
                title: CopyDeck.Activity.scanAction,
                subtitle: CopyDeck.Activity.scanActionSubtitle,
                action: {}
            )
            ActionSectionCard(
                systemImage: "doc.fill",
                title: CopyDeck.Activity.uploadAction,
                subtitle: CopyDeck.Activity.uploadActionSubtitle,
                gradientReversed: true,
                action: {}
            )
        }
        OrSeparatorBadge()
    }
    .padding(16)
    .background(Color.faxitMintBackground)
}
