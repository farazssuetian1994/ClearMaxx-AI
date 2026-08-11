# Progress Analysis (History-Aware Skin Trend Report) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an "Analyze My Progress" feature that compares a user's first and latest scans (photos + full metric history), calls a new backend endpoint for an AI-written progress verdict, and lets the user push the AI's adapted routine into today's checklist — gated to premium users, with on-device caching so repeat views cost zero API calls.

**Architecture:** All numeric trend computation happens in Swift (`ProgressTrendCalculator`), never in the model — the backend receives precomputed, direction-labeled facts and is only asked to judge the two photos, explain the trend in plain language, and adapt the routine. A new `POST /api/skin/progress` endpoint on the existing Flask/Vertex backend shares the model-fallback plumbing with `/api/skin/analyze`. On-device, a SwiftData-cached `ProgressReportCache` keyed to the latest scan's ID means re-opening a report with no new scan makes no network call at all.

**Tech Stack:** Python/Flask backend on Vertex AI Gemini (existing runtime, additive schema change), pytest for backend tests. Swift 5 / SwiftUI / SwiftData (iOS 17+ deployment target). A new `ClearMaxxTests` XCTest target (scaffolded via the `xcodeproj` Ruby gem, already installed) since none exists in the project today.

## Global Constraints

- iOS deployment target is 17.0, Swift version 5.0 (confirmed in `ClearMaxxApp.xcodeproj/project.pbxproj`).
- Backend request JSON uses **snake_case** keys (matches the existing `/api/skin/analyze` convention, e.g. `image_base64`); backend response JSON uses **camelCase** keys (matches the existing `SkinAnalysis`/`_normalize()` convention, e.g. `clearScore`, `routineSteps`).
- All backend routes require the `X-App-Token` header, checked via the existing `_authorized(request)` helper — reuse it unchanged.
- Progress-analysis photos are downscaled to a **768px** long edge before upload (a cost control — see spec). This is distinct from the existing single-scan path's 1024px cap in `SkinAnalysisService.swift`, which this plan does not touch.
- Gemini calls get a bounded `max_output_tokens` — a cost control shared by both the existing and new endpoint once `_generate()` is generalized.
- The progress feature is gated to `AppState.isPremium` (from `PurchaseService`), unlimited taps — cost is controlled via the `ProgressReportCache`, not via a tap limit.
- Every new pure-logic Swift file gets real XCTest coverage in the new `ClearMaxxTests` target (per user decision — see Task 1). Every backend addition gets `pytest` coverage in the existing `backend/test_main.py`, following that file's established pattern of testing pure functions imported from `main` (no real Vertex calls).
- Full spec: `docs/superpowers/specs/2026-08-12-progress-analysis-design.md`.
- Explicitly out of scope (per spec's "Deferred" section): routine-adherence signals, Diary integration, scan-cadence changes, and a code-enforced check that the model's verdict is numerically consistent with the given trends.

---

### Task 1: Scaffold the `ClearMaxxTests` XCTest target

**Files:**
- Create: `ClearMaxxApp/scripts/add_test_target.rb` (temporary, deleted at the end of this task)
- Create: `ClearMaxxApp/ClearMaxxTests/ClearMaxxTests.swift`
- Create: `ClearMaxxApp/ClearMaxx.xcodeproj/xcshareddata/xcschemes/ClearMaxx.xcscheme`
- Modify: `ClearMaxxApp/ClearMaxx.xcodeproj/project.pbxproj` (via the script, not by hand)

**Interfaces:**
- Produces: a `ClearMaxxTests` unit-test target hosted by the `ClearMaxx` app target, runnable via `xcodebuild test -project ClearMaxx.xcodeproj -scheme ClearMaxx -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'`. Every later iOS task's tests live in this target.

- [ ] **Step 1: Write the one-time project-scaffolding script**

Create `ClearMaxxApp/scripts/add_test_target.rb`:

```ruby
require 'xcodeproj'

project_path = 'ClearMaxx.xcodeproj'
project = Xcodeproj::Project.open(project_path)

app_target = project.targets.find { |t| t.name == 'ClearMaxx' }
raise "ClearMaxx app target not found" unless app_target

test_target = project.new_target(:unit_test_bundle, 'ClearMaxxTests', :ios, '17.0')
test_target.add_dependency(app_target)

test_target.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.clearmaxx.app.tests'
  config.build_settings['TEST_HOST'] = '$(BUILT_PRODUCTS_DIR)/ClearMaxx.app/ClearMaxx'
  config.build_settings['BUNDLE_LOADER'] = '$(TEST_HOST)'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
end

group = project.main_group.new_group('ClearMaxxTests', 'ClearMaxxTests')
file_ref = group.new_file('ClearMaxxTests/ClearMaxxTests.swift')
test_target.add_file_references([file_ref])

project.save

scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(app_target)
scheme.add_test_target(test_target)
scheme.set_launch_target(app_target)
scheme.save_as(project_path, 'ClearMaxx', true)

puts "Done: ClearMaxxTests target + shared ClearMaxx scheme created."
```

- [ ] **Step 2: Write a trivial failing test to prove the target runs**

Create `ClearMaxxApp/ClearMaxxTests/ClearMaxxTests.swift`:

```swift
import XCTest

final class ClearMaxxTests: XCTestCase {
    func test_targetIsWired() {
        XCTAssertEqual(1 + 1, 3)  // deliberately wrong — proves this test actually runs
    }
}
```

- [ ] **Step 3: Run the scaffolding script**

Run (from `ClearMaxxApp/`):
```bash
cd ClearMaxxApp
ruby scripts/add_test_target.rb
```
Expected: `Done: ClearMaxxTests target + shared ClearMaxx scheme created.` and `project.pbxproj` is modified (verify with `git status`).

- [ ] **Step 4: Run the test and confirm it FAILS**

Run:
```bash
xcodebuild test -project ClearMaxx.xcodeproj -scheme ClearMaxx \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' 2>&1 | tail -30
```
Expected: build succeeds, then `Test Case '-[ClearMaxxTests.ClearMaxxTests test_targetIsWired]' failed` with `XCTAssertEqual failed: ("2") is not equal to ("3")`. This confirms the target is really wired into the build and the test is really executing (not silently skipped).

If the build fails with a code-signing or team error: add `config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'` and `config.build_settings['DEVELOPMENT_TEAM'] = ''` for simulator-only signing in the script's build-settings block, re-run Step 3 with a fresh `git checkout -- ClearMaxx.xcodeproj/project.pbxproj` first, then repeat Step 4.

- [ ] **Step 5: Fix the assertion so the test passes**

Edit `ClearMaxxApp/ClearMaxxTests/ClearMaxxTests.swift`:

```swift
import XCTest

final class ClearMaxxTests: XCTestCase {
    func test_targetIsWired() {
        XCTAssertEqual(1 + 1, 2)
    }
}
```

- [ ] **Step 6: Run the test and confirm it PASSES**

Run the same command as Step 4.
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 7: Delete the one-time script and commit**

```bash
cd ClearMaxxApp
rm scripts/add_test_target.rb
rmdir scripts 2>/dev/null || true
cd ..
git add ClearMaxxApp/ClearMaxx.xcodeproj ClearMaxxApp/ClearMaxxTests
git commit -m "iOS: scaffold ClearMaxxTests XCTest target and shared scheme"
```

---

### Task 2: Extract shared `SeverityRank` and add tests

**Files:**
- Modify: `ClearMaxxApp/ClearMaxx/Models/ResolutionDiff.swift`
- Modify: `ClearMaxxApp/ClearMaxx/Screens/SkinProgressView.swift:145-165`
- Create: `ClearMaxxApp/ClearMaxxTests/SeverityRankTests.swift`

**Interfaces:**
- Produces: `enum SeverityRank { static func rank(_ severity: String) -> Int }` — `"Good"` → 0, `"Mild"` → 1, `"Moderate"` → 2, `"Severe"` → 3, unknown strings → 1. Used by Task 3's `ProgressTrendCalculator` and by the existing `SkinProgressView.metricRow`.

`SkinProgressView.metricRow` already computes trend direction from a private `severityRank` table (`SkinProgressView.swift:145`) rather than raw metric values — this is the correct polarity-aware pattern the spec calls for. Hoisting it into a shared file lets the new progress-analysis logic reuse it instead of duplicating a second polarity table.

- [ ] **Step 1: Write the failing test**

Create `ClearMaxxApp/ClearMaxxTests/SeverityRankTests.swift`:

```swift
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
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `xcodebuild test -project ClearMaxx.xcodeproj -scheme ClearMaxx -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' -only-testing:ClearMaxxTests/SeverityRankTests 2>&1 | tail -30`
Expected: FAIL — `cannot find 'SeverityRank' in scope`.

- [ ] **Step 3: Add `SeverityRank` to `ResolutionDiff.swift`**

In `ClearMaxxApp/ClearMaxx/Models/ResolutionDiff.swift`, add above the `ResolutionDiff` enum (after the `PersistedMetric` struct):

```swift
/// Severity is already direction-aware — the backend always encodes "Good" as
/// healthy regardless of whether the metric's raw value is higher- or
/// lower-is-better — so trend direction for any metric is derived from this
/// rank, never from comparing raw values directly.
enum SeverityRank {
    private static let table = ["Good": 0, "Mild": 1, "Moderate": 2, "Severe": 3]
    static func rank(_ severity: String) -> Int { table[severity] ?? 1 }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Same command as Step 2. Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Update `SkinProgressView` to use the shared table**

In `ClearMaxxApp/ClearMaxx/Screens/SkinProgressView.swift`, replace lines 142-151:

```swift
    /// Severity is already direction-aware (backend always encodes "Good" as
    /// healthy regardless of whether the metric's raw value is higher- or
    /// lower-is-better), so trend comes from the severity rank, not the value.
    private static let severityRank = ["Good": 0, "Mild": 1, "Moderate": 2, "Severe": 3]

    private func metricRow(_ metric: PersistedMetric) -> some View {
        let prevMetric = previous?.metrics.first(where: { $0.name == metric.name })
        let justResolved = metric.severity == "Good" && prevMetric?.severity != "Good"
        let curRank = Self.severityRank[metric.severity] ?? 1
        let prevRank = prevMetric.map { Self.severityRank[$0.severity] ?? 1 }
```

with:

```swift
    private func metricRow(_ metric: PersistedMetric) -> some View {
        let prevMetric = previous?.metrics.first(where: { $0.name == metric.name })
        let justResolved = metric.severity == "Good" && prevMetric?.severity != "Good"
        let curRank = SeverityRank.rank(metric.severity)
        let prevRank = prevMetric.map { SeverityRank.rank($0.severity) }
```

- [ ] **Step 6: Build and confirm no regressions**

Run: `xcodebuild build -project ClearMaxx.xcodeproj -scheme ClearMaxx -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' 2>&1 | tail -20`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 7: Commit**

```bash
git add ClearMaxxApp/ClearMaxx/Models/ResolutionDiff.swift ClearMaxxApp/ClearMaxx/Screens/SkinProgressView.swift ClearMaxxApp/ClearMaxxTests/SeverityRankTests.swift
git commit -m "iOS: extract shared SeverityRank from SkinProgressView"
```

---

### Task 3: `ProgressTrendCalculator` — pure trend/eligibility logic

**Files:**
- Create: `ClearMaxxApp/ClearMaxx/Models/ProgressTrend.swift`
- Create: `ClearMaxxApp/ClearMaxxTests/ProgressTrendCalculatorTests.swift`

**Interfaces:**
- Consumes: `ScanRecord` (from `ScanHistory.swift`: `.date: Date`, `.clearScore: Int`, `.metrics: [PersistedMetric]`), `SeverityRank.rank(_:)` (Task 2).
- Produces:
  - `enum TrendDirection: String, Equatable { case better, worse, flat }`
  - `struct MetricTrend: Equatable { let name: String; let firstValue: Int; let latestValue: Int; let direction: TrendDirection }`
  - `struct ScanSnapshot: Equatable { let date: Date; let clearScore: Int }`
  - `struct ProgressTrend { let spanDays: Int; let scanCount: Int; let overallFirstScore: Int; let overallLatestScore: Int; let overallDirection: TrendDirection; let metricTrends: [MetricTrend]; let sampledHistory: [ScanSnapshot] }`
  - `enum ProgressEligibility: Equatable { case eligible(ProgressTrend); case notEnoughScans; case tooRecentSpan(daysRemaining: Int) }` (note: `ProgressTrend`/`MetricTrend`/`ScanSnapshot` need `Equatable` for this — see Step 3's full listing)
  - `enum ProgressTrendCalculator { static let flatThreshold = 3; static let minSpanDays = 7; static let maxSampledPoints = 8; static func eligibility(for scans: [ScanRecord]) -> ProgressEligibility }`
- Used by: Task 6 (`ProgressAnalysisService`), Task 9 (`SkinProgressView` wiring).

- [ ] **Step 1: Write the failing tests**

Create `ClearMaxxApp/ClearMaxxTests/ProgressTrendCalculatorTests.swift`:

```swift
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
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `xcodebuild test -project ClearMaxx.xcodeproj -scheme ClearMaxx -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' -only-testing:ClearMaxxTests/ProgressTrendCalculatorTests 2>&1 | tail -40`
Expected: FAIL — `cannot find 'ProgressTrendCalculator' in scope` (or similar, for each missing type).

- [ ] **Step 3: Implement `ProgressTrend.swift`**

Create `ClearMaxxApp/ClearMaxx/Models/ProgressTrend.swift`:

```swift
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
```

- [ ] **Step 4: Run the tests to verify they pass**

Same command as Step 2. Expected: `** TEST SUCCEEDED **` for all cases in `ProgressTrendCalculatorTests`.

- [ ] **Step 5: Commit**

```bash
git add ClearMaxxApp/ClearMaxx/Models/ProgressTrend.swift ClearMaxxApp/ClearMaxxTests/ProgressTrendCalculatorTests.swift
git commit -m "iOS: add ProgressTrendCalculator pure trend/eligibility logic"
```

---

### Task 4: `ProgressReport` model and on-device cache

**Files:**
- Create: `ClearMaxxApp/ClearMaxx/Models/ProgressReport.swift`
- Modify: `ClearMaxxApp/ClearMaxx/ClearMaxxApp.swift:25`
- Create: `ClearMaxxApp/ClearMaxxTests/ProgressReportCacheTests.swift`

**Interfaces:**
- Consumes: `APIRoutineStep` (from `SkinAnalysisService.swift`, already `Codable`).
- Produces:
  - `struct ProgressReport: Codable { let verdict: String; let headline: String; let narrative: String; let working: [String]; let stalled: [String]; let watch: [String]; let updatedRoutine: [APIRoutineStep] }`
  - `@Model final class ProgressReportCache { var latestScanID: PersistentIdentifier; ...; init(latestScanID:report:); var report: ProgressReport { get } }`
- Used by: Task 6 (decodes `ProgressReport` from the network response), Task 9 (reads/writes `ProgressReportCache` via `@Query`/`ModelContext`).

- [ ] **Step 1: Write the failing test**

Create `ClearMaxxApp/ClearMaxxTests/ProgressReportCacheTests.swift`:

```swift
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

        let cache = ProgressReportCache(latestScanID: scan.persistentModelID, report: report)
        context.insert(cache)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<ProgressReportCache>()).first
        XCTAssertEqual(fetched?.latestScanID, scan.persistentModelID)
        XCTAssertEqual(fetched?.report.verdict, "improving")
        XCTAssertEqual(fetched?.report.working, ["Acne"])
        XCTAssertEqual(fetched?.report.updatedRoutine.first?.title, "Foam Wash")
        XCTAssertEqual(fetched?.report.updatedRoutine.first?.tags, ["Fragrance-free"])
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `xcodebuild test -project ClearMaxx.xcodeproj -scheme ClearMaxx -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' -only-testing:ClearMaxxTests/ProgressReportCacheTests 2>&1 | tail -30`
Expected: FAIL — `cannot find 'ProgressReport' in scope`.

- [ ] **Step 3: Implement `ProgressReport.swift`**

Create `ClearMaxxApp/ClearMaxx/Models/ProgressReport.swift`:

```swift
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
/// since costs zero API calls. Keyed to the latest `ScanRecord` it was built
/// from — a new scan simply won't match this key, which is how the cache
/// "invalidates" itself with no TTL bookkeeping.
@Model
final class ProgressReportCache {
    var latestScanID: PersistentIdentifier
    var verdict: String
    var headline: String
    var narrative: String
    var working: [String]
    var stalled: [String]
    var watch: [String]
    var updatedRoutineData: Data

    init(latestScanID: PersistentIdentifier, report: ProgressReport) {
        self.latestScanID = latestScanID
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
```

- [ ] **Step 4: Register the new model type in the app's `ModelContainer`**

In `ClearMaxxApp/ClearMaxx/ClearMaxxApp.swift`, replace line 25:

```swift
        .modelContainer(for: [ScanRecord.self, DailyRoutineChecklist.self])
```

with:

```swift
        .modelContainer(for: [ScanRecord.self, DailyRoutineChecklist.self, ProgressReportCache.self])
```

- [ ] **Step 5: Run the test to verify it passes**

Same command as Step 2. Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 6: Build and confirm no regressions**

Run: `xcodebuild build -project ClearMaxx.xcodeproj -scheme ClearMaxx -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' 2>&1 | tail -20`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 7: Commit**

```bash
git add ClearMaxxApp/ClearMaxx/Models/ProgressReport.swift ClearMaxxApp/ClearMaxx/ClearMaxxApp.swift ClearMaxxApp/ClearMaxxTests/ProgressReportCacheTests.swift
git commit -m "iOS: add ProgressReport model and SwiftData-backed cache"
```

---

### Task 5: Backend — `/api/skin/progress` endpoint

**Files:**
- Modify: `backend/main.py:214-228` (`_generate`), and additively after `_normalize_routine_step`/`_normalize`
- Modify: `backend/test_main.py`

**Interfaces:**
- Produces: `_generate(parts: list, prompt: str) -> str` (generalized — was `_generate(img_bytes: bytes) -> str`), `PROGRESS_PROMPT: str` (a `.format()` template with `{trends_json}`/`{routine_json}` placeholders), `_normalize_progress(parsed: dict, metric_names: set[str]) -> dict`, route `POST /api/skin/progress`.
- Response shape: `{"success": true, "result": {"verdict": str, "headline": str, "narrative": str, "working": [str], "stalled": [str], "watch": [str], "updatedRoutine": [<same shape as analyze's routineSteps>]}}`.

- [ ] **Step 1: Write the failing tests**

In `backend/test_main.py`, add at the end of the file:

```python
from main import _normalize_progress, PROGRESS_PROMPT


def test_normalize_progress_valid_passthrough():
    parsed = {
        "verdict": "improving",
        "headline": "Great progress",
        "narrative": "Your acne cleared up.",
        "working": ["Acne"],
        "stalled": ["Dark Spots"],
        "watch": [],
        "updatedRoutine": [
            {"time": "AM", "category": "Cleanser", "title": "Foam Wash",
             "detail": "Cleanses gently.", "tags": ["Fragrance-free"]},
        ],
    }
    result = _normalize_progress(parsed, metric_names={"Acne", "Dark Spots"})
    assert result["verdict"] == "improving"
    assert result["working"] == ["Acne"]
    assert result["stalled"] == ["Dark Spots"]
    assert result["updatedRoutine"][0]["title"] == "Foam Wash"


def test_normalize_progress_invalid_verdict_defaults_to_steady():
    parsed = {"verdict": "amazing!!", "working": [], "stalled": [], "watch": []}
    result = _normalize_progress(parsed, metric_names=set())
    assert result["verdict"] == "steady"


def test_normalize_progress_filters_hallucinated_metric_names():
    parsed = {"verdict": "steady", "working": ["Acne", "NotARealMetric"], "stalled": [], "watch": []}
    result = _normalize_progress(parsed, metric_names={"Acne"})
    assert result["working"] == ["Acne"]


def test_normalize_progress_caps_updated_routine_at_eight():
    one_step = {"time": "AM", "category": "C", "title": "T", "detail": "D", "tags": []}
    parsed = {"verdict": "steady", "working": [], "stalled": [], "watch": [], "updatedRoutine": [one_step] * 10}
    result = _normalize_progress(parsed, metric_names=set())
    assert len(result["updatedRoutine"]) == 8


def test_progress_prompt_has_trends_and_routine_placeholders():
    rendered = PROGRESS_PROMPT.format(trends_json="{}", routine_json="[]")
    assert "{}" in rendered
    assert "[]" in rendered
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd backend && python -m pytest test_main.py -v -k "progress" 2>&1 | tail -30`
Expected: FAIL — `ImportError: cannot import name '_normalize_progress' from 'main'`.

- [ ] **Step 3: Generalize `_generate` and update its existing call site**

In `backend/main.py`, replace lines 214-228:

```python
def _generate(img_bytes: bytes) -> str:
    """Call Vertex Gemini with the prompt + image; retry on the lite tier."""
    image_part = types.Part.from_bytes(data=img_bytes, mime_type="image/jpeg")
    config = types.GenerateContentConfig(response_mime_type="application/json",
                                         temperature=0.4)
    last_err = None
    for model in (PRIMARY_MODEL, FALLBACK_MODEL):
        try:
            resp = _client.models.generate_content(
                model=model, contents=[ANALYSIS_PROMPT, image_part], config=config)
            return (resp.text or "").strip()
        except Exception as e:  # e.g. model unavailable in region → try lite
            last_err = e
            print(f"[WARN] {model} failed ({e}); trying next tier.")
    raise last_err or RuntimeError("No Vertex model succeeded")
```

with:

```python
def _generate(parts: list, prompt: str) -> str:
    """Call Vertex Gemini with an arbitrary prompt + content parts; retry on the lite tier.

    Shared by /api/skin/analyze and /api/skin/progress so both endpoints get
    the same model-fallback behavior and the same bounded output budget.
    """
    config = types.GenerateContentConfig(response_mime_type="application/json",
                                         temperature=0.4, max_output_tokens=2048)
    last_err = None
    for model in (PRIMARY_MODEL, FALLBACK_MODEL):
        try:
            resp = _client.models.generate_content(
                model=model, contents=[prompt, *parts], config=config)
            return (resp.text or "").strip()
        except Exception as e:  # e.g. model unavailable in region → try lite
            last_err = e
            print(f"[WARN] {model} failed ({e}); trying next tier.")
    raise last_err or RuntimeError("No Vertex model succeeded")
```

Then, in `analyze_skin()` (around line 260), replace:

```python
        raw = _generate(img_bytes)
```

with:

```python
        image_part = types.Part.from_bytes(data=img_bytes, mime_type="image/jpeg")
        raw = _generate([image_part], ANALYSIS_PROMPT)
```

- [ ] **Step 4: Add `PROGRESS_PROMPT` and `_normalize_progress`**

In `backend/main.py`, add after `_normalize()` (after line 187, before the `# Routes` section):

```python
VERDICTS = {"improving", "steady", "worsening"}

PROGRESS_PROMPT = """
You are a dermatology-aware skin progress analyst for a consumer skincare app.
You are given TWO photos of the SAME person's face — the FIRST photo is their
earliest scan, the SECOND photo is their most recent scan — plus PRECOMPUTED,
ALREADY-CORRECT trend facts comparing their metrics between those two scans.

CRITICAL: The numeric trends given below are already computed correctly by
the app. Do NOT recompute, re-derive, or contradict them. Treat every value
in TRENDS as ground truth. Your job is to (1) visually compare the two
photos ONLY to describe what changed (texture, clarity, redness, etc.) — if
lighting, angle, or distance differ enough that the photos aren't visually
comparable, say so implicitly by relying on the given trends rather than
guessing from the images, (2) explain WHY the trends look the way they do in
plain, encouraging language, and (3) adapt the routine.

TRENDS (ground truth, do not alter the numbers):
{trends_json}

CURRENT ROUTINE:
{routine_json}

Return ONLY a JSON object (no markdown) with EXACTLY this shape:
{{
  "verdict": <one of "improving","steady","worsening">,
  "headline": <one short encouraging sentence, max 80 chars, consistent with verdict>,
  "narrative": <2-3 sentences explaining the trend in plain language, max 400 chars>,
  "working": [<metric names from TRENDS whose direction is "better">],
  "stalled": [<metric names from TRENDS whose direction is "flat">],
  "watch": [<metric names from TRENDS whose direction is "worse">],
  "updatedRoutine": [
    {{
      "time": <"AM" or "PM">,
      "category": <e.g. "Cleanser","Treatment","Moisturizer","Sunscreen">,
      "title": <short product/step name, max 40 chars>,
      "detail": <one sentence, max 140 chars, tied to a specific trend above>,
      "tags": [<0-3 short tags>]
    }}
    // 4-8 steps, adapted from CURRENT ROUTINE: keep steps tied to metrics
    // that are "working" as-is, and change the approach (different active
    // ingredient, different category) for steps tied to "stalled" or
    // "watch" metrics rather than repeating what evidently isn't moving them
  ]
}}

Rules:
- verdict MUST be consistent with the given trends: "improving" only if the
  overall trend or at least one metric is "better" and none are "worse";
  "worsening" only if at least one is "worse" and none improved; otherwise
  "steady".
- Never claim to detect medical conditions. Be encouraging but honest — do
  not claim improvement that the given trends do not support.
- Output raw JSON only.
""".strip()


def _normalize_progress(parsed: dict, metric_names: set) -> dict:
    """Coerce progress-analysis model output into the exact shape the app expects."""
    verdict = parsed.get("verdict") if parsed.get("verdict") in VERDICTS else "steady"

    def _filtered_names(key):
        return [str(x) for x in (parsed.get(key) or []) if str(x) in metric_names]

    return {
        "verdict": verdict,
        "headline": str(parsed.get("headline", ""))[:120],
        "narrative": str(parsed.get("narrative", ""))[:400],
        "working": _filtered_names("working"),
        "stalled": _filtered_names("stalled"),
        "watch": _filtered_names("watch"),
        "updatedRoutine": [
            _normalize_routine_step(s) for s in (parsed.get("updatedRoutine") or [])
            if isinstance(s, dict)
        ][:8],
    }
```

- [ ] **Step 5: Add the `/api/skin/progress` route**

In `backend/main.py`, add after the `analyze_skin()` route (after line 270, before `if __name__ == "__main__":`):

```python
@app.route("/api/skin/progress", methods=["POST"])
def analyze_progress():
    if _client is None:
        return jsonify({"error": "Server not configured (Vertex client unavailable)"}), 500
    if not _authorized(request):
        return jsonify({"error": "Unauthorized"}), 401

    data = request.get_json(silent=True) or {}
    trends = data.get("trends")
    overall = data.get("overall")
    if not isinstance(trends, list) or not trends or not isinstance(overall, dict):
        return jsonify({"error": "Missing or invalid trends/overall"}), 400

    def _decode_image(b64):
        if not b64:
            return None
        if "," in b64:
            b64 = b64.split(",", 1)[1]
        try:
            image = Image.open(io.BytesIO(base64.b64decode(b64)))
        except Exception:
            return None
        buf = io.BytesIO()
        image.convert("RGB").save(buf, format="JPEG", quality=90)
        return buf.getvalue()

    parts = []
    for key in ("first_image_base64", "latest_image_base64"):
        img_bytes = _decode_image(data.get(key))
        if img_bytes:
            parts.append(types.Part.from_bytes(data=img_bytes, mime_type="image/jpeg"))

    prompt = PROGRESS_PROMPT.format(
        trends_json=json.dumps({
            "overall": overall,
            "metrics": trends,
            "history": data.get("history") or [],
        }),
        routine_json=json.dumps(data.get("current_routine") or []),
    )

    try:
        raw = _generate(parts, prompt)
        try:
            parsed = json.loads(raw)
        except json.JSONDecodeError:
            s, e = raw.find("{"), raw.rfind("}")
            parsed = json.loads(raw[s:e + 1]) if s != -1 and e != -1 else {}
        metric_names = {t.get("name") for t in trends if isinstance(t, dict)}
        return jsonify({"success": True, "result": _normalize_progress(parsed, metric_names)})
    except Exception as e:
        print(f"[ERROR] progress analysis failed: {e}")
        return jsonify({"error": str(e)}), 500
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `cd backend && python -m pytest test_main.py -v 2>&1 | tail -40`
Expected: all tests pass, including the pre-existing `test_normalize_routine_steps_*` ones (confirming the `_generate` signature change didn't break the existing route's normalize path).

- [ ] **Step 7: Commit**

```bash
git add backend/main.py backend/test_main.py
git commit -m "Backend: add /api/skin/progress endpoint for history-aware trend analysis"
```

---

### Task 6: `ScanPhotoStore.downscaled` + `ProgressAnalysisService`

**Files:**
- Modify: `ClearMaxxApp/ClearMaxx/Services/SkinAnalysisService.swift:128` (drop `private` from the `UIImage` extension)
- Modify: `ClearMaxxApp/ClearMaxx/Services/ScanPhotoStore.swift`
- Create: `ClearMaxxApp/ClearMaxx/Services/ProgressAnalysisService.swift`

**Interfaces:**
- Consumes: `ProgressTrend`/`MetricTrend`/`ScanSnapshot`/`TrendDirection` (Task 3), `ProgressReport` (Task 4), `APIRoutineStep` (existing), `CMConfig.backendURL`/`CMConfig.appToken` (existing).
- Produces: `ScanPhotoStore.downscaled(_ fileName: String, maxEdge: CGFloat) -> UIImage?`; `enum ProgressAnalysisService { static func analyze(trend: ProgressTrend, firstImage: UIImage?, latestImage: UIImage?, currentRoutine: [APIRoutineStep]) async throws -> ProgressReport }`; `enum ProgressAnalysisError: LocalizedError`.
- Used by: Task 9 (`SkinProgressView` wiring).

This task has no new pure logic to TDD in isolation (it's a thin network client, matching the existing untested `SkinAnalysisService` precedent) — verification is a build check plus a manual `curl` smoke test against the locally-running backend from Task 5.

- [ ] **Step 1: Expose the existing resize helper for reuse**

In `ClearMaxxApp/ClearMaxx/Services/SkinAnalysisService.swift`, change line 128:

```swift
private extension UIImage {
```

to:

```swift
extension UIImage {
```

- [ ] **Step 2: Add `ScanPhotoStore.downscaled`**

In `ClearMaxxApp/ClearMaxx/Services/ScanPhotoStore.swift`, add at the end of the file (after the closing brace of the `ScanPhotoStore` enum):

```swift

extension ScanPhotoStore {
    /// Loads a saved scan photo downscaled to `maxEdge` on its longest side —
    /// used by progress analysis to keep upload payloads (and Gemini's
    /// per-image tiling cost) small without touching the full-res original.
    static func downscaled(_ fileName: String, maxEdge: CGFloat) -> UIImage? {
        load(fileName)?.cm_resized(maxDimension: maxEdge)
    }
}
```

- [ ] **Step 3: Implement `ProgressAnalysisService.swift`**

Create `ClearMaxxApp/ClearMaxx/Services/ProgressAnalysisService.swift`:

```swift
//
//  ProgressAnalysisService.swift
//  ClearMaxx — calls the backend to compare scan history and get a progress verdict + adapted routine.
//

import UIKit

/// User-facing progress-analysis errors, mirroring SkinAnalysisError's calm,
/// plain-language pattern — we never surface raw status codes to the user.
enum ProgressAnalysisError: LocalizedError {
    case encodingFailed
    case offline
    case timedOut
    case unauthorized
    case rateLimited
    case serverBusy
    case unknown

    var errorDescription: String? {
        switch self {
        case .encodingFailed: return "We couldn't prepare your scan history. Please try again."
        case .offline:        return "You appear to be offline. Check your connection and try again."
        case .timedOut:       return "This is taking longer than usual. Please try again."
        case .unauthorized:   return "We couldn't start your progress check right now. Please update ClearMaxx or try again later."
        case .rateLimited:    return "A lot of progress checks are happening right now. Please try again in a moment."
        case .serverBusy:     return "Our progress analysis is taking a quick break. Please try again shortly."
        case .unknown:        return "Something went wrong while checking your progress. Please try again."
        }
    }
}

private struct ProgressResponseEnvelope: Codable {
    let success: Bool?
    let result: ProgressReport?
    let error: String?
}

enum ProgressAnalysisService {
    /// Images are capped smaller than the single-scan path (768px vs 1024px) —
    /// judging visual change across two photos needs far less detail than the
    /// primary per-scan analysis, and this call sends two images, not one.
    private static let maxImageEdge: CGFloat = 768

    static func analyze(trend: ProgressTrend, firstImage: UIImage?, latestImage: UIImage?,
                        currentRoutine: [APIRoutineStep]) async throws -> ProgressReport {
        var body: [String: Any] = [
            "span_days": trend.spanDays,
            "scan_count": trend.scanCount,
            "overall": [
                "first_score": trend.overallFirstScore,
                "latest_score": trend.overallLatestScore,
                "direction": trend.overallDirection.rawValue,
            ],
            "trends": trend.metricTrends.map {
                ["name": $0.name, "first_value": $0.firstValue,
                 "latest_value": $0.latestValue, "direction": $0.direction.rawValue]
            },
            "history": trend.sampledHistory.map {
                ["date": ISO8601DateFormatter().string(from: $0.date), "score": $0.clearScore]
            },
            "current_routine": currentRoutine.map {
                ["time": $0.time, "category": $0.category, "title": $0.title,
                 "detail": $0.detail, "tags": $0.tags]
            },
        ]
        if let firstImage, let jpeg = firstImage.cm_resized(maxDimension: maxImageEdge).jpegData(compressionQuality: 0.7) {
            body["first_image_base64"] = jpeg.base64EncodedString()
        }
        if let latestImage, let jpeg = latestImage.cm_resized(maxDimension: maxImageEdge).jpegData(compressionQuality: 0.7) {
            body["latest_image_base64"] = jpeg.base64EncodedString()
        }

        var req = URLRequest(url: CMConfig.backendURL.appendingPathComponent("api/skin/progress"))
        req.httpMethod = "POST"
        req.timeoutInterval = 60
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(CMConfig.appToken, forHTTPHeaderField: "X-App-Token")
        do {
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            throw ProgressAnalysisError.encodingFailed
        }

        let data: Data
        let resp: URLResponse
        do {
            (data, resp) = try await URLSession.shared.data(for: req)
        } catch let e as URLError {
            switch e.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
                throw ProgressAnalysisError.offline
            case .timedOut:
                throw ProgressAnalysisError.timedOut
            default:
                print("[ProgressAnalysis] network error: \(e.code.rawValue) \(e.localizedDescription)")
                throw ProgressAnalysisError.unknown
            }
        }

        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        let decoded = try? JSONDecoder().decode(ProgressResponseEnvelope.self, from: data)

        guard status == 200, let result = decoded?.result else {
            print("[ProgressAnalysis] server \(status): \(decoded?.error ?? "no body")")
            switch status {
            case 401, 403:  throw ProgressAnalysisError.unauthorized
            case 429:       throw ProgressAnalysisError.rateLimited
            case 500...599: throw ProgressAnalysisError.serverBusy
            default:        throw ProgressAnalysisError.unknown
            }
        }
        return result
    }
}
```

- [ ] **Step 4: Build and confirm it compiles**

Run: `xcodebuild build -project ClearMaxx.xcodeproj -scheme ClearMaxx -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' 2>&1 | tail -20`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Manual smoke test against the local backend**

Run the backend locally (per its existing `README.md` dev instructions), then:

```bash
curl -s -X POST http://localhost:8080/api/skin/progress \
  -H "Content-Type: application/json" \
  -H "X-App-Token: $APP_TOKEN" \
  -d '{
    "span_days": 30, "scan_count": 2,
    "overall": {"first_score": 60, "latest_score": 72, "direction": "better"},
    "trends": [{"name": "Acne", "first_value": 55, "latest_value": 30, "direction": "better"}],
    "history": [{"date": "2026-07-01T00:00:00Z", "score": 60}, {"date": "2026-08-01T00:00:00Z", "score": 72}],
    "current_routine": []
  }' | python3 -m json.tool
```
Expected: HTTP 200, a JSON body with `"success": true` and a `result` containing `verdict`, `headline`, `narrative`, `working`/`stalled`/`watch`, and `updatedRoutine`.

- [ ] **Step 6: Commit**

```bash
git add ClearMaxxApp/ClearMaxx/Services/SkinAnalysisService.swift ClearMaxxApp/ClearMaxx/Services/ScanPhotoStore.swift ClearMaxxApp/ClearMaxx/Services/ProgressAnalysisService.swift
git commit -m "iOS: add ProgressAnalysisService and downscaled photo loading"
```

---

### Task 7: `AppState.applyUpdatedRoutine`

**Files:**
- Modify: `ClearMaxxApp/ClearMaxx/Models/Models.swift:142-167`

**Interfaces:**
- Consumes: `APIRoutineStep` (existing), `ModelContext` (SwiftData).
- Produces: `func AppState.applyUpdatedRoutine(_ steps: [APIRoutineStep], modelContext: ModelContext)`.
- Used by: Task 8 (`ProgressReportView`).

`upsertTodayChecklist` already does exactly what "apply an AI routine to today's checklist, preserving `done` state" needs — this task reuses it instead of duplicating checklist-building logic for the progress-report path.

- [ ] **Step 1: Make `upsertTodayChecklist` accessible outside `AppState`'s own calls**

In `ClearMaxxApp/ClearMaxx/Models/Models.swift`, change line 145:

```swift
    private func upsertTodayChecklist(from apiSteps: [APIRoutineStep], modelContext: ModelContext) {
```

to:

```swift
    func upsertTodayChecklist(from apiSteps: [APIRoutineStep], modelContext: ModelContext) {
```

- [ ] **Step 2: Add `applyUpdatedRoutine`**

In `ClearMaxxApp/ClearMaxx/Models/Models.swift`, add directly after the `upsertTodayChecklist` method (after its closing brace, before `func resetAnalysis()`):

```swift

    /// Replaces today's routine checklist with the AI's progress-adapted
    /// steps, preserving `done` state exactly like a normal rescan would
    /// (via `upsertTodayChecklist`'s existing title-matching behavior).
    func applyUpdatedRoutine(_ steps: [APIRoutineStep], modelContext: ModelContext) {
        upsertTodayChecklist(from: steps, modelContext: modelContext)
        do {
            try modelContext.save()
        } catch {
            print("[AppState] Could not save updated routine: \(error)")
        }
    }
```

- [ ] **Step 3: Build and confirm no regressions**

Run: `xcodebuild build -project ClearMaxx.xcodeproj -scheme ClearMaxx -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' 2>&1 | tail -20`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add ClearMaxxApp/ClearMaxx/Models/Models.swift
git commit -m "iOS: add AppState.applyUpdatedRoutine for progress-report routine adoption"
```

---

### Task 8: `ProgressReportView`

**Files:**
- Create: `ClearMaxxApp/ClearMaxx/Screens/ProgressReportView.swift`

**Interfaces:**
- Consumes: `ProgressReport` (Task 4), `AppState.applyUpdatedRoutine` (Task 7), design-system components already used throughout the app (`DewyBackground`, `GlassCard`, `AuraButton`, `TagChip`, `CMFont`, `CMColor` — all from `DesignSystem/Components.swift` and `DesignSystem/Theme.swift`).
- Produces: `struct ProgressReportView: View { let report: ProgressReport }`.
- Used by: Task 9 (presented from `SkinProgressView`).

This is a leaf UI view with no new business logic — verification is a build check plus the Xcode preview and the manual end-to-end check in Task 9.

- [ ] **Step 1: Implement `ProgressReportView.swift`**

Create `ClearMaxxApp/ClearMaxx/Screens/ProgressReportView.swift`:

```swift
//
//  ProgressReportView.swift
//  ClearMaxx — shows the AI's read on scan-history progress and lets the user adopt the adapted routine.
//

import SwiftUI
import SwiftData

struct ProgressReportView: View {
    @ObserveInjection var inject
    @EnvironmentObject var state: AppState
    @Environment(\.modelContext) private var modelContext
    let report: ProgressReport
    @State private var didUpdateRoutine = false

    var body: some View {
        DewyBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(report.headline).font(CMFont.headlineLg).foregroundStyle(CMColor.ink)
                        Text(report.narrative).font(CMFont.bodyMd).foregroundStyle(CMColor.inkSoft)
                    }

                    if !report.working.isEmpty {
                        trendSection(title: "Working", names: report.working, color: CMColor.success)
                    }
                    if !report.stalled.isEmpty {
                        trendSection(title: "Stalled", names: report.stalled, color: CMColor.inkSoft)
                    }
                    if !report.watch.isEmpty {
                        trendSection(title: "Watch", names: report.watch, color: CMColor.error)
                    }

                    if !report.updatedRoutine.isEmpty {
                        AuraButton(title: didUpdateRoutine ? "Routine Updated" : "Update My Routine",
                                  systemImage: didUpdateRoutine ? "checkmark" : "arrow.triangle.2.circlepath") {
                            state.applyUpdatedRoutine(report.updatedRoutine, modelContext: modelContext)
                            didUpdateRoutine = true
                        }
                        .disabled(didUpdateRoutine)
                    }
                }
                .padding(.horizontal, 24).padding(.top, 8).padding(.bottom, 24)
            }
        }
    }

    private func trendSection(title: String, names: [String], color: Color) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(title).font(CMFont.title).foregroundStyle(CMColor.ink)
                HStack { ForEach(names, id: \.self) { TagChip(text: $0) } }
            }
        }
    }
}

