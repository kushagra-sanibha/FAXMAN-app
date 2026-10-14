import Foundation

/// The send plan this Apple ID is on right now and its current billing
/// period, as StoreKit reports it.
struct ActiveSendPlan: Equatable {
    let plan: FaxPricing.SendPlan
    /// Start of the current billing period (the latest purchase or renewal).
    let periodStart: Date
    /// When the current period ends (renews or expires).
    let periodEnd: Date?
}

/// Pages left on the active plan for the current billing period.
///
/// A fax uses its document pages (the cover is free) the moment it's
/// created. A fax that finally fails gives its pages back, and retrying a
/// fax reuses the same record, so a retry never uses pages twice.
struct PlanAllowance: Equatable {
    let active: ActiveSendPlan
    let pagesUsed: Int

    init(active: ActiveSendPlan, faxes: [SentFax]) {
        self.active = active
        self.pagesUsed = Self.pagesUsed(by: faxes, since: active.periodStart)
    }

    var plan: FaxPricing.SendPlan { active.plan }
    var pagesLeft: Int { max(0, plan.pageLimit - pagesUsed) }

    func covers(pages: Int) -> Bool { pages <= pagesLeft }

    static func pagesUsed(by faxes: [SentFax], since periodStart: Date) -> Int {
        faxes
            .filter { $0.paymentMethod == .planAllowance && $0.createdAt >= periodStart && !$0.status.isFailure }
            .reduce(0) { $0 + $1.planPageCount }
    }
}
