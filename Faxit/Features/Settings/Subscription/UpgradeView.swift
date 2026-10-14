import SwiftUI
import StoreKit
import SafariServices

/// The Plus plan paywall: the Send plans (weekly, monthly, yearly, each with
/// a page allowance) with the Receive
/// number subscription below it. Pushed from Settings or shown in
/// a sheet; when shown in a sheet, the presenter supplies the close button so
/// a pushed copy never shows two ways out. Prices and periods come only from
/// StoreKit — while they load, rows are redacted skeletons, never a guess.
struct UpgradeView: View {
    @Environment(StoreManager.self) private var storeManager
    @Environment(NetworkMonitor.self) private var networkMonitor
    @Environment(AppSettingsStore.self) private var settingsStore
    @Environment(AppNavigation.self) private var navigation: AppNavigation?
    @Environment(\.dismiss) private var dismiss

    @State private var selectedProductID = FaxPricing.SendPlan.monthly.productID
    @State private var purchaseState: PurchaseState = .idle
    @State private var safariURL: IdentifiableURL?

    private enum PurchaseState: Equatable {
        case idle
        case purchasing
        /// Ask to Buy: waiting for whoever approves purchases on this Apple ID.
        case pending
        case failed
    }

    /// Weekly, monthly, yearly — each shown with equal weight.
    private var plans: [Product] {
        FaxPricing.SendPlan.allCases.compactMap { storeManager.product(for: $0) }
    }

    private var selectedProduct: Product? {
        plans.first { $0.id == selectedProductID } ?? plans.first
    }

    private var canPurchase: Bool {
        selectedProduct != nil && networkMonitor.isOnline && purchaseState != .purchasing
    }

    var body: some View {
        Group {
            if !storeManager.hasLoadedEntitlements {
                ProgressView(CopyDeck.Subscription.checkingSubscription)
                    .font(.faxitBody)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if storeManager.hasActiveSendPlan {
                subscribedContent
            } else {
                paywall
            }
        }
        .background(Color.faxitMintBackground.ignoresSafeArea())
        .navigationTitle(CopyDeck.Subscription.upgradeTitle)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $safariURL) { item in
            SafariView(url: item.url)
                .ignoresSafeArea()
        }
    }

    // MARK: Already subscribed