#Preview {
    ProgressReportView(report: ProgressReport(
        verdict: "improving", headline: "You're making real progress",
        narrative: "Your acne and redness have both improved since your first scan.",
        working: ["Acne", "Redness"], stalled: ["Dark Spots"], watch: [],
        updatedRoutine: []))
    .environmentObject(AppState())
    .modelContainer(for: [ScanRecord.self, DailyRoutineChecklist.self, ProgressReportCache.self], inMemory: true)
}
```

- [ ] **Step 2: Build and confirm it compiles**

Run: `xcodebuild build -project ClearMaxx.xcodeproj -scheme ClearMaxx -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' 2>&1 | tail -20`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add ClearMaxxApp/ClearMaxx/Screens/ProgressReportView.swift
git commit -m "iOS: add ProgressReportView"
```

---

### Task 9: Wire `SkinProgressView` — button, gating, cache, and error states

**Files:**
- Modify: `ClearMaxxApp/ClearMaxx/Screens/SkinProgressView.swift`

**Interfaces:**
- Consumes: `ProgressTrendCalculator.eligibility(for:)` (Task 3), `ProgressReportCache` (Task 4), `ProgressAnalysisService.analyze(...)` (Task 6), `ProgressReportView` (Task 8), `AppState.isPremium` (existing), `GoPremiumView` (existing, presented via `.sheet` per the established `ProfileView.swift:135` pattern), `DailyRoutineChecklist`/`PersistedRoutineStep` (existing, from `ScanHistory.swift` — used to source the actual persisted current routine rather than the transient `state.analysis`).

This is the final integration task — verified with a manual end-to-end run since it depends on network + SwiftData + premium entitlement state together, which is more reliably checked live than mocked.

- [ ] **Step 1: Add state and the cache query**

In `ClearMaxxApp/ClearMaxx/Screens/SkinProgressView.swift`, replace lines 9-18:

```swift
struct SkinProgressView: View {
    @ObserveInjection var inject
    @EnvironmentObject var state: AppState
    @Query(sort: \ScanRecord.date) private var scanRecords: [ScanRecord]
    @State private var slider: CGFloat = 0.5
    @State private var showShare = false

