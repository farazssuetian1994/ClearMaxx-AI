//
//  ProgressReport.swift
//  ClearMaxx — AI progress-analysis result + its on-device cache.
//

import Foundation
import SwiftData

struct ProgressReport: Codable {
    let verdict: String          // "improving" | "steady" | "worsening"
    let headline: String
    let narrative: String
    let working: [String]
    let stalled: [String]
    let watch: [String]
    let updatedRoutine: [APIRoutineStep]
}

/// Caches the most recent `ProgressReport` so re-opening it with no new scan
/// since costs zero API calls. Keyed to the latest `ScanRecord`'s `date` —
/// a new scan simply won't match this key, which is how the cache
/// "invalidates" itself with no TTL bookkeeping.
///
/// Keyed to `Date`, not `PersistentIdentifier`: SwiftData on iOS 17 cannot
/// persist `PersistentIdentifier` as a stored `@Model` property (it wraps an
/// `NSManagedObjectID` that SwiftData's schema generator rejects at runtime
/// with a fatal error). `Date` is a plain, already-storable field.
@Model
final class ProgressReportCache {
    var latestScanDate: Date
    var verdict: String
    var headline: String
    var narrative: String
    var working: [String]
    var stalled: [String]
    var watch: [String]
    var updatedRoutineData: Data

    init(latestScanDate: Date, report: ProgressReport) {
        self.latestScanDate = latestScanDate
        self.verdict = report.verdict
        self.headline = report.headline
        self.narrative = report.narrative
        self.working = report.working
        self.stalled = report.stalled
        self.watch = report.watch
        self.updatedRoutineData = (try? JSONEncoder().encode(report.updatedRoutine)) ?? Data()
    }

    var report: ProgressReport {
        let routine = (try? JSONDecoder().decode([APIRoutineStep].self, from: updatedRoutineData)) ?? []
        return ProgressReport(verdict: verdict, headline: headline, narrative: narrative,
                              working: working, stalled: stalled, watch: watch, updatedRoutine: routine)
    }
}
