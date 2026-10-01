import XCTest
@testable import ClearMaxx

/// What the paywall does once a purchase call returns. RevenueCat reports a
/// closed purchase sheet as an ordinary return with `userCancelled == true`,
/// not as a thrown error, so a cancel and a genuinely unconfirmed purchase both
/// arrive looking "not entitled". Telling them apart is what keeps a user who
/// simply closed the sheet from being told their purchase failed.
final class PurchaseOutcomeTests: XCTestCase {

    func test_activeEntitlement_unlocks() {
        XCTAssertEqual(PurchaseService.outcome(entitled: true, userCancelled: false), .entitled)
    }

    func test_closingTheSheet_isACancel_notAFailure() {
        XCTAssertEqual(PurchaseService.outcome(entitled: false, userCancelled: true), .cancelled)
    }

    func test_completedPurchaseWithNoEntitlement_isUnconfirmed() {
        XCTAssertEqual(PurchaseService.outcome(entitled: false, userCancelled: false), .notConfirmed)
    }

    /// Someone who already has access is let in, whatever StoreKit says about
    /// this particular sheet — a subscriber must never be held at the gate.
    func test_activeEntitlement_unlocksEvenWhenTheSheetWasCancelled() {
        XCTAssertEqual(PurchaseService.outcome(entitled: true, userCancelled: true), .entitled)
    }
}
