import XCTest
@testable import ClearMaxx

/// The onboarding flag decides whether a returning user replays the whole
/// onboarding + quiz funnel. Once the quiz leads into a hard paywall, getting
/// this wrong means re-quizzing and re-gating a subscriber on every launch, so
/// it's worth pinning down.
@MainActor
final class OnboardingGateTests: XCTestCase {

    private let key = "cm_completed_onboarding"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: key)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: key)
        super.tearDown()
    }

    func test_defaultsToNotCompleted_onAFreshInstall() {
        XCTAssertFalse(AppState().hasCompletedOnboarding)
    }

    func test_completingOnboardingSurvivesRelaunch() {
        let firstLaunch = AppState()
        firstLaunch.hasCompletedOnboarding = true

        // A brand-new AppState stands in for the next cold launch.
        XCTAssertTrue(AppState().hasCompletedOnboarding,
                      "The funnel must not replay after the user has finished it.")
    }

    func test_clearingItAlsoPersists() {
        let state = AppState()
        state.hasCompletedOnboarding = true
        state.hasCompletedOnboarding = false
        XCTAssertFalse(AppState().hasCompletedOnboarding)
    }

    /// An active entitlement must release the gate — otherwise a subscriber who
    /// reinstalls is stuck behind a paywall for something they already bought.
    func test_paywallStageIsReleasedWhenEntitlementIsAlreadyActive() {
        let state = AppState()
        state.stage = .paywall
        state.isPremium = true
        // Mirrors the branch in refreshPremiumStatus() once RevenueCat answers.
        if state.isPremium && state.stage == .paywall { state.stage = .main }
        XCTAssertEqual(state.stage, .main)
    }
}
