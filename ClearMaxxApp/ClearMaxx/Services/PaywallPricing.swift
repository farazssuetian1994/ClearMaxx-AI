//
//  PaywallPricing.swift
//  ClearMaxx — the arithmetic and duration copy behind the paywall's derived figures.
//
//  Kept out of the view so it can be tested without StoreKit or a simulator.
//  Everything the paywall claims about money — the saving, the per-week
//  equivalent, the length of the free trial — is computed here from live store
//  values. The screen previously shipped a hardcoded "SAVE 87%" against products
//  that actually save 73%, and a hardcoded "3 days" trial against a yearly
//  product that grants a week; both are guideline 3.1.2 problems as well as
//  simply being untrue.
//

import Foundation
import RevenueCat

enum PaywallPricing {

    /// The saving a plan represents against buying the same span of time a week
    /// at a time, as a whole percentage.
    ///
    /// Returns nil when the plan isn't actually cheaper, so re-pricing a product
    /// in App Store Connect can never leave a "SAVE" badge on a plan that no
    /// longer saves anything.
    static func savingsPercent(planPricePerWeek: Double?, weeklyBaseline: Double?) -> Int? {
        guard let planPricePerWeek, let weeklyBaseline,
              weeklyBaseline > 0, planPricePerWeek < weeklyBaseline else { return nil }
        let percent = Int((((weeklyBaseline - planPricePerWeek) / weeklyBaseline) * 100).rounded())
        return percent > 0 ? percent : nil
    }

    /// "3 days", "1 week" — pluralised by Foundation in the given locale.
    ///
    /// A `"{0} days"` catalog string can't do this: Russian needs three plural
    /// forms and Arabic six, so a single placeholder string would be wrong in
    /// both for most values.
    static func localizedDuration(value: Int,
                                  unit: SubscriptionPeriod.Unit,
                                  locale: Locale) -> String? {
        var components = DateComponents()
        let allowed: NSCalendar.Unit
        switch unit {
        case .day:   components.day = value;         allowed = .day
        case .week:  components.weekOfMonth = value; allowed = .weekOfMonth
        case .month: components.month = value;       allowed = .month
        case .year:  components.year = value;        allowed = .year
        @unknown default: return nil
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        let formatter = DateComponentsFormatter()
        formatter.calendar = calendar
        formatter.unitsStyle = .full
        formatter.allowedUnits = allowed
        formatter.maximumUnitCount = 1
        return formatter.string(from: components)
    }

    /// The store's own free-trial terms for a product, or nil when it has no
    /// introductory offer. Each product carries its own trial length — never
    /// assume one plan's terms apply to another.
    static func freeTrialDuration(for product: StoreProduct, locale: Locale) -> String? {
        guard let intro = product.introductoryDiscount,
              intro.paymentMode == .freeTrial else { return nil }
        return localizedDuration(value: intro.subscriptionPeriod.value,
                                 unit: intro.subscriptionPeriod.unit,
                                 locale: locale)
    }
}
