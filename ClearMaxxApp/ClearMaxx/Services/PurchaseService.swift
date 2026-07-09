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
    static let entitlementID = "premium"
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

    @discardableResult
    func purchase(_ package: Package) async throws -> Bool {
        let result = try await Purchases.shared.purchase(package: package)
        return Self.isEntitled(result.customerInfo)
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

    private static func isEntitled(_ customerInfo: CustomerInfo) -> Bool {
        customerInfo.entitlements[CMPurchaseConfig.entitlementID]?.isActive == true
    }
}
