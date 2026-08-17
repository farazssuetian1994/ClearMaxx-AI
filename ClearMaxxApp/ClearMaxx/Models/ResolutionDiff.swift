//
//  ResolutionDiff.swift
//  ClearMaxx — persisted per-metric snapshot + severity ranking used for trend comparisons.
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
