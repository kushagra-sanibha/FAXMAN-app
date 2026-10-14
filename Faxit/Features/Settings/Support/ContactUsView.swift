import SwiftUI
import UIKit

/// Support email only — no form. Works offline: the address is always shown.
struct ContactUsView: View {
    @Environment(\.openURL) private var openURL
    @State private var showNoMailApp = false
    @State private var copied = false

    private var mailURL: URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = AppInfo.supportEmail
        components.queryItems = [URLQueryItem(name: "subject", value: CopyDeck.Support.emailSubject)]
        return components.url
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(CopyDeck.Support.contactIntro)
                    .font(.faxitBody)
                    .foregroundStyle(Color.faxitInkPrimary)

                Text(AppInfo.supportEmail)
                    .font(.faxitSectionHeader)
                    .foregroundStyle(Color.faxitAccent)
                    .textSelection(.enabled)

                Text(CopyDeck.Support.contactPersonNote)
                    .font(.faxitCaption)
                    .foregroundStyle(Color.faxitInkSecondary)

                Button {
                    guard let mailURL else { showNoMailApp = true; return }
                    openURL(mailURL) { accepted in
                        if !accepted { showNoMailApp = true }
                    }
                } label: {
                    Label(CopyDeck.Support.sendEmail, systemImage: "envelope").frame(maxWidth: .infinity)
                }
                .buttonStyle(.faxitPrimary)

                Button {
                    UIPasteboard.general.string = AppInfo.supportEmail
                    copied = true
                } label: {
                    Label(copied ? CopyDeck.Support.copied : CopyDeck.Support.copyAddress,
                          systemImage: copied ? "checkmark" : "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.faxitSecondary)
                .sensoryFeedback(.success, trigger: copied) { _, new in new }

                if showNoMailApp {
                    Text(CopyDeck.Support.noMailApp)
                        .font(.faxitBody)
                        .foregroundStyle(Color.faxitStatusAmber)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding()
        }
        .background(Color.faxitMintBackground)
        .navigationTitle(CopyDeck.Support.contactTitle)
        .task(id: copied) {
            guard copied else { return }
            try? await Task.sleep(for: .seconds(2))
            copied = false
        }
    }
}
