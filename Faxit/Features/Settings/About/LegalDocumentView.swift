import SafariServices
import SwiftUI

/// Shows a hosted legal page (privacy policy, terms of use) in-app.
///
/// Presentation: designed to be shown as a sheet, e.g.
/// `.sheet(item: $legalDocument) { LegalDocumentView(title: $0.title, url: $0.url) }`.
/// SFSafariViewController supplies its own Done button, which dismisses the sheet.
/// When offline we show our own message with a retry; once loading, any load
/// failure is reported by Safari's own error page inside the controller.
/// Only present this when `AppInfo.privacyPolicyURL` / `termsOfUseURL` are non-nil.
struct LegalDocumentView: View {
    let title: String
    let url: URL

    @Environment(NetworkMonitor.self) private var network
    @Environment(\.dismiss) private var dismiss
    @State private var attemptID = 0

    var body: some View {
        if network.isOnline {
            SafariView(url: url)
                .id(attemptID)
                .ignoresSafeArea()
                .accessibilityLabel(title)
        } else {
            NavigationStack {
                ContentUnavailableView {
                    Label(CopyDeck.About.offlineTitle, systemImage: "wifi.slash")
                } description: {
                    Text(CopyDeck.About.offlineMessage)
                } actions: {
                    Button(CopyDeck.About.retry) { attemptID += 1 }
                        .buttonStyle(.faxitPrimary)
                }
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(CopyDeck.About.done) { dismiss() }
                    }
                }
            }
        }
    }
}

/// Identifiable payload for `.sheet(item:)`.
struct LegalDocument: Identifiable, Hashable {
    let title: String
    let url: URL
    var id: URL { url }
}

private struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.dismissButtonStyle = .done
        return controller
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
