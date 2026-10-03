import XCTest
@testable import ClearMaxx

/// The app should open in the device's language, and only an explicit pick in
/// Profile → Language may pin it. Saving the auto-detected language used to lock
/// a user into whatever their phone was set to on first launch.
final class LanguageSelectionTests: XCTestCase {

    private let suiteName = "LanguageSelectionTests"
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    private func launch(device: [String]) -> CMLocale {
        CMLocale(defaults: defaults, preferredLanguages: device)
    }

    func test_freshInstall_opensInTheDeviceLanguage() {
        XCTAssertEqual(launch(device: ["en-US"]).language, "en")
        XCTAssertEqual(launch(device: ["ar-SA"]).language, "ar")
        XCTAssertEqual(launch(device: ["pt-BR"]).language, "pt")
    }

    func test_unsupportedDeviceLanguage_fallsBackToEnglish() {
        XCTAssertEqual(launch(device: ["sw-KE"]).language, "en")
    }

    func test_autoDetectedLanguage_isNotPinned() {
        XCTAssertEqual(launch(device: ["ar-SA"]).language, "ar")
        XCTAssertEqual(launch(device: ["en-US"]).language, "en")
    }

    /// Older builds wrote the auto-detected language to `cm_language`, so a
    /// value there can't be told apart from a real choice and must not win.
    func test_languageSavedByOlderBuild_isIgnored() {
        defaults.set("ar", forKey: "cm_language")
        XCTAssertEqual(launch(device: ["en-US"]).language, "en")
    }

    func test_explicitChoice_survivesRelaunch() {
        launch(device: ["en-US"]).setLanguage("fr")
        XCTAssertEqual(launch(device: ["en-US"]).language, "fr")
    }

    func test_choosingTheDeviceLanguage_goesBackToFollowingTheDevice() {
        let locale = launch(device: ["en-US"])
        locale.setLanguage("fr")
        locale.setLanguage("en")
        XCTAssertEqual(launch(device: ["de-DE"]).language, "de")
    }
}
