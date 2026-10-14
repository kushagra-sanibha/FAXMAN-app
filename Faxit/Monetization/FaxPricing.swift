import Foundation

/// Single source of truth for what Faxit sells. Sending is only ever on a
/// Weekly, Monthly or Yearly send plan, each with a page allowance per
/// billing period; there is no per-fax or per-page purchase. Prices come
/// only from StoreKit.
enum FaxPricing {
    enum SendPlan: String, CaseIterable, Identifiable {
        case weekly = "com.faxit.plan.weekly"
        case monthly = "com.faxit.plan.monthly"
        case yearly = "com.faxit.plan.annual"

        var id: String { productID }
        var productID: String { rawValue }

        init?(productID: String) {
            self.init(rawValue: productID)
        }

        /// Document pages included per billing period (cover pages are free).
        /// Sized so the price per page falls with commitment: at $4.99 /
        /// $9.99 / $79.99 that's about $0.20, $0.10 and $0.067 a page.
        var pageLimit: Int {
            switch self {
            case .weekly: 25
            case .monthly: 100
            case .yearly: 1200
            }
        }
    }

    static let numberRentalProductID = "com.faxit.number.monthly"

    static var allProductIDs: [String] {
        SendPlan.allCases.map(\.productID) + [numberRentalProductID]
    }
}
