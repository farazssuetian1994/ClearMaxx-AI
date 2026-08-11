//
//  ProgressTrend.swift
//  ClearMaxx — pure logic: turns raw scan history into direction-aware trends
//  for the progress-analysis feature. No I/O, no networking; fully unit-testable.
//

import Foundation

enum TrendDirection: String, Equatable {
    case better, worse, flat
}

struct MetricTrend: Equatable {
    let name: String
    let firstValue: Int
    let latestValue: Int
    let direction: TrendDirection
}

struct ScanSnapshot: Equatable {
    let date: Date
    let clearScore: Int
}

struct ProgressTrend: Equatable {
    let spanDays: Int
    let scanCount: Int
    let overallFirstScore: Int
    let overallLatestScore: Int
    let overallDirection: TrendDirection
    let metricTrends: [MetricTrend]
    let sampledHistory: [ScanSnapshot]
}

enum ProgressEligibility: Equatable {
    case eligible(ProgressTrend)
    case notEnoughScans
    case tooRecentSpan(daysRemaining: Int)
}

enum ProgressTrendCalculator {
    /// Overall ClearScore changes within this many points either way are noise, not progress.
    static let flatThreshold = 3
    /// Minimum days between first and latest scan before a progress read is meaningful.
    static let minSpanDays = 7
    /// Upper bound on history points sent to the backend, regardless of total scan count.
    static let maxSampledPoints = 8

    static func eligibility(for scans: [ScanRecord]) -> ProgressEligibility {
        guard scans.count >= 2 else { return .notEnoughScans }
        let sorted = scans.sorted { $0.date < $1.date }
        guard let first = sorted.first, let latest = sorted.last else { return .notEnoughScans }
        let spanDays = Calendar.current.dateComponents([.day], from: first.date, to: latest.date).day ?? 0
        guard spanDays >= minSpanDays else {
            return .tooRecentSpan(daysRemaining: minSpanDays - spanDays)
        }
        return .eligible(compute(sorted: sorted, first: first, latest: latest, spanDays: spanDays))
    }

    private static func compute(sorted: [ScanRecord], first: ScanRecord, latest: ScanRecord,
                                 spanDays: Int) -> ProgressTrend {
        let overallDelta = latest.clearScore - first.clearScore
        let overallDirection: TrendDirection =
            abs(overallDelta) <= flatThreshold ? .flat : (overallDelta > 0 ? .better : .worse)

        let firstByName = Dictionary(uniqueKeysWithValues: first.metrics.map { ($0.name, $0) })
        let metricTrends: [MetricTrend] = latest.metrics.compactMap { latestMetric in
            guard let firstMetric = firstByName[latestMetric.name] else { return nil }
            let firstRank = SeverityRank.rank(firstMetric.severity)
            let latestRank = SeverityRank.rank(latestMetric.severity)
            let direction: TrendDirection =
                latestRank == firstRank ? .flat : (latestRank < firstRank ? .better : .worse)
            return MetricTrend(name: latestMetric.name, firstValue: firstMetric.value,
                               latestValue: latestMetric.value, direction: direction)
        }

        return ProgressTrend(spanDays: spanDays, scanCount: sorted.count,
                             overallFirstScore: first.clearScore, overallLatestScore: latest.clearScore,
                             overallDirection: overallDirection, metricTrends: metricTrends,
                             sampledHistory: sample(sorted, maxPoints: maxSampledPoints))
    }

    /// Always includes the first and last scan; intermediate points are chosen at
    /// even index intervals so payload size stays flat regardless of total scan count.
    static func sample(_ sorted: [ScanRecord], maxPoints: Int) -> [ScanSnapshot] {
        guard sorted.count > maxPoints else {
            return sorted.map { ScanSnapshot(date: $0.date, clearScore: $0.clearScore) }
        }
        var indices: Set<Int> = [0, sorted.count - 1]
        let step = Double(sorted.count - 1) / Double(maxPoints - 1)
        for i in 0..<maxPoints {
            indices.insert(Int((Double(i) * step).rounded()))
        }
        return indices.sorted().map { sorted[$0] }.map {
            ScanSnapshot(date: $0.date, clearScore: $0.clearScore)
        }
    }
}
