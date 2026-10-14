import SwiftUI
import SwiftData
import StoreKit

/// Plan status, plan picker and the Send button, shared by both send
/// screens (PaywallView and ReviewSendView). Sending is only ever on a
/// Weekly, Monthly or Yearly plan: each fax uses its document pages from
/// the plan's allowance for the current billing period. A purchase only
/// ever happens here, at the moment of sending; retrying a failed fax later
/// reuses the same record and never uses pages or charges again.
struct SendPlanPanel: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(StoreManager.self) private var storeManager
    @Query(sort: \SentFax.createdAt, order: .reverse) private var recentFaxes: [SentFax]

    let submission: FaxSubmission
    let onSent: (SentFax) -> Void

    @State private var selectedPlan: FaxPricing.SendPlan?
    @State private var isPurchasing = false
    @State private var errorMessage: String?
    @State private var showPendingNotice = false
    @State private var showDuplicateConfirmation = false

    private var pagesNeeded: Int { submission.billablePageCount }

    private var allowance: PlanAllowance? {
        storeManager.activeSendPlan.map { PlanAllowance(active: $0, faxes: recentFaxes) }
    }

    private var canSendOnCurrentPlan: Bool {
        allowance?.covers(pages: pagesNeeded) ?? false
    }

    /// Without a plan: every plan. On a plan that's short for this fax:
    /// only bigger plans (switching starts a fresh period with the full
    /// allowance). Otherwise none.
    private var offeredPlans: [FaxPricing.SendPlan] {
        guard let allowance else { return FaxPricing.SendPlan.allCases }
        guard !allowance.covers(pages: pagesNeeded) else { return [] }
        return FaxPricing.SendPlan.allCases.filter { $0.pageLimit > allowance.plan.pageLimit && $0.pageLimit >= pagesNeeded }
    }

    /// The plan the button buys: the user's pick if it fits this fax,
    /// otherwise Monthly if it fits, otherwise the smallest that does.
    private var chosenPlan: FaxPricing.SendPlan? {
        let fitting = offeredPlans.filter { $0.pageLimit >= pagesNeeded }
        if let selectedPlan, fitting.contains(selectedPlan) { return selectedPlan }
        return fitting.contains(.monthly) ? .monthly : fitting.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !storeManager.hasLoadedEntitlements {
                HStack(spacing: 10) {
                    ProgressView()
                    Text(CopyDeck.SendPlan.checkingPlan)
                        .font(.faxitBody)
                        .foregroundStyle(Color.faxitInkSecondary)
                }
            } else {
                if let allowance {
                    statusCard(allowance)
                    if !allowance.covers(pages: pagesNeeded) {
                        shortfall(allowance)
                    }
                } else {
                    Text(CopyDeck.SendPlan.choosePlan)
                        .font(.faxitSectionHeader)
                        .foregroundStyle(Color.faxitInkPrimary)
                        .accessibilityAddTraits(.isHeader)
                }
                if !offeredPlans.isEmpty {
                    planRows
                }
            }

            sendButton

            Text("\(CopyDeck.SendPlan.faxUses(pagesNeeded)) \(CopyDeck.SendPlan.coverPageFree) \(CopyDeck.SendPlan.failedPagesReturned)")
                .font(.faxitCaption)
                .foregroundStyle(Color.faxitInkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .alert(CopyDeck.SendPlan.purchaseFailedTitle, isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .alert(CopyDeck.Subscription.pendingTitle, isPresented: $showPendingNotice) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(CopyDeck.SendPlan.pendingMessage)
        }
        .confirmationDialog(
            "You sent this fax a moment ago. Send it again?",
            isPresented: $showDuplicateConfirmation,
            titleVisibility: .visible
        ) {
            Button("Send again") { Task { await sendOrSubscribe() } }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: Plan status

    private func statusCard(_ allowance: PlanAllowance) -> some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 10) {
                    Image(systemName: allowance.covers(pages: pagesNeeded) ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .foregroundStyle(allowance.covers(pages: pagesNeeded) ? Color.faxitAccent : Color.faxitStatusAmber)
                        .accessibilityHidden(true)
                    Text(CopyDeck.SendPlan.status(allowance.plan, left: allowance.pagesLeft))
                        .font(.faxitBodySemibold)
                        .foregroundStyle(Color.faxitInkPrimary)
                }
                if let end = allowance.active.periodEnd {
                    Text(CopyDeck.SendPlan.resetsOn(CopyDeck.Subscription.dateText(end)))
                        .font(.faxitCaption)
                        .foregroundStyle(Color.faxitInkSecondary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    private func shortfall(_ allowance: PlanAllowance) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(allowance.active.periodEnd.map {
                CopyDeck.SendPlan.notEnoughPagesResets(needed: pagesNeeded, left: allowance.pagesLeft, date: CopyDeck.Subscription.dateText($0))
            } ?? CopyDeck.SendPlan.notEnoughPages(needed: pagesNeeded, left: allowance.pagesLeft))
            Text(offeredPlans.isEmpty ? CopyDeck.SendPlan.noBiggerPlan : CopyDeck.SendPlan.switchForMorePages)
        }
        .font(.faxitBody)
        .foregroundStyle(Color.faxitInkPrimary)
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: Plans

    @ViewBuilder
    private var planRows: some View {
        if storeManager.isLoadingProducts {
            VStack(spacing: 12) {
                ForEach(offeredPlans) { plan in
                    planRow(plan, price: CopyDeck.Subscription.loadingPlanPrice, isSelected: false, fits: true)
                }
            }
            .redacted(reason: .placeholder)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(CopyDeck.Billing.loadingPrices)
        } else if storeManager.productsUnavailable {
            VStack(alignment: .leading, spacing: 8) {
                Text(CopyDeck.Subscription.pricesUnavailableMessage)
                    .font(.faxitBody)
                    .foregroundStyle(Color.faxitInkSecondary)
                Button(CopyDeck.Subscription.retry) {
                    Task { await storeManager.reloadProducts() }
                }
                .buttonStyle(.faxitSecondary)
            }
        } else {
            VStack(spacing: 12) {
                ForEach(offeredPlans) { plan in
                    let fits = plan.pageLimit >= pagesNeeded
                    Button {
                        selectedPlan = plan
                    } label: {
                        planRow(plan, price: priceText(for: plan), isSelected: fits && plan == chosenPlan, fits: fits)
                    }
                    .buttonStyle(.plain)
                    .disabled(!fits || isPurchasing)
                    .accessibilityAddTraits(plan == chosenPlan ? [.isSelected] : [])
                }
            }
        }
    }

    private func planRow(_ plan: FaxPricing.SendPlan, price: String, isSelected: Bool, fits: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                .foregroundStyle(isSelected ? Color.faxitAccent : Color.faxitInkSecondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(CopyDeck.SendPlan.name(plan))
                    .font(.faxitBodySemibold)
                    .foregroundStyle(Color.faxitInkPrimary)
                Text(fits ? CopyDeck.SendPlan.allowance(plan) : CopyDeck.SendPlan.tooSmallForThisFax)
                    .font(.faxitCaption)
                    .foregroundStyle(Color.faxitInkSecondary)
            }
            Spacer(minLength: 8)
            Text(price)
                .font(.faxitBodySemibold)
                .foregroundStyle(Color.faxitInkPrimary)
        }
        .padding(16)
        .background(Color.faxitCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isSelected ? Color.faxitAccent : Color.faxitInkSecondary.opacity(0.15), lineWidth: isSelected ? 2 : 1)
        )
        .opacity(fits ? 1 : 0.5)
        .contentShape(Rectangle())
    }

    private func priceText(for plan: FaxPricing.SendPlan) -> String {
        guard let product = storeManager.product(for: plan) else { return CopyDeck.Billing.pricesUnavailable }
        guard let period = product.subscription?.subscriptionPeriod else { return product.displayPrice }
        return "\(product.displayPrice)/\(CopyDeck.Subscription.periodText(period))"
    }

    // MARK: Send

    private var buttonTitle: String {
        if canSendOnCurrentPlan || chosenPlan == nil { return CopyDeck.SendPlan.send }
        guard let plan = chosenPlan, let product = storeManager.product(for: plan) else { return CopyDeck.SendPlan.send }
        if allowance != nil { return CopyDeck.SendPlan.switchAndSend(plan) }
        let period = (product.subscription?.subscriptionPeriod).map(CopyDeck.Subscription.periodText) ?? CopyDeck.SendPlan.periodNoun(plan)
        return CopyDeck.SendPlan.subscribeAndSend(price: product.displayPrice, period: period)
    }

    private var isButtonEnabled: Bool {
        guard storeManager.hasLoadedEntitlements, !isPurchasing else { return false }
        if canSendOnCurrentPlan { return true }
        guard let plan = chosenPlan else { return false }
        return storeManager.product(for: plan) != nil
    }

    private var sendButton: some View {
        Button {
            attemptSend()
        } label: {
            if isPurchasing {
                ProgressView()
            } else {
                Text(buttonTitle)
            }
        }
        .buttonStyle(.faxitPrimary)
        .disabled(!isButtonEnabled)
    }

    private func attemptSend() {
        guard submission.hasValidRecipient else {
            errorMessage = CopyDeck.Review.numberFormatInvalid
            return
        }
        if submission.isRecentDuplicate(of: recentFaxes) {
            showDuplicateConfirmation = true
        } else {
            Task { await sendOrSubscribe() }
        }
    }

    /// Sends on the current plan if it has the pages; otherwise buys the
    /// chosen plan first and sends once it's active.
    private func sendOrSubscribe() async {
        guard submission.hasValidRecipient else {
            errorMessage = CopyDeck.Review.numberFormatInvalid
            return
        }
        if canSendOnCurrentPlan {
            send()
            return
        }
        guard let plan = chosenPlan, let product = storeManager.product(for: plan) else {
            errorMessage = CopyDeck.Review.pricingUnavailableMessage
            return
        }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            switch try await storeManager.purchase(product) {
            case .purchased:
                // purchase() refreshed the plan; the new period starts now.
                if canSendOnCurrentPlan {
                    send()
                } else if let allowance {
                    errorMessage = CopyDeck.SendPlan.notEnoughPages(needed: pagesNeeded, left: allowance.pagesLeft)
                }
            case .pending:
                showPendingNotice = true
            case .cancelled:
                break
            }
        } catch {
            errorMessage = CopyDeck.Review.purchaseFailedMessage
        }
    }

    private func send() {
        onSent(submission.makeSentFax(modelContext: modelContext))
    }
}
