import XCTest
@testable import ClearMaxx

final class SeverityRankTests: XCTestCase {
    func test_knownSeverities_rankInOrder() {
        XCTAssertEqual(SeverityRank.rank("Good"), 0)
        XCTAssertEqual(SeverityRank.rank("Mild"), 1)
        XCTAssertEqual(SeverityRank.rank("Moderate"), 2)
        XCTAssertEqual(SeverityRank.rank("Severe"), 3)
    }

    func test_unknownSeverity_defaultsToMildRank() {
        XCTAssertEqual(SeverityRank.rank("Unknown"), 1)
    }
}
