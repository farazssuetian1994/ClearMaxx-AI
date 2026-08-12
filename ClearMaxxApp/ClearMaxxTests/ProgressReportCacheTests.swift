import XCTest
import SwiftData
@testable import ClearMaxx

final class ProgressReportCacheTests: XCTestCase {
    func test_cache_roundTripsReportIncludingRoutineSteps() throws {
        let container = try ModelContainer(for: ScanRecord.self, ProgressReportCache.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)

        let scan = ScanRecord(date: Date(), clearScore: 70, confidence: 90, skinType: "Normal",
                              summary: "", metrics: [], photoFileName: "a.jpg")
        context.insert(scan)

        let report = ProgressReport(
            verdict: "improving", headline: "Great progress", narrative: "Your skin is clearer.",
            working: ["Acne"], stalled: ["Dark Spots"], watch: [],
            updatedRoutine: [APIRoutineStep(time: "AM", category: "Cleanser", title: "Foam Wash",
                                            detail: "Gentle daily cleanse.", tags: ["Fragrance-free"])])

        let cache = ProgressReportCache(latestScanDate: scan.date, report: report)
        context.insert(cache)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<ProgressReportCache>()).first
        XCTAssertEqual(fetched?.latestScanDate, scan.date)
        XCTAssertEqual(fetched?.report.verdict, "improving")
        XCTAssertEqual(fetched?.report.working, ["Acne"])
        XCTAssertEqual(fetched?.report.updatedRoutine.first?.title, "Foam Wash")
        XCTAssertEqual(fetched?.report.updatedRoutine.first?.tags, ["Fragrance-free"])
    }
}
