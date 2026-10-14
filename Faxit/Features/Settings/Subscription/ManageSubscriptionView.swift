import SwiftUI
import StoreKit

/// Mirrors what Apple reports for each Faxit subscription. Apple owns billing
/// and cancellation; this screen explains the state in plain words and hands
/// off to Apple's own sheet, then refreshes when the person comes back.
struct ManageSubscriptionView: View {
    @Environment(StoreManager.self) private var storeManager
    @Environment(NetworkMonitor.self) private var networkMonitor
    @Environment(AppNavigation.self) private var navigation: AppNavigation?
    @Environment(\.openURL) private var openURL

    @State private var details: [SubscriptionDetail] = []
    @State private var hasLoaded = false
    @State private var isRefreshing = false
    @State private var showAppleSheet = false
    @State private var cancelling: SubscriptionDetail?

    /// Apple's billing page, where payment methods are updated.
    private static let appleBillingURL = URL(string: "https://apps.apple.com/account/billing")!

    var body: some View {
        content
            .background(Color.faxitMintBackground.ignoresSafeArea())
            .navigationTitle(CopyDeck.Subscription.manageTitle)
            .navigationBarTitleDisplayMode(.inline)
            .task { await load() }
            .onChange(of: storeManager.isLoadingProducts) { _, isLoading in
                if !isLoading { Task { await load() } }
            }
            .onChange(of: storeManager.activeSubscriptionIDs) { _, _ in
                Task { await load() }
            }
            .onChange(of: networkMonitor.isOnline) { _, isOnline in
                if isOnline { Task { await load() } }
            }
            .manageSubscriptionsSheet(isPresented: $showAppleSheet)
            .onChange(of: showAppleSheet) { _, isShowing in
                if !isShowing { Task { await load() } }
            }
            .sheet(item: $cancelling, onDismiss: { Task { await load() } }) { detail in
                CancelSubscriptionFlow(detail: detail)
            }
    }

