import XCTest
@testable import ClearMaxx

final class ProgressTrendCalculatorTests: XCTestCase {
    private func scan(daysAgo: Int, score: Int, metrics: [PersistedMetric] = []) -> ScanRecord {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        return ScanRecord(date: date, clearScore: score, confidence: 90, skinType: "Normal",
                          summary: "", metrics: metrics, photoFileName: "test.jpg")
    }

    func test_fewerThanTwoScans_isNotEnough() {
        XCTAssertEqual(ProgressTrendCalculator.eligibility(for: []), .notEnoughScans)
        XCTAssertEqual(ProgressTrendCalculator.eligibility(for: [scan(daysAgo: 0, score: 50)]), .notEnoughScans)
    }

    func test_spanUnderSevenDays_isTooRecent() {
        let scans = [scan(daysAgo: 3, score: 50), scan(daysAgo: 0, score: 55)]
        XCTAssertEqual(ProgressTrendCalculator.eligibility(for: scans), .tooRecentSpan(daysRemaining: 4))
    }

    func test_spanOfExactlySevenDays_isEligible() {
        let scans = [scan(daysAgo: 7, score: 50), scan(daysAgo: 0, score: 55)]
        guard case .eligible(let trend) = ProgressTrendCalculator.eligibility(for: scans) else {
            return XCTFail("expected eligible")
        }
        XCTAssertEqual(trend.spanDays, 7)
    }

    func test_overallDirection_withinFlatThreshold_isFlat() {
        let scans = [scan(daysAgo: 10, score: 50), scan(daysAgo: 0, score: 52)]
        guard case .eligible(let trend) = ProgressTrendCalculator.eligibility(for: scans) else {
            return XCTFail("expected eligible")
        }
        XCTAssertEqual(trend.overallDirection, .flat)
        XCTAssertEqual(trend.overallFirstScore, 50)
        XCTAssertEqual(trend.overallLatestScore, 52)
    }

    func test_overallDirection_beyondFlatThreshold_isBetterOrWorse() {
        let improving = [scan(daysAgo: 10, score: 50), scan(daysAgo: 0, score: 54)]
        guard case .eligible(let up) = ProgressTrendCalculator.eligibility(for: improving) else {
            return XCTFail("expected eligible")
        }
        XCTAssertEqual(up.overallDirection, .better)

        let worsening = [scan(daysAgo: 10, score: 50), scan(daysAgo: 0, score: 46)]
        guard case .eligible(let down) = ProgressTrendCalculator.eligibility(for: worsening) else {
            return XCTFail("expected eligible")
        }
        XCTAssertEqual(down.overallDirection, .worse)
    }

    func test_metricTrend_lowerSeverityIsBetter_regardlessOfRawValueDirection() {
        // Hydration: higher raw value is healthier, but severity is what we trust.
        let first = [scan(daysAgo: 10, score: 50, metrics: [
            PersistedMetric(name: "Hydration", value: 40, severity: "Moderate"),
        ])]
        let latest = [scan(daysAgo: 0, score: 55, metrics: [
            PersistedMetric(name: "Hydration", value: 60, severity: "Good"),
        ])]
        guard case .eligible(let trend) = ProgressTrendCalculator.eligibility(for: first + latest) else {
            return XCTFail("expected eligible")
        }
        XCTAssertEqual(trend.metricTrends, [
            MetricTrend(name: "Hydration", firstValue: 40, latestValue: 60, direction: .better),
        ])
    }

    func test_metricTrend_sameSeverity_isFlat() {
        let first = [scan(daysAgo: 10, score: 50, metrics: [
            PersistedMetric(name: "Acne", value: 38, severity: "Mild"),
        ])]
        let latest = [scan(daysAgo: 0, score: 51, metrics: [
            PersistedMetric(name: "Acne", value: 35, severity: "Mild"),
        ])]
        guard case .eligible(let trend) = ProgressTrendCalculator.eligibility(for: first + latest) else {
            return XCTFail("expected eligible")
        }
        XCTAssertEqual(trend.metricTrends.first?.direction, .flat)
    }

    func test_metricMissingFromFirstScan_isSkipped() {
        let first = [scan(daysAgo: 10, score: 50, metrics: [])]
        let latest = [scan(daysAgo: 0, score: 55, metrics: [
            PersistedMetric(name: "NewMetric", value: 20, severity: "Good"),
        ])]
        guard case .eligible(let trend) = ProgressTrendCalculator.eligibility(for: first + latest) else {
            return XCTFail("expected eligible")
        }
        XCTAssertEqual(trend.metricTrends, [])
    }

    func test_sampling_underCap_returnsEveryScan() {
        let scans = (0..<5).map { scan(daysAgo: 10 - $0 * 2, score: 50 + $0) }
        guard case .eligible(let trend) = ProgressTrendCalculator.eligibility(for: scans) else {
            return XCTFail("expected eligible")
        }
        XCTAssertEqual(trend.sampledHistory.count, 5)
    }

    func test_sampling_overCap_includesFirstAndLastAndCapsCount() {
        let scans = (0..<40).map { scan(daysAgo: 100 - $0 * 2, score: 50 + $0) }
        guard case .eligible(let trend) = ProgressTrendCalculator.eligibility(for: scans) else {
            return XCTFail("expected eligible")
        }
        XCTAssertLessThanOrEqual(trend.sampledHistory.count, ProgressTrendCalculator.maxSampledPoints)
        XCTAssertEqual(trend.sampledHistory.first?.clearScore, 50)
        XCTAssertEqual(trend.sampledHistory.last?.clearScore, 89)
    }

    func test_scanCount_reflectsAllScansNotJustSampled() {
        let scans = (0..<40).map { scan(daysAgo: 100 - $0 * 2, score: 50 + $0) }
        guard case .eligible(let trend) = ProgressTrendCalculator.eligibility(for: scans) else {
            return XCTFail("expected eligible")
        }
        XCTAssertEqual(trend.scanCount, 40)
    }

    func test_overallDirection_atExactFlatThreshold_isFlat() {
        let scans = [scan(daysAgo: 10, score: 50), scan(daysAgo: 0, score: 53)]  // delta exactly 3
        guard case .eligible(let trend) = ProgressTrendCalculator.eligibility(for: scans) else {
            return XCTFail("expected eligible")
        }
        XCTAssertEqual(trend.overallDirection, .flat)
    }

    func test_eligibility_atSixDaysRemaining_isTooRecent() {
        let scans = [scan(daysAgo: 1, score: 50), scan(daysAgo: 0, score: 55)]  // 1-day span, 6 days remaining
        XCTAssertEqual(ProgressTrendCalculator.eligibility(for: scans), .tooRecentSpan(daysRemaining: 6))
    }
}