    private var first: ScanRecord? { scanRecords.first }
    private var latest: ScanRecord? { scanRecords.last }
    private var previous: ScanRecord? { scanRecords.count >= 2 ? scanRecords[scanRecords.count - 2] : nil }
```

with:

```swift
struct SkinProgressView: View {
    @ObserveInjection var inject
    @EnvironmentObject var state: AppState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ScanRecord.date) private var scanRecords: [ScanRecord]
    @Query private var progressCaches: [ProgressReportCache]
    @Query private var todayChecklist: [DailyRoutineChecklist]
    @State private var slider: CGFloat = 0.5
    @State private var showShare = false
    @State private var showPaywall = false
    @State private var isAnalyzingProgress = false
    @State private var progressReport: ProgressReport?
    @State private var showProgressReport = false
    @State private var progressAnalysisError: String?

    // `todayChecklist` needs a predicate, so every other @Query on this view
    // must also be assigned explicitly here (SwiftData requires all @Query
    // properties to be set together once any one of them gets a custom init) —
    // same pattern DailyRoutineView already uses for its own filtered query.
    init() {
        _scanRecords = Query(sort: \ScanRecord.date)
        _progressCaches = Query()
        let startOfDay = Calendar.current.startOfDay(for: Date())
        _todayChecklist = Query(filter: #Predicate<DailyRoutineChecklist> { $0.day == startOfDay })
    }

    private var first: ScanRecord? { scanRecords.first }
    private var latest: ScanRecord? { scanRecords.last }
    private var previous: ScanRecord? { scanRecords.count >= 2 ? scanRecords[scanRecords.count - 2] : nil }
    private var eligibility: ProgressEligibility { ProgressTrendCalculator.eligibility(for: scanRecords) }

    /// The routine actually on the user's checklist today (persists across
    /// launches), not `state.analysis` — which is only populated in-memory
    /// right after a scan and is `nil` again the next time the app opens.
    private var currentRoutineForAnalysis: [APIRoutineStep] {
        (todayChecklist.first?.steps ?? []).map {
            APIRoutineStep(time: $0.time, category: $0.category, title: $0.title,
                           detail: $0.detail, tags: $0.tags)
        }
    }
```

- [ ] **Step 2: Add the "Analyze My Progress" section to the body**

In the same file, replace the `if scanRecords.count < 2 { ... } else { metricDeltaCard }` block (lines 47-52):

```swift
                        if scanRecords.count < 2 {
                            emptyState(title: "Scan again to see your trend",
                                       body: "One more scan will start showing how each metric is changing.")
                        } else {
                            metricDeltaCard
                        }
```

with:

```swift
                        if scanRecords.count < 2 {
                            emptyState(title: "Scan again to see your trend",
                                       body: "One more scan will start showing how each metric is changing.")
                        } else {
                            metricDeltaCard
                        }

                        progressAnalysisSection
```

- [ ] **Step 3: Implement `progressAnalysisSection` and the analysis flow**

In the same file, add these members inside `SkinProgressView` (after the `metricDeltaCard` computed property, before `emptyState`):

```swift
    @ViewBuilder
    private var progressAnalysisSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Analyze My Progress").font(CMFont.title).foregroundStyle(CMColor.ink)

                switch eligibility {
                case .notEnoughScans:
                    Text("Scan at least twice to see whether it's working.")
                        .font(CMFont.bodyMd).foregroundStyle(CMColor.inkSoft)
                case .tooRecentSpan(let daysRemaining):
                    Text("Your scans span less than a week — give your skin \(daysRemaining) more day\(daysRemaining == 1 ? "" : "s") before checking progress.")
                        .font(CMFont.bodyMd).foregroundStyle(CMColor.inkSoft)
                case .eligible:
                    if let progressAnalysisError {
                        Text(progressAnalysisError).font(CMFont.bodyMd).foregroundStyle(CMColor.error)
                    }
                    AuraButton(title: isAnalyzingProgress ? "Analyzing…" : "Analyze My Progress",
                              systemImage: "sparkles") {
                        Task { await requestProgressAnalysis() }
                    }
                    .disabled(isAnalyzingProgress)
                }
            }
        }
        .sheet(isPresented: $showPaywall) { GoPremiumView() }
        .sheet(isPresented: $showProgressReport) {
            if let progressReport { ProgressReportView(report: progressReport) }
        }
    }

    @MainActor
    private func requestProgressAnalysis() async {
        guard case .eligible(let trend) = eligibility else { return }
        guard state.isPremium else {
            showPaywall = true
            return
        }
        guard let latest else { return }

        if let cached = progressCaches.first(where: { $0.latestScanID == latest.persistentModelID }) {
            progressReport = cached.report
            showProgressReport = true
            return
        }

        progressAnalysisError = nil
        isAnalyzingProgress = true
        defer { isAnalyzingProgress = false }

        do {
            let firstImage = first.flatMap { ScanPhotoStore.downscaled($0.photoFileName, maxEdge: 768) }
            let latestImage = ScanPhotoStore.downscaled(latest.photoFileName, maxEdge: 768)
            let report = try await ProgressAnalysisService.analyze(
                trend: trend, firstImage: firstImage, latestImage: latestImage,
                currentRoutine: currentRoutineForAnalysis)

            let cache = ProgressReportCache(latestScanID: latest.persistentModelID, report: report)
            modelContext.insert(cache)
            try? modelContext.save()

            progressReport = report
            showProgressReport = true
        } catch {
            progressAnalysisError = error.localizedDescription
        }
    }
