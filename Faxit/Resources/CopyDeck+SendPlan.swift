import Foundation

extension CopyDeck {
    /// Send plans (Weekly / Monthly / Yearly) and their page allowances.
    /// Prices always come from StoreKit — nothing here holds a price.
    enum SendPlan {
        static func name(_ plan: FaxPricing.SendPlan) -> String {
            switch plan {
            case .weekly: "Weekly"
            case .monthly: "Monthly"
            case .yearly: "Yearly"
            }
        }

        static func periodNoun(_ plan: FaxPricing.SendPlan) -> String {
            switch plan {
            case .weekly: "week"
            case .monthly: "month"
            case .yearly: "year"
            }
        }

        /// "100 pages a month"
        static func allowance(_ plan: FaxPricing.SendPlan) -> String {
            "\(plan.pageLimit.formatted()) pages a \(periodNoun(plan))"
        }

        static func pages(_ count: Int) -> String {
            count == 1 ? "1 page" : "\(count.formatted()) pages"
        }

        static let choosePlan = "Choose a plan to send"
        static let checkingPlan = "Checking your plan…"
        static let tooSmallForThisFax = "Not enough pages for this fax"
        static let coverPageFree = "The cover page is free and doesn't use your pages."
        static let failedPagesReturned = "If a fax can't be delivered, its pages are given back."

        /// "Monthly plan · 82 of 100 pages left"
        static func status(_ plan: FaxPricing.SendPlan, left: Int) -> String {
            "\(name(plan)) plan · \(left.formatted()) of \(plan.pageLimit.formatted()) pages left"
        }

        static func resetsOn(_ date: String) -> String { "Resets on \(date)" }

        /// "This fax uses 12 pages."
        static func faxUses(_ pages: Int) -> String { "This fax uses \(self.pages(pages))." }

        static func notEnoughPages(needed: Int, left: Int) -> String {
            "This fax needs \(pages(needed)), and you have \(pages(left)) left this period."
        }
        static func notEnoughPagesResets(needed: Int, left: Int, date: String) -> String {
            "This fax needs \(pages(needed)), and you have \(pages(left)) left until \(date)."
        }
        static let switchForMorePages = "Switch to a bigger plan to send it now:"
        static let noBiggerPlan = "Remove some pages, or send it once your pages reset."

        static let send = "Send"
        static func subscribeAndSend(price: String, period: String) -> String {
            "Subscribe \(price)/\(period) and send"
        }
        static func switchAndSend(_ plan: FaxPricing.SendPlan) -> String {
            "Switch to \(name(plan)) and send"
        }

        static let pendingMessage = "Your purchase is waiting for approval. You can send as soon as it's approved."
        static let purchaseFailedTitle = "Couldn't complete purchase"
    }
}
