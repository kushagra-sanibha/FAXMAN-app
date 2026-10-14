import Foundation
import XCTest
@testable import Faxit

/// What counts against a send plan's page allowance, and whether a fax fits.
final class PlanAllowanceTests: XCTestCase {
    private let periodStart = Date(timeIntervalSince1970: 1_800_000_000)

    private func fax(pages: Int, at offset: TimeInterval, status: FaxStatus = .delivered, method: FaxPaymentMethod = .planAllowance) -> SentFax {
        SentFax(
            recipientNumber: "5551234567",
            pageCount: pages + 1,
            status: status,
            createdAt: periodStart.addingTimeInterval(offset),
            paymentMethod: method,
            planPageCount: pages,
            documentContentHash: UUID().uuidString
        )
    }

    private func allowance(_ plan: FaxPricing.SendPlan, _ faxes: [SentFax]) -> PlanAllowance {
        PlanAllowance(active: ActiveSendPlan(plan: plan, periodStart: periodStart, periodEnd: nil), faxes: faxes)
    }

    func testOnlyThisPeriodsPlanPagesCount() {
        let faxes = [
            fax(pages: 10, at: 60),                       // counts
            fax(pages: 4, at: 3_600, status: .sending),   // in flight: counts
            fax(pages: 7, at: -60),                       // last period: doesn't
            fax(pages: 9, at: 120, method: .oneTimePass), // paid separately before plans: doesn't
        ]
        let result = allowance(.weekly, faxes)
        XCTAssertEqual(result.pagesUsed, 14)
        XCTAssertEqual(result.pagesLeft, 11)
    }

    func testFailedFaxGivesItsPagesBack() {
        let faxes = [
            fax(pages: 8, at: 60, status: .notDelivered(reason: .noAnswer)),
            fax(pages: 5, at: 90, status: .providerUnavailable),
            fax(pages: 3, at: 120),
        ]
        XCTAssertEqual(allowance(.weekly, faxes).pagesUsed, 3)
    }

    func testFaxFitsExactlyUpToTheLimitAndNotOnePageMore() {
        let used = allowance(.weekly, [fax(pages: 20, at: 60)])
        XCTAssertTrue(used.covers(pages: 5))
        XCTAssertFalse(used.covers(pages: 6))
    }

    func testPagesLeftNeverGoesNegative() {
        let over = allowance(.weekly, [fax(pages: 30, at: 60)])
        XCTAssertEqual(over.pagesLeft, 0)
        XCTAssertFalse(over.covers(pages: 1))
    }

    func testBiggerPlansAlwaysIncludeMorePages() {
        let limits = FaxPricing.SendPlan.allCases.map(\.pageLimit)
        XCTAssertEqual(limits, limits.sorted())
        XCTAssertEqual(Set(limits).count, limits.count)
    }
}