```

- [ ] **Step 4: Update the `#Preview` to include the new model type**

`SkinProgressView` now runs a `@Query` over `ProgressReportCache`, so its preview's `modelContainer` must include that type or the preview crashes. Replace the file's final lines:

```swift
#Preview {
    SkinProgressView()
        .environmentObject(AppState())
        .modelContainer(for: [ScanRecord.self, DailyRoutineChecklist.self], inMemory: true)
}
```

with:

```swift
#Preview {
    SkinProgressView()
        .environmentObject(AppState())
        .modelContainer(for: [ScanRecord.self, DailyRoutineChecklist.self, ProgressReportCache.self], inMemory: true)
}
```

- [ ] **Step 5: Build and confirm it compiles**

Run: `xcodebuild build -project ClearMaxx.xcodeproj -scheme ClearMaxx -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' 2>&1 | tail -20`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Manual end-to-end verification on the simulator**

1. Launch the app on the simulator (`xcodebuild build` output app, or run from Xcode).
2. Complete two scans at least a week apart. (For simulator testing, temporarily lower `ProgressTrendCalculator.minSpanDays` to `0` locally, test, then revert before committing — do not commit a lowered threshold.)
3. As a **non-premium** test account: confirm tapping "Analyze My Progress" opens the paywall (`GoPremiumView`) and makes no network call.
4. As a **premium** test account: confirm tapping the button shows "Analyzing…", then presents `ProgressReportView` with a verdict, headline, narrative, and (if returned) working/stalled/watch chips.
5. Tap "Update My Routine" and confirm the Routine tab's today checklist reflects the new steps, with any previously-checked items whose titles survived still checked.
6. Dismiss and reopen the progress report (same latest scan): confirm it appears **instantly with no loading state** — this is the cache hit. Optionally confirm via a network proxy or by temporarily adding a `print` in `ProgressAnalysisService.analyze` that no second call fires.
7. Take a new scan, then tap "Analyze My Progress" again: confirm a fresh network call fires (cache miss on the new `latestScanID`) and a new report is cached.

- [ ] **Step 7: Commit**

```bash
git add ClearMaxxApp/ClearMaxx/Screens/SkinProgressView.swift
git commit -m "iOS: wire Analyze My Progress button into SkinProgressView"
```
