import StoreKit

enum StoreError: Error {
    case verificationFailed
}

enum PurchaseOutcome {
    case purchased
    case cancelled
    /// Waiting on approval (e.g. Ask to Buy); completes later via Transaction.updates.
    case pending
}

/// One subscription as Apple currently sees it — the app only mirrors this.
struct SubscriptionDetail: Identifiable {
    enum State {
        case active
        /// Payment failed; Apple is retrying and access continues until `gracePeriodEndsAt`.
        case inGracePeriod
        /// Payment failed and the grace period (if any) is over; access is paused.
        case inBillingRetry
        case expired
        case revoked
    }

    let product: Product
    let state: State
    let willAutoRenew: Bool
    /// Next renewal, or the end date once auto-renew is off.
    let renewalOrExpirationDate: Date?
    let gracePeriodEndsAt: Date?

    var id: String { product.id }
}

/// Owns every real money transaction in the app: the Weekly, Monthly and
/// Yearly send plans (each with a page allowance) and the number rental
/// subscription. Nothing here ever blocks preparing a fax — purchase only
/// happens at the moment of sending, never earlier.
@Observable
final class StoreManager {
    private(set) var products: [String: Product] = [:]
    /// The send plan in effect and its current billing period; nil without one.
    private(set) var activeSendPlan: ActiveSendPlan?
    private(set) var hasActiveNumberRental = false
    private(set) var isLoadingProducts = true
    /// False until StoreKit has answered once — before that,
    /// `hasActive…` are just defaults, not facts.
    private(set) var hasLoadedEntitlements = false
    /// Product IDs of every current entitlement.
    private(set) var activeSubscriptionIDs: Set<String> = []

    private var transactionListener: Task<Void, Never>?

    init() {
        transactionListener = Task { [weak self] in
            await self?.observeTransactionUpdates()
        }
        // Independent: a slow or failing product lookup must not keep
        // "do they own a plan?" unanswered.
        Task { [weak self] in
            await self?.refreshEntitlements()
        }
        Task { [weak self] in
            await self?.loadProducts()
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    func product(for id: String) -> Product? { products[id] }

    func product(for plan: FaxPricing.SendPlan) -> Product? { products[plan.productID] }

    var hasActiveSendPlan: Bool { activeSendPlan != nil }

    private var subscriptionProducts: [Product] {
        (FaxPricing.SendPlan.allCases.map(\.productID) + [FaxPricing.numberRentalProductID]).compactMap { products[$0] }
    }

    var numberRentalProduct: Product? { products[FaxPricing.numberRentalProductID] }

    /// True once loading finished with nothing — show a retry, never a made-up price.
    var productsUnavailable: Bool { !isLoadingProducts && products.isEmpty }

    @MainActor
    func reloadProducts() async {
        isLoadingProducts = true
        await loadProducts()
    }

    @MainActor
    private func loadProducts() async {
        do {
            let loaded = try await Product.products(for: FaxPricing.allProductIDs)
            products = Dictionary(uniqueKeysWithValues: loaded.map { ($0.id, $0) })
        } catch {
            products = [:]
        }
        isLoadingProducts = false
    }

    /// Buys a product. Cancelled and pending are outcomes, not errors —
    /// the caller simply doesn't proceed.
    @MainActor
    @discardableResult
    func purchase(_ product: Product) async throws -> PurchaseOutcome {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try verify(verification)
            await transaction.finish()
            await refreshEntitlements()
            return .purchased
        case .pending:
            return .pending
        case .userCancelled:
            return .cancelled
        @unknown default:
            return .cancelled
        }
    }

    /// Asks Apple for this Apple ID's purchases. Returns the subscriptions
    /// that are active afterwards (empty = nothing found). Throws if the
    /// App Store couldn't be reached.
    @MainActor
    func restorePurchases() async throws -> [Product] {
        try await AppStore.sync()
        await refreshEntitlements()
        return activeSubscriptionProducts
    }

    /// Active subscriptions, for the restore result.
    var activeSubscriptionProducts: [Product] {
        subscriptionProducts.filter { activeSubscriptionIDs.contains($0.id) }
    }

    /// Every subscription this Apple ID has a status for, as Apple sees it now.
    @MainActor
    func subscriptionDetails() async -> [SubscriptionDetail] {
        var details: [SubscriptionDetail] = []
        for product in subscriptionProducts {
            guard let statuses = try? await product.subscription?.status else { continue }
            for status in statuses {
                guard let transaction = try? verify(status.transaction), transaction.productID == product.id else { continue }
                let renewalInfo = try? verify(status.renewalInfo)
                let state: SubscriptionDetail.State
                switch status.state {
                case .subscribed: state = .active
                case .inGracePeriod: state = .inGracePeriod
                case .inBillingRetryPeriod: state = .inBillingRetry
                case .revoked: state = .revoked
                default: state = .expired
                }
                let willAutoRenew = renewalInfo?.willAutoRenew ?? false
                details.append(SubscriptionDetail(
                    product: product,
                    state: state,
                    willAutoRenew: willAutoRenew,
                    renewalOrExpirationDate: willAutoRenew ? (renewalInfo?.renewalDate ?? transaction.expirationDate) : transaction.expirationDate,
                    gracePeriodEndsAt: renewalInfo?.gracePeriodExpirationDate
                ))
                break
            }
        }
        return details
    }

    @MainActor
    func refreshEntitlements() async {
        var activeIDs: Set<String> = []
        var plans: [ActiveSendPlan] = []
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? verify(result) else { continue }
            guard transaction.revocationDate == nil else { continue }
            activeIDs.insert(transaction.productID)
            if let plan = FaxPricing.SendPlan(productID: transaction.productID) {
                // A renewal is a new transaction, so its purchase date is
                // the start of the current billing period.
                plans.append(ActiveSendPlan(plan: plan, periodStart: transaction.purchaseDate, periodEnd: transaction.expirationDate))
            }
        }
        activeSubscriptionIDs = activeIDs
        // Plans share one subscription group, so normally there's one; if
        // Apple briefly reports two (mid-switch), the bigger allowance wins.
        activeSendPlan = plans.max { $0.plan.pageLimit < $1.plan.pageLimit }
        hasActiveNumberRental = activeIDs.contains(FaxPricing.numberRentalProductID)
        hasLoadedEntitlements = true
    }

    private func observeTransactionUpdates() async {
        for await result in Transaction.updates {
            guard let transaction = try? verify(result) else { continue }
            await transaction.finish()
            await refreshEntitlements()
        }
    }

    private func verify<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.verificationFailed
        case .verified(let value):
            return value
        }
    }
}