    @ViewBuilder
    private var content: some View {
        if !hasLoaded {
            if storeManager.productsUnavailable {
                // Without products there's nothing to ask Apple about yet.
                messageState(
                    title: networkMonitor.isOnline ? CopyDeck.Subscription.loadFailedTitle : CopyDeck.Subscription.restoreOfflineTitle,
                    message: networkMonitor.isOnline ? CopyDeck.Subscription.loadFailedMessage : CopyDeck.Subscription.offlineMessage,
                    systemImage: networkMonitor.isOnline ? "exclamationmark.triangle" : "wifi.slash"
                ) {
                    Button(CopyDeck.Subscription.retry) {
                        Task {
                            await storeManager.reloadProducts()
                            await load()
                        }
                    }
                    .buttonStyle(.faxitPrimary)
                }
            } else {
                ProgressView(CopyDeck.Subscription.loadingSubscriptions)
                    .font(.faxitBody)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else if details.isEmpty {
            if networkMonitor.isOnline {
                messageState(
                    title: CopyDeck.Subscription.emptyTitle,
                    message: CopyDeck.Subscription.emptyMessage,
                    systemImage: "creditcard"
                ) {
                    NavigationLink {
                        UpgradeView()
                    } label: {
                        Text(CopyDeck.Subscription.seeSendPlan)
                    }
                    .buttonStyle(.faxitPrimary)
                    RestorePurchasesButton()
                        .buttonStyle(.faxitSecondary)
                }
            } else {
                messageState(
                    title: CopyDeck.Subscription.restoreOfflineTitle,
                    message: CopyDeck.Subscription.offlineMessage,
                    systemImage: "wifi.slash"
                ) {
                    Button(CopyDeck.Subscription.retry) {
                        Task { await load() }
                    }
                    .buttonStyle(.faxitPrimary)
                }
            }
        } else {
            list
        }
    }

    private var list: some View {
        List {
            if !networkMonitor.isOnline {
                Section {
                    Label(CopyDeck.Subscription.offlineBannerManage, systemImage: "wifi.slash")
                        .font(.faxitBody)
                        .foregroundStyle(Color.faxitInkPrimary)
                }
            }

            ForEach(details) { detail in
                Section {
                    subscriptionSummary(detail)
                    actions(for: detail)
                }
            }

            if !storeManager.hasActiveSendPlan, !details.contains(where: isSendPlan) {
                Section {
                    NavigationLink(CopyDeck.Subscription.seeSendPlan) {
                        UpgradeView()
                    }
                }
            }

            Section {
                Button(CopyDeck.Subscription.openAppleSettings) {
                    showAppleSheet = true
                }
                .disabled(!networkMonitor.isOnline)
                RestorePurchasesButton()
            } footer: {
                Text(CopyDeck.Subscription.appleSettingsFootnote)
                    .font(.faxitCaption)
            }
        }
        .scrollContentBackground(.hidden)
        .refreshable { await load() }
        .overlay(alignment: .top) {
            if isRefreshing {
                ProgressView()
                    .padding(8)
                    .accessibilityLabel(CopyDeck.Subscription.loadingSubscriptions)
            }
        }
    }

    private func subscriptionSummary(_ detail: SubscriptionDetail) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(detail.product.displayName)
                    .font(.faxitSectionHeader)
                    .foregroundStyle(Color.faxitInkPrimary)
                Spacer(minLength: 8)
                Text(Self.priceText(detail.product))
                    .font(.faxitBody)
                    .foregroundStyle(Color.faxitInkSecondary)
            }
            Label {
                Text(Self.stateText(detail))
                    .font(.faxitBody)
                    .foregroundStyle(Color.faxitInkPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: Self.stateIcon(detail))
                    .foregroundStyle(Self.stateTint(detail))
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func actions(for detail: SubscriptionDetail) -> some View {
        switch detail.state {
        case .active:
            if detail.willAutoRenew {
                Button(CopyDeck.Subscription.cancelSubscription, role: .destructive) {
                    cancelling = detail
                }
            } else {
                Button(CopyDeck.Subscription.turnRenewalBackOn) {
                    showAppleSheet = true
                }
                .disabled(!networkMonitor.isOnline)
            }
        case .inGracePeriod, .inBillingRetry:
            Button(CopyDeck.Subscription.updatePayment) {
                openURL(Self.appleBillingURL)
            }
            if detail.willAutoRenew {
                Button(CopyDeck.Subscription.cancelSubscription, role: .destructive) {
                    cancelling = detail
                }
            }
        case .expired, .revoked:
            if isSendPlan(detail) {
                NavigationLink(CopyDeck.Subscription.subscribeAgain) {
                    UpgradeView()
                }
            } else if let navigation {
                Button(CopyDeck.Subscription.goToReceive) {
                    navigation.selectedTab = .receive
                }
            }
        }
    }

    private func messageState<Actions: View>(
        title: String,
        message: String,
        systemImage: String,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: systemImage)
                    .font(.faxitLargeTitle)
                    .foregroundStyle(Color.faxitAccent)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.faxitSectionHeader)
                    .foregroundStyle(Color.faxitInkPrimary)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text(message)
                    .font(.faxitBody)
                    .foregroundStyle(Color.faxitInkSecondary)
                    .multilineTextAlignment(.center)
                VStack(spacing: 12) {
                    actions()
                }
                .padding(.top, 8)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
        }
    }

    private func isSendPlan(_ detail: SubscriptionDetail) -> Bool {
        FaxPricing.SendPlan(productID: detail.product.id) != nil
    }

    private func load() async {
        // Products arrive asynchronously at launch; asking Apple before then
        // would wrongly look like "no subscriptions".
        guard !storeManager.isLoadingProducts, !storeManager.products.isEmpty else { return }
        if hasLoaded { isRefreshing = true }
        await storeManager.refreshEntitlements()
        details = await storeManager.subscriptionDetails()
        hasLoaded = true
        isRefreshing = false
    }

    // MARK: Text

    static func priceText(_ product: Product) -> String {
        guard let period = product.subscription?.subscriptionPeriod else { return product.displayPrice }
        return "\(product.displayPrice)/\(CopyDeck.Subscription.periodText(period))"
    }

    static func stateText(_ detail: SubscriptionDetail) -> String {
        let date = detail.renewalOrExpirationDate.map { CopyDeck.Subscription.dateText($0) }
        switch detail.state {
        case .active:
            if detail.willAutoRenew {
                return date.map { CopyDeck.Subscription.renewsOn($0) } ?? CopyDeck.Subscription.activeNoDate
            }
            return date.map { CopyDeck.Subscription.endsOn($0) } ?? CopyDeck.Subscription.endsNoDate
        case .inGracePeriod:
            return detail.gracePeriodEndsAt
                .map { CopyDeck.Subscription.gracePeriod(CopyDeck.Subscription.dateText($0)) }
                ?? CopyDeck.Subscription.gracePeriodNoDate
        case .inBillingRetry:
            return CopyDeck.Subscription.billingRetry
        case .expired:
            return date.map { CopyDeck.Subscription.expiredOn($0) } ?? CopyDeck.Subscription.expiredNoDate
        case .revoked:
            return CopyDeck.Subscription.revoked
        }
    }

    private static func stateIcon(_ detail: SubscriptionDetail) -> String {
        switch detail.state {
        case .active: detail.willAutoRenew ? "checkmark.circle.fill" : "calendar.badge.clock"
        case .inGracePeriod, .inBillingRetry: "exclamationmark.triangle.fill"
        case .expired, .revoked: "xmark.circle"
        }
    }

    private static func stateTint(_ detail: SubscriptionDetail) -> Color {
        switch detail.state {
        case .active: detail.willAutoRenew ? .faxitStatusGreen : .faxitStatusAmber
        case .inGracePeriod: .faxitStatusAmber
        case .inBillingRetry: .faxitStatusRed
        case .expired, .revoked: .faxitInkSecondary
        }
    }
}