    private var subscribedContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.faxitLargeTitle)
                    .foregroundStyle(Color.faxitStatusGreen)
                    .accessibilityHidden(true)
                Text(CopyDeck.Subscription.subscribedTitle)
                    .font(.faxitHero)
                    .foregroundStyle(Color.faxitInkPrimary)
                    .multilineTextAlignment(.center)
                if let active = storeManager.activeSendPlan {
                    Text(CopyDeck.SendPlan.allowance(active.plan))
                        .font(.faxitBody)
                        .foregroundStyle(Color.faxitInkSecondary)
                        .multilineTextAlignment(.center)
                }
                NavigationLink {
                    ManageSubscriptionView()
                } label: {
                    Text(CopyDeck.Subscription.manageSubscription)
                }
                .buttonStyle(.faxitSecondary)
                .padding(.top, 8)
                receiveSection
                    .padding(.top, 16)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: Paywall

    private var paywall: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if !networkMonitor.isOnline {
                    banner(CopyDeck.Subscription.offlineBanner, systemImage: "wifi.slash", tint: .faxitStatusAmber)
                }
                header
                benefits
                planSection
                purchaseSection
                receiveSection
                RestorePurchasesButton()
                    .buttonStyle(.faxitSecondary)
                legalLinks
            }
            .padding(20)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(CopyDeck.Subscription.headline)
                .font(.faxitHero)
                .foregroundStyle(Color.faxitInkPrimary)
                .accessibilityAddTraits(.isHeader)
            Text(CopyDeck.Subscription.subheadline)
                .font(.faxitBody)
                .foregroundStyle(Color.faxitInkSecondary)
        }
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(CopyDeck.Subscription.benefits, id: \.self) { benefit in
                Label {
                    Text(benefit)
                        .font(.faxitBody)
                        .foregroundStyle(Color.faxitInkPrimary)
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.faxitAccent)
                }
            }
        }
    }

    @ViewBuilder
    private var planSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(CopyDeck.Subscription.choosePlan)
                .font(.faxitSectionHeader)
                .foregroundStyle(Color.faxitInkPrimary)
                .accessibilityAddTraits(.isHeader)

            if storeManager.isLoadingProducts {
                VStack(spacing: 12) {
                    ForEach(0..<FaxPricing.SendPlan.allCases.count, id: \.self) { _ in
                        planRowContent(
                            title: CopyDeck.Subscription.loadingPlanTitle,
                            subtitle: CopyDeck.Subscription.loadingPlanTitle,
                            price: CopyDeck.Subscription.loadingPlanPrice,
                            isSelected: false
                        )
                    }
                }
                .redacted(reason: .placeholder)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(CopyDeck.Billing.loadingPrices)
            } else if plans.isEmpty {
                pricesUnavailable
            } else {
                ForEach(plans, id: \.id) { product in
                    Button {
                        selectedProductID = product.id
                    } label: {
                        planRowContent(
                            title: planName(for: product),
                            subtitle: FaxPricing.SendPlan(productID: product.id).map(CopyDeck.SendPlan.allowance) ?? "",
                            price: priceText(for: product),
                            isSelected: product.id == selectedProduct?.id
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(product.id == selectedProduct?.id ? [.isSelected] : [])
                }
            }
        }
    }

    private func planRowContent(title: String, subtitle: String, price: String, isSelected: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                .font(.faxitTitle3)
                .foregroundStyle(isSelected ? Color.faxitAccent : Color.faxitInkSecondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.faxitSectionHeader)
                    .foregroundStyle(Color.faxitInkPrimary)
                Text(subtitle)
                    .font(.faxitCaption)
                    .foregroundStyle(Color.faxitInkSecondary)
            }
            Spacer(minLength: 8)
            Text(price)
                .font(.faxitBodySemibold)
                .foregroundStyle(Color.faxitInkPrimary)
                .multilineTextAlignment(.trailing)
        }
        .padding(16)
        .frame(minHeight: 44)
        .background(Color.faxitCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(isSelected ? Color.faxitAccent : Color.clear, lineWidth: 2)
        )
        .contentShape(Rectangle())
    }

    private var pricesUnavailable: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(CopyDeck.Subscription.pricesUnavailableTitle)
                .font(.faxitSectionHeader)
                .foregroundStyle(Color.faxitInkPrimary)
            Text(CopyDeck.Subscription.pricesUnavailableMessage)
                .font(.faxitBody)
                .foregroundStyle(Color.faxitInkSecondary)
            Button(CopyDeck.Subscription.retry) {
                Task { await storeManager.reloadProducts() }
            }
            .buttonStyle(.faxitSecondary)
        }
        .padding(16)
        .background(Color.faxitCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var purchaseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch purchaseState {
            case .pending:
                banner(
                    "\(CopyDeck.Subscription.pendingTitle). \(CopyDeck.Subscription.pendingMessage)",
                    systemImage: "hourglass",
                    tint: .faxitStatusAmber
                )
            case .failed:
                VStack(alignment: .leading, spacing: 8) {
                    banner(
                        "\(CopyDeck.Subscription.purchaseFailedTitle). \(CopyDeck.Subscription.purchaseFailedMessage)",
                        systemImage: "exclamationmark.triangle.fill",
                        tint: .faxitStatusRed
                    )
                    Button(CopyDeck.Subscription.retry) {
                        Task { await purchase() }
                    }
                    .buttonStyle(.faxitSecondary)
                    .disabled(!canPurchase)
                }
            case .idle, .purchasing:
                EmptyView()
            }

            Button {
                Task { await purchase() }
            } label: {
                HStack(spacing: 8) {
                    if purchaseState == .purchasing {
                        ProgressView().tint(.white)
                    }
                    Text(purchaseButtonTitle)
                }
                .frame(minHeight: 22)
            }
            .buttonStyle(PrimaryButtonStyle(isDisabled: !canPurchase))
            .disabled(!canPurchase)

            if let product = selectedProduct, let period = product.subscription?.subscriptionPeriod {
                Text(CopyDeck.Subscription.renewalTerms(
                    price: product.displayPrice,
                    period: CopyDeck.Subscription.periodText(period)
                ))
                .font(.faxitCaption)
                .foregroundStyle(Color.faxitInkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var legalLinks: some View {
        if AppInfo.termsOfUseURL != nil || AppInfo.privacyPolicyURL != nil {
            HStack(spacing: 24) {
                if let url = AppInfo.termsOfUseURL {
                    legalLink(CopyDeck.Subscription.termsOfUse, url: url)
                }
                if let url = AppInfo.privacyPolicyURL {
                    legalLink(CopyDeck.Subscription.privacyPolicy, url: url)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func legalLink(_ title: String, url: URL) -> some View {
        Button(title) { safariURL = IdentifiableURL(url: url) }
            .font(.faxitCaption)
            .frame(minHeight: 44)
    }

    // MARK: Receive (fax number subscription)

    /// Number rental is bought together with picking the number, so the
    /// button opens the number picker, which handles purchase and assignment.
    private var receiveSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(CopyDeck.Subscription.receiveHeader)
                .font(.faxitSectionHeader)
                .foregroundStyle(Color.faxitInkPrimary)
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(CopyDeck.Subscription.receivePlanName)
                        .font(.faxitSectionHeader)
                        .foregroundStyle(Color.faxitInkPrimary)
                    Spacer(minLength: 8)
                    if storeManager.isLoadingProducts {
                        Text(CopyDeck.Subscription.loadingPlanPrice)
                            .font(.faxitBodySemibold)
                            .redacted(reason: .placeholder)
                    } else if let product = storeManager.numberRentalProduct {
                        Text(priceText(for: product))
                            .font(.faxitBodySemibold)
                            .foregroundStyle(Color.faxitInkPrimary)
                    }
                }
                Text(CopyDeck.Subscription.receiveDescription)
                    .font(.faxitBody)
                    .foregroundStyle(Color.faxitInkSecondary)

                if storeManager.hasActiveNumberRental {
                    Label(
                        settingsStore.settings.ownFaxNumber.map { CopyDeck.Subscription.receiveActiveWithNumber($0) }
                            ?? CopyDeck.Subscription.receiveActive,
                        systemImage: "checkmark.circle.fill"
                    )
                    .font(.faxitBodySemibold)
                    .foregroundStyle(Color.faxitStatusGreen)
                } else if !storeManager.isLoadingProducts && storeManager.numberRentalProduct == nil {
                    Text(CopyDeck.Subscription.pricesUnavailableMessage)
                        .font(.faxitCaption)
                        .foregroundStyle(Color.faxitInkSecondary)
                } else {
                    NavigationLink {
                        NumberProvisioningView(provider: FaxProviderContainer.shared, showsCloseButton: false)
                    } label: {
                        Text(CopyDeck.Subscription.receiveAction)
                    }
                    .buttonStyle(.faxitSecondary)
                    .disabled(!networkMonitor.isOnline)
                    if let product = storeManager.numberRentalProduct, let period = product.subscription?.subscriptionPeriod {
                        Text(CopyDeck.Subscription.renewalTerms(
                            price: product.displayPrice,
                            period: CopyDeck.Subscription.periodText(period)
                        ))
                        .font(.faxitCaption)
                        .foregroundStyle(Color.faxitInkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.faxitCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func banner(_ text: String, systemImage: String, tint: Color) -> some View {
        Label {
            Text(text)
                .font(.faxitBody)
                .foregroundStyle(Color.faxitInkPrimary)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: Helpers

    private var purchaseButtonTitle: String {
        guard let product = selectedProduct, let period = product.subscription?.subscriptionPeriod else {
            return CopyDeck.Subscription.subscribe
        }
        return CopyDeck.Subscription.subscribeFor(
            price: product.displayPrice,
            period: CopyDeck.Subscription.periodText(period)
        )
    }

    private func planName(for product: Product) -> String {
        FaxPricing.SendPlan(productID: product.id).map(CopyDeck.SendPlan.name) ?? product.displayName
    }

    private func priceText(for product: Product) -> String {
        guard let period = product.subscription?.subscriptionPeriod else { return product.displayPrice }
        return "\(product.displayPrice)/\(CopyDeck.Subscription.periodText(period))"
    }

    private func purchase() async {
        guard let product = selectedProduct, networkMonitor.isOnline else { return }
        purchaseState = .purchasing
        do {
            switch try await storeManager.purchase(product) {
            case .purchased:
                // hasActiveSendPlan flips and the view shows the subscribed state.
                purchaseState = .idle
            case .pending:
                purchaseState = .pending
            case .cancelled:
                purchaseState = .idle
            }
        } catch {
            purchaseState = .failed
        }
    }
}

private struct IdentifiableURL: Identifiable {
    let url: URL
    var id: URL { url }
}

/// Terms and Privacy open in-app so the paywall stays where it was.
private struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
