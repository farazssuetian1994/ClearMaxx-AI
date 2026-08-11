//
//  ResolutionDiff.swift
//  ClearMaxx — pure logic for detecting a metric that just resolved (improved into "Good").
//

import Foundation

struct PersistedMetric: Codable, Hashable {
    let name: String
    let value: Int
    let severity: String   // "Good" / "Mild" / "Moderate" / "Severe" — reused verbatim from the backend
}

/// Severity is already direction-aware — the backend always encodes "Good" as
/// healthy regardless of whether the metric's raw value is higher- or
/// lower-is-better — so trend direction for any metric is derived from this
/// rank, never from comparing raw values directly.
enum SeverityRank {
    private static let table = ["Good": 0, "Mild": 1, "Moderate": 2, "Severe": 3]
    static func rank(_ severity: String) -> Int { table[severity] ?? 1 }
}

enum ResolutionDiff {
    /// Metrics whose severity is "Good" now but was not "Good" on the immediately
    /// preceding scan. Returns [] when there is no previous scan — the first-ever
    /// scan only establishes a baseline, it never triggers a celebration.
    static func newlyResolved(current: [PersistedMetric], previous: [PersistedMetric]?) -> [PersistedMetric] {
        guard let previous else { return [] }
        let previousByName = Dictionary(uniqueKeysWithValues: previous.map { ($0.name, $0) })
        return current.filter { metric in
            metric.severity == "Good" && previousByName[metric.name]?.severity != "Good"
        }
    }
}
