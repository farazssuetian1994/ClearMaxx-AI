import XCTest
import RevenueCat
@testable import ClearMaxx

/// The paywall states prices, savings and trial lengths to the user at the
/// moment of purchase. Getting any of them wrong is both a false claim and an
/// App Store guideline 3.1.2 rejection, so the derivations are pinned here.
///
/// The figures below are ClearMaxx's real App Store Connect products:
/// weekly $4.99, monthly $14.99, yearly $69.99.
final class PaywallPricingTests: XCTestCase {

    // RevenueCat's own per-week normalisation of each product's price.
    private let weeklyPerWeek = 4.99
    private let yearlyPerWeek = 69.99 / 52.0      // ≈ 1.346
    private let monthlyPerWeek = 14.99 * 12 / 52.0 // ≈ 3.459

    // MARK: Savings

    func test_yearlySavesSeventyThreePercent_notTheHardcodedEightySeven() {
        XCTAssertEqual(
            PaywallPricing.savingsPercent(planPricePerWeek: yearlyPerWeek,
                                          weeklyBaseline: weeklyPerWeek),
            73,
            "$69.99/yr against $4.99/wk is a 73% saving. The screen used to claim 87%.")
    }

    func test_monthlySavingIsDerivedToo() {
        XCTAssertEqual(
            PaywallPricing.savingsPercent(planPricePerWeek: monthlyPerWeek,
                                          weeklyBaseline: weeklyPerWeek),
            31)
    }

    func test_noBadgeWhenThePlanIsNotActuallyCheaper() {
        // If yearly were ever re-priced above the weekly run-rate, the badge
        // must disappear rather than advertise a saving that isn't there.
        XCTAssertNil(PaywallPricing.savingsPercent(planPricePerWeek: 6.00,
                                                   weeklyBaseline: weeklyPerWeek))
        XCTAssertNil(PaywallPricing.savingsPercent(planPricePerWeek: weeklyPerWeek,
                                                   weeklyBaseline: weeklyPerWeek))
    }

    func test_noBadgeWithoutAWeeklyPlanToCompareAgainst() {
        XCTAssertNil(PaywallPricing.savingsPercent(planPricePerWeek: yearlyPerWeek,
                                                   weeklyBaseline: nil))
        XCTAssertNil(PaywallPricing.savingsPercent(planPricePerWeek: nil,
                                                   weeklyBaseline: weeklyPerWeek))
    }

    func test_aZeroBaselineCannotDivideByZero() {
        XCTAssertNil(PaywallPricing.savingsPercent(planPricePerWeek: 1.0, weeklyBaseline: 0))
    }

    // MARK: Trial duration

    func test_trialDurationsMatchTheProductsInAppStoreConnect() {
        let en = Locale(identifier: "en")
        // The weekly and monthly products grant 3 days; the yearly grants 1 week.
        XCTAssertEqual(PaywallPricing.localizedDuration(value: 3, unit: .day, locale: en), "3 days")
        XCTAssertEqual(PaywallPricing.localizedDuration(value: 1, unit: .week, locale: en), "1 week")
    }

    func test_durationIsPluralisedNotConcatenated() {
        let en = Locale(identifier: "en")
        XCTAssertEqual(PaywallPricing.localizedDuration(value: 1, unit: .day, locale: en), "1 day")
        XCTAssertEqual(PaywallPricing.localizedDuration(value: 2, unit: .month, locale: en), "2 months")
    }

    /// Every language ClearMaxx ships must render a trial length. A nil here
    /// silently downgrades the CTA from "Start Free Trial" to "Continue" and
    /// drops the trial line for users in that language.
    func test_everyShippedLanguageProducesATrialString() {
        for code in CMLanguages.codes {
            let locale = Locale(identifier: code)
            for (value, unit) in [(3, SubscriptionPeriod.Unit.day), (1, .week)] {
                let text = PaywallPricing.localizedDuration(value: value, unit: unit, locale: locale)
                XCTAssertNotNil(text, "No trial duration for \(code)")
                XCTAssertFalse(text?.isEmpty ?? true, "Empty trial duration for \(code)")
            }
        }
    }

    func test_durationActuallyFollowsTheLocale() {
        let en = PaywallPricing.localizedDuration(value: 3, unit: .day, locale: Locale(identifier: "en"))
        let de = PaywallPricing.localizedDuration(value: 3, unit: .day, locale: Locale(identifier: "de"))
        XCTAssertNotEqual(en, de, "The app's language override must drive the trial copy, not the device locale.")
    }
}

/// The catalogs are the other half of the paywall's copy: a key missing from a
/// translation falls back to English mid-sentence.
final class PaywallLocalizationTests: XCTestCase {

    private let paywallKeys = [
        "premium.monthly", "premium.perWeek", "premium.perMonth", "premium.perYear",
        "premium.saveBadge", "premium.perWeekCompare", "premium.freeTrialThen",
        "premium.thenPrice", "premium.autoRenew", "premium.continue",
        "premium.selectPlan", "premium.loadingPlans", "premium.includedTitle",
        "premium.weekly", "premium.yearly", "premium.startTrial", "premium.restore",
    ]

    func test_everyLanguageHasEveryPaywallKey() throws {
        for code in CMLanguages.codes {
            let url = try XCTUnwrap(
                Bundle(for: type(of: self)).url(forResource: code, withExtension: "json")
                    ?? Bundle.main.url(forResource: code, withExtension: "json"),
                "Missing catalog for \(code)")
            let data = try Data(contentsOf: url)
            let catalog = try JSONDecoder().decode([String: String].self, from: data)
            for key in paywallKeys {
                let value = catalog[key]
                XCTAssertNotNil(value, "\(code).json is missing \(key)")
                XCTAssertFalse(value?.isEmpty ?? true, "\(code).json has an empty \(key)")
            }
        }
    }

    /// The placeholders are what carry the live prices in. A translation that
    /// drops one renders a sentence with the number missing.
    func test_placeholdersSurviveTranslation() throws {
        let expected = ["premium.saveBadge": ["{0}"],
                        "premium.perWeekCompare": ["{0}", "{1}"],
                        "premium.freeTrialThen": ["{0}", "{1}"],
                        "premium.thenPrice": ["{0}"]]
        for code in CMLanguages.codes {
            let url = try XCTUnwrap(
                Bundle(for: type(of: self)).url(forResource: code, withExtension: "json")
                    ?? Bundle.main.url(forResource: code, withExtension: "json"))
            let catalog = try JSONDecoder().decode([String: String].self, from: try Data(contentsOf: url))
            for (key, tokens) in expected {
                let value = try XCTUnwrap(catalog[key], "\(code).json missing \(key)")
                for token in tokens {
                    XCTAssertTrue(value.contains(token), "\(code).json \(key) lost \(token): \(value)")
                }
            }
        }
    }

    /// The claims that were hardcoded and wrong. If either reappears, the
    /// screen has gone back to asserting figures it didn't get from the store.
    func test_theHardcodedPriceClaimsAreGone() throws {
        for code in CMLanguages.codes {
            let url = try XCTUnwrap(
                Bundle(for: type(of: self)).url(forResource: code, withExtension: "json")
                    ?? Bundle.main.url(forResource: code, withExtension: "json"))
            let catalog = try JSONDecoder().decode([String: String].self, from: try Data(contentsOf: url))
            XCTAssertNil(catalog["premium.save87"], "\(code).json still carries the hardcoded 87% claim")
            XCTAssertNil(catalog["premium.trialLine"], "\(code).json still carries the hardcoded trial line")
        }
    }
}
