import SwiftUI

/// About screen. Rows backed by nil `AppInfo` values are hidden.
struct AppInfoView: View {
    @Environment(\.openURL) private var openURL
    @State private var legalDocument: LegalDocument?

    private var currentYear: Int { Calendar.current.component(.year, from: .now) }

    var body: some View {
        List {
            Section(CopyDeck.About.appSection) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(AppInfo.appName)
                        .font(.faxitSectionHeader)
                        .foregroundStyle(Color.faxitInkPrimary)
                    Text(AppInfo.versionAndBuild)
                        .font(.faxitBody)
                        .foregroundStyle(Color.faxitInkSecondary)
                        .textSelection(.enabled)
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
                .accessibilityHint(CopyDeck.About.copyVersionHint)

                if let company = AppInfo.companyName {
                    LabeledContent(CopyDeck.About.company) {
                        Text(company).textSelection(.enabled)
                    }
                }
                if let city = AppInfo.companyCity {
                    LabeledContent(CopyDeck.About.location, value: city)
                }
                if let website = AppInfo.websiteURL {
                    Link(destination: website) {
                        LabeledContent(CopyDeck.About.website, value: website.host() ?? website.absoluteString)
                    }
                }
                Button {
                    if let url = AppInfo.supportEmailURL { openURL(url) }
                } label: {
                    LabeledContent(CopyDeck.About.support) {
                        Text(AppInfo.supportEmail)
                            .foregroundStyle(Color.faxitAccent)
                            .textSelection(.enabled)
                    }
                    .foregroundStyle(Color.faxitInkPrimary)
                }
            }

            Section(CopyDeck.About.legalSection) {
                NavigationLink(CopyDeck.About.licenses) { LicensesView() }
                if let url = AppInfo.privacyPolicyURL {
                    legalButton(CopyDeck.About.privacyPolicy, url: url)
                }
                if let url = AppInfo.termsOfUseURL {
                    legalButton(CopyDeck.About.termsOfUse, url: url)
                }
            }

            if let company = AppInfo.companyName {
                Section {
                    Text(CopyDeck.About.copyright(year: currentYear, company: company))
                        .font(.faxitCaption)
                        .foregroundStyle(Color.faxitInkSecondary)
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.faxitMintBackground)
        .navigationTitle(CopyDeck.About.title)
        .sheet(item: $legalDocument) { doc in
            LegalDocumentView(title: doc.title, url: doc.url)
        }
    }

    private func legalButton(_ title: String, url: URL) -> some View {
        Button {
            legalDocument = LegalDocument(title: title, url: url)
        } label: {
            HStack {
                Text(title).foregroundStyle(Color.faxitInkPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.faxitCaption)
                    .foregroundStyle(Color.faxitInkSecondary)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
    }
}
