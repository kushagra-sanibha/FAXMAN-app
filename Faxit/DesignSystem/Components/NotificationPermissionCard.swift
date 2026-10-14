import SwiftUI

/// One-line, in-context ask for notification permission, shown only while a
/// fax is in flight — the moment the user actually benefits from it.
struct NotificationPermissionCard: View {
    let onNotifyMe: () -> Void
    let onNotNow: () -> Void

    var body: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 12) {
                Label {
                    Text(CopyDeck.Notifications.promptLine)
                        .font(.faxitBody)
                        .foregroundStyle(Color.faxitInkPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "bell.badge")
                        .foregroundStyle(Color.faxitAccent)
                        .accessibilityHidden(true)
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { buttons }
                    VStack(spacing: 8) { buttons }
                }
            }
            .padding(16)
        }
    }

    @ViewBuilder
    private var buttons: some View {
        Button(CopyDeck.Notifications.notifyMe, action: onNotifyMe)
            .buttonStyle(.faxitPrimary)
        Button(CopyDeck.Notifications.notNow, action: onNotNow)
            .buttonStyle(.faxitSecondary)
    }
}
