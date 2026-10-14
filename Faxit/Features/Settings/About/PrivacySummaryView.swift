import SwiftUI

/// Plain-language summary of how Faxit handles data, shown in Settings until
/// a hosted, lawyer-reviewed policy URL is set in `AppInfo.privacyPolicyURL`
/// (which then replaces this screen). Every statement here is grounded in
/// what the app does today; update it if that changes.
struct PrivacySummaryView: View {
    private struct Item: Identifiable {
        let title: String
        let body: String
        var id: String { title }
    }

    private let items = [
        Item(title: "Your faxes stay on this iPhone",
             body: "Sent and received faxes, drafts, your saved signature and your sender details are stored on this device only. Faxit has no account and no sign-in."),
        Item(title: "What we send to deliver a fax",
             body: "When you send a fax, its pages and the recipient's number go to our fax provider so they can be delivered, and are removed afterward."),
        Item(title: "Camera",
             body: "Faxit uses your camera only to scan pages (or a signature) you choose. Photos you pick come through the system picker."),
        Item(title: "Payments",
             body: "Purchases are handled by Apple. Faxit never sees your payment details."),
        Item(title: "Export and feedback",
             body: "If you export your data, the email address you enter is used only to send that one download link, then deleted. An optional feedback email is used only to reply."),
        Item(title: "No tracking",
             body: "Faxit has no analytics or advertising tools and doesn't track you across other apps."),
        Item(title: "Your controls",
             body: "Export my data and Delete my data are in Settings. Deleting removes what's on this iPhone and asks our servers to delete anything stored under this app's anonymous ID."),
    ]

    var body: some View {
        List {
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title).font(.faxitSectionHeader)
                    Text(item.body)
                        .font(.faxitBody)
                        .foregroundStyle(Color.faxitInkSecondary)
                }
                .padding(.vertical, 4)
            }
            Section {
                Text("Questions? Email \(AppInfo.supportEmail).")
                    .font(.faxitCaption)
                    .foregroundStyle(Color.faxitInkSecondary)
                    .textSelection(.enabled)
            }
        }
        .navigationTitle(CopyDeck.Settings.privacyPolicy)
    }
}
