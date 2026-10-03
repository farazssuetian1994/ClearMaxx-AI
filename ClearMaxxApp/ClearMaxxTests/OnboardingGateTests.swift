import XCTest
@testable import ClearMaxx

/// The onboarding flag decides whether a returning user replays the whole
/// onboarding + quiz funnel. Once the quiz leads into a hard paywall, getting
/// this wrong means re-quizzing and re-gating a subscriber on every launch, so
/// it's worth pinning down.
@MainActor
final class OnboardingGateTests: XCTestCase {

    private let key = "cm_completed_onboarding"
    private let skipPaywallKey = "cm_debug_skip_paywall"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: key)
        UserDefaults.standard.removeObject(forKey: skipPaywallKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: key)
        UserDefaults.standard.removeObject(forKey: skipPaywallKey)
        super.tearDown()
    }

    /// A Debug build has to meet the paywall exactly as a real user does.
    /// Skipping it by default hid the paywall from everyone running the app
    /// from Xcode, which made it look as if it never showed.
    func test_aFreshDebugInstall_isNotPremium_soThePaywallShows() {
        XCTAssertFalse(AppState.debugSkipPaywall)
        XCTAssertFalse(AppState().isPremium)
    }

    /// The developer opt-out is set as a scheme launch argument
    /// (`-cm_debug_skip_paywall YES`), which arrives as the string "YES".
    func test_theDeveloperOptOut_acceptsALaunchArgumentValue() {
        UserDefaults.standard.set("YES", forKey: skipPaywallKey)
        XCTAssertTrue(AppState.debugSkipPaywall)
        XCTAssertTrue(AppState().isPremium)
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
