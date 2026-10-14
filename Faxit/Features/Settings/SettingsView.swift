import SwiftUI

/// Settings home (Sanibha Common Screens Spec): one grouped list, every
/// screen at most two taps away. Rows needing a per-app value that isn't
/// set yet (AppInfo) are hidden rather than shown dead. The Language row
/// is hidden while the app is English-only.
struct SettingsView: View {
    @Environment(AppSettingsStore.self) private var settingsStore
    @Environment(StoreManager.self) private var storeManager
    @Environment(\.openURL) private var openURL

    @State private var legalDocument: LegalDocument?
    @State private var showScannerPreview = false
    @State private var useFaxitScanner = ScannerPreference.useFaxitScanner

    var body: some View {
        NavigationStack {
            List {
                #if DEBUG
                // Not in release builds: the new camera is still being tested.
                Section {
                    Toggle(CopyDeck.Scanner.useForScanning, isOn: Binding(
                        get: { useFaxitScanner },
                        set: { useFaxitScanner = $0; ScannerPreference.useFaxitScanner = $0 }
                    ))
                    .tint(.faxitAccent)
                    Button(CopyDeck.Scanner.previewEntry) { showScannerPreview = true }
                        .foregroundStyle(Color.faxitInkPrimary)
                } header: {
                    Text(CopyDeck.Scanner.developerSection)
                } footer: {
                    Text(CopyDeck.Scanner.useForScanningFooter)
                }
                #endif

                Section(CopyDeck.Settings.faxingSection) {
                    NavigationLink(CopyDeck.Settings.senderInformation) { SenderInfoView() }
                    NavigationLink(CopyDeck.Settings.defaultCoverPage) { DefaultCoverPageView() }
                    Picker(CopyDeck.Settings.paperSize, selection: Binding(
                        get: { settingsStore.settings.faxPaperSize },
                        set: { settingsStore.settings.faxPaperSize = $0; settingsStore.save() }
                    )) {
                        ForEach(FaxPaperSize.allCases) { Text($0.title).tag($0) }
                    }
                }

                Section(CopyDeck.Settings.subscriptionSection) {
                    if !storeManager.hasActiveSendPlan {
                        NavigationLink(CopyDeck.Settings.upgrade) { UpgradeView() }
                    }
                    if storeManager.hasActiveSendPlan || storeManager.hasActiveNumberRental {
                        NavigationLink(CopyDeck.Settings.manageSubscription) { ManageSubscriptionView() }
                    }
                    RestorePurchasesButton()
                }

                Section(CopyDeck.Settings.preferencesSection) {
                    NavigationLink(CopyDeck.Settings.notifications) { NotificationsSettingsView() }
                    NavigationLink(CopyDeck.Settings.access) { AccessView() }
                    Picker(CopyDeck.Settings.appearance, selection: Binding(
                        get: { settingsStore.appearanceMode ?? .light },
                        set: { settingsStore.appearanceMode = $0 }
                    )) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    NavigationLink(CopyDeck.Settings.appLock) { PrivacyPinView() }
                }

                Section(CopyDeck.Settings.yourDataSection) {
                    NavigationLink(CopyDeck.Settings.exportMyData) { ExportMyDataView() }
                }

                Section(CopyDeck.Settings.supportSection) {
                    NavigationLink(CopyDeck.Settings.help) { HelpView() }
                    NavigationLink(CopyDeck.Settings.contactUs) { ContactUsView() }
                    NavigationLink(CopyDeck.Settings.feedback) { FeedbackView() }
                }

                Section(CopyDeck.Settings.aboutSection) {
                    if let reviewURL = AppInfo.writeReviewURL {
                        Button(CopyDeck.Settings.rateOnAppStore) { openURL(reviewURL) }
                            .foregroundStyle(Color.faxitInkPrimary)
                    }
                    if let appStoreURL = AppInfo.appStoreURL, let message = AppInfo.shareMessage {
                        ShareLink(CopyDeck.Settings.shareApp, item: appStoreURL, message: Text(message))
                            .foregroundStyle(Color.faxitInkPrimary)
                    }
                    if let url = AppInfo.privacyPolicyURL {
                        Button(CopyDeck.Settings.privacyPolicy) {
                            legalDocument = LegalDocument(title: CopyDeck.Settings.privacyPolicy, url: url)
                        }
                        .foregroundStyle(Color.faxitInkPrimary)
                    } else {
                        // No hosted policy yet: show the in-app summary rather than a missing row.
                        NavigationLink(CopyDeck.Settings.privacyPolicy) { PrivacySummaryView() }
                    }
                    if let url = AppInfo.termsOfUseURL {
                        Button(CopyDeck.Settings.termsOfUse) {
                            legalDocument = LegalDocument(title: CopyDeck.Settings.termsOfUse, url: url)
                        }
                        .foregroundStyle(Color.faxitInkPrimary)
                    }
                    NavigationLink(CopyDeck.Settings.appInfo) { AppInfoView() }
                }

                // Kept apart from everyday rows.
                Section {
                    NavigationLink(CopyDeck.Settings.deleteMyData) { DeleteMyDataView() }
                        .foregroundStyle(Color.faxitStatusRed)
                } footer: {
                    Text("\(AppInfo.appName) · \(AppInfo.versionAndBuild)")
                        .font(.faxitCaption)
                        .foregroundStyle(Color.faxitInkSecondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 24)
                }
            }
            .navigationTitle(CopyDeck.Settings.title)
            .sheet(item: $legalDocument) { document in
                LegalDocumentView(title: document.title, url: document.url)
            }
            .fullScreenCover(isPresented: $showScannerPreview) {
                ScannerView(onFinish: { _ in showScannerPreview = false }, onCancel: { showScannerPreview = false })
            }
        }
    }
}
