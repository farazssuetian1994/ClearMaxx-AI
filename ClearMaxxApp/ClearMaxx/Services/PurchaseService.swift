//
//  PurchaseService.swift
//  ClearMaxx — RevenueCat wrapper: configure, fetch offerings, purchase, restore, entitlement check.
//

import Foundation
import RevenueCat

enum CMPurchaseConfig {
    /// Public RevenueCat SDK key for the "ClearMaxx AI" app — safe to embed client-side.
    static let apiKey = "appl_lotZIQfXqxuXsyzTbxxadEvhnIT"

    /// Must match the entitlement identifier created in the RevenueCat dashboard.
    /// This is "ClearMaxx A Pro", not "premium" — confirmed directly against the
    /// RevenueCat dashboard after a real sandbox purchase left App Review stuck
    /// on the paywall post-purchase (Guideline 2.1(b), Sep 30 2026 rejection).
    /// The three products were correctly attached to the entitlement the whole
    /// time; only this identifier string was wrong, so every purchase/restore
    /// check against "premium" silently found nothing.
    static let entitlementID = "ClearMaxx A Pro"
}

final class PurchaseService {
    static let shared = PurchaseService()
    private init() {}

    func configure() {
        Purchases.logLevel = .info
        Purchases.configure(withAPIKey: CMPurchaseConfig.apiKey)
    }

    func fetchOfferings() async throws -> Offering? {
        try await Purchases.shared.offerings().current
    }

    enum PurchaseOutcome: Equatable {
        case entitled
        /// The user closed the purchase sheet. Their choice, not a failure.
        case cancelled
        /// The transaction went through but the entitlement still isn't active.
        case notConfirmed
    }

    func purchase(_ package: Package) async throws -> PurchaseOutcome {
        // RevenueCat does not throw when the user closes the sheet: it returns
        // normally with `userCancelled == true`. Read as a plain "not entitled",
        // a cancel used to be reported to the user as a failed purchase.
        let result = try await Purchases.shared.purchase(package: package)
        var entitled = Self.isEntitled(result.customerInfo)
        if !entitled && !result.userCancelled {
            entitled = await forceRefreshEntitlement()
        }
        return Self.outcome(entitled: entitled, userCancelled: result.userCancelled)
    }

    /// An active entitlement always wins — someone who already has access is
    /// let in whatever StoreKit says about this particular sheet.
    static func outcome(entitled: Bool, userCancelled: Bool) -> PurchaseOutcome {
        if entitled { return .entitled }
        return userCancelled ? .cancelled : .notConfirmed
    }

    @discardableResult
    func restorePurchases() async throws -> Bool {
        let customerInfo = try await Purchases.shared.restorePurchases()
        return Self.isEntitled(customerInfo)
    }

    func refreshEntitlement() async -> Bool {
        guard let customerInfo = try? await Purchases.shared.customerInfo() else { return false }
        return Self.isEntitled(customerInfo)
    }

    /// Forces a fresh fetch from RevenueCat's servers rather than trusting the
    /// local cache. `purchase(_:)` already returns the `customerInfo` attached
    /// to the transaction, so this is only for the rare case where that first
    /// read doesn't yet show the entitlement as active — e.g. App Review's
    /// sandbox environment occasionally has a brief lag between a completed
    /// purchase and RevenueCat's cache reflecting it. Without this retry, a
    /// user whose purchase genuinely succeeded could be left stuck on the
    /// paywall with no path forward.
    private func forceRefreshEntitlement() async -> Bool {
        guard let customerInfo = try? await Purchases.shared.customerInfo(fetchPolicy: .fetchCurrent) else {
            return false
        }
        return Self.isEntitled(customerInfo)
    }

    private static func isEntitled(_ customerInfo: CustomerInfo) -> Bool {
        customerInfo.entitlements[CMPurchaseConfig.entitlementID]?.isActive == true
    }
}