// MARK: - Cancellation flow

/// Three steps: what changes → confirm → Apple's own sheet, then a plain
/// confirmation of the date the person will see. No discounts, no guilt.
private struct CancelSubscriptionFlow: View {
    let detail: SubscriptionDetail

    @Environment(StoreManager.self) private var storeManager
    @Environment(NetworkMonitor.self) private var networkMonitor
    @Environment(AppSettingsStore.self) private var settingsStore
    @Environment(\.dismiss) private var dismiss

    private enum Step {
        case whatChanges
        case confirm
        case apple
    }

    private enum CheckResult {
        case ends(Date?)
        case stillRenewing(Date?)
        case unknown
    }

    @State private var step: Step = .whatChanges
    @State private var showAppleSheet = false
    @State private var isChecking = false
    @State private var result: CheckResult?

    private var planName: String { detail.product.displayName }

    private var isNumberRental: Bool { detail.product.id == FaxPricing.numberRentalProductID }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch step {
                    case .whatChanges: whatChanges
                    case .confirm: confirm
                    case .apple: apple
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.faxitMintBackground.ignoresSafeArea())
            .navigationTitle(CopyDeck.Subscription.cancelFlowTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel(CopyDeck.Subscription.close)
                }
            }
            .manageSubscriptionsSheet(isPresented: $showAppleSheet)
            .onChange(of: showAppleSheet) { _, isShowing in
                if !isShowing { Task { await checkResult() } }
            }
        }
    }

    // Step 1
    private var whatChanges: some View {
        VStack(alignment: .leading, spacing: 16) {
            title(CopyDeck.Subscription.stepOneTitle)
            Text(planName)
                .font(.faxitSectionHeader)
                .foregroundStyle(Color.faxitInkSecondary)
            bullet(
                isNumberRental
                    ? CopyDeck.Subscription.numberLoss(settingsStore.settings.ownFaxNumber)
                    : CopyDeck.Subscription.sendPlanLoss,
                systemImage: "minus.circle"
            )
            bullet(CopyDeck.Subscription.keepsData, systemImage: "iphone")
            bullet(
                detail.renewalOrExpirationDate
                    .map { CopyDeck.Subscription.accessUntil(CopyDeck.Subscription.dateText($0)) }
                    ?? CopyDeck.Subscription.accessUntilNoDate,
                systemImage: "calendar"
            )
            choiceButtons(continueTitle: CopyDeck.Subscription.continueAction) {
                step = .confirm
            }
        }
    }

    // Step 2
    private var confirm: some View {
        VStack(alignment: .leading, spacing: 16) {
            title(CopyDeck.Subscription.stepTwoTitle)
            paragraph(CopyDeck.Subscription.stepTwoMessage)
            if !networkMonitor.isOnline {
                Label(CopyDeck.Subscription.stepTwoOffline, systemImage: "wifi.slash")
                    .font(.faxitBody)
                    .foregroundStyle(Color.faxitInkPrimary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.faxitStatusAmber.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            choiceButtons(
                continueTitle: CopyDeck.Subscription.continueToCancel,
                continueDisabled: !networkMonitor.isOnline
            ) {
                step = .apple
                showAppleSheet = true
            }
        }
    }

    // Step 3
    @ViewBuilder
    private var apple: some View {
        if isChecking {
            ProgressView(CopyDeck.Subscription.checkingResult)
                .font(.faxitBody)
                .frame(maxWidth: .infinity)
        } else if let result {
            VStack(alignment: .leading, spacing: 16) {
                Label {
                    Text(resultText(result))
                        .font(.faxitBody)
                        .foregroundStyle(Color.faxitInkPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: resultIcon(result))
                        .foregroundStyle(Color.faxitAccent)
                }
                Button(CopyDeck.Subscription.done) { dismiss() }
                    .buttonStyle(.faxitPrimary)
                if case .unknown = result {
                    Button(CopyDeck.Subscription.retry) {
                        Task { await checkResult() }
                    }
                    .buttonStyle(.faxitSecondary)
                }
                if case .stillRenewing = result {
                    Button(CopyDeck.Subscription.openAppleSettings) {
                        showAppleSheet = true
                    }
                    .buttonStyle(.faxitSecondary)
                    .disabled(!networkMonitor.isOnline)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 16) {
                title(CopyDeck.Subscription.stepThreeTitle)
                paragraph(CopyDeck.Subscription.stepThreeMessage)
                Button(CopyDeck.Subscription.openAppleSettings) {
                    showAppleSheet = true
                }
                .buttonStyle(.faxitPrimary)
                .disabled(!networkMonitor.isOnline)
            }
        }
    }

    // MARK: Pieces

    private func title(_ text: String) -> some View {
        Text(text)
            .font(.faxitHero)
            .foregroundStyle(Color.faxitInkPrimary)
            .accessibilityAddTraits(.isHeader)
    }

    private func paragraph(_ text: String) -> some View {
        Text(text)
            .font(.faxitBody)
            .foregroundStyle(Color.faxitInkSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func bullet(_ text: String, systemImage: String) -> some View {
        Label {
            Text(text)
                .font(.faxitBody)
                .foregroundStyle(Color.faxitInkPrimary)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(Color.faxitAccent)
        }
    }

    /// The two choices carry equal visual weight: neither is pushed.
    private func choiceButtons(
        continueTitle: String,
        continueDisabled: Bool = false,
        onContinue: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 12) {
            Button(CopyDeck.Subscription.keepSubscription) { dismiss() }
                .buttonStyle(.faxitSecondary)
            Button(continueTitle, action: onContinue)
                .buttonStyle(.faxitSecondary)
                .disabled(continueDisabled)
                .opacity(continueDisabled ? 0.5 : 1)
        }
        .padding(.top, 8)
    }

    private func resultText(_ result: CheckResult) -> String {
        switch result {
        case .ends(let date):
            date.map { CopyDeck.Subscription.endsConfirmation(plan: planName, date: CopyDeck.Subscription.dateText($0)) }
                ?? CopyDeck.Subscription.endsConfirmationNoDate(plan: planName)
        case .stillRenewing(let date):
            date.map { CopyDeck.Subscription.stillRenewing(plan: planName, date: CopyDeck.Subscription.dateText($0)) }
                ?? CopyDeck.Subscription.stillRenewingNoDate(plan: planName)
        case .unknown:
            CopyDeck.Subscription.resultUnknown
        }
    }

    private func resultIcon(_ result: CheckResult) -> String {
        switch result {
        case .ends: "calendar"
        case .stillRenewing: "checkmark.circle"
        case .unknown: "questionmark.circle"
        }
    }

    private func checkResult() async {
        isChecking = true
        await storeManager.refreshEntitlements()
        let latest = await storeManager.subscriptionDetails().first { $0.id == detail.id }
        if let latest {
            result = latest.willAutoRenew
                ? .stillRenewing(latest.renewalOrExpirationDate)
                : .ends(latest.renewalOrExpirationDate)
        } else {
            result = .unknown
        }
        isChecking = false
    }
}
