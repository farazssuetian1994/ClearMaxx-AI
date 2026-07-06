# AI Routine + Real Progress Tracking Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close ClearMaxx's core loop — wire the backend's AI-generated routine into a real daily checklist, and replace the Progress tab's fake data with real, locally-persisted scan history (trend, before/after photos, per-metric deltas, and a resolved-metric celebration).

**Architecture:** The backend's Gemini prompt/schema changes to emit structured routine steps instead of flat strings. On-device, SwiftData persists every scan (score, per-metric severity, photo) and a daily routine checklist; the Progress and Routine tabs read from SwiftData via `@Query` instead of hardcoded mock arrays. A pure, dependency-free diff function detects when a metric newly improves into the "Good" severity tier and triggers a celebration screen (the existing `GlowUpShareView`, now fed real data) before landing on the normal results screen.

**Tech Stack:** Python/Flask backend on Vertex AI Gemini (unchanged runtime, schema-only change), pytest for backend unit tests, Swift 5 / SwiftUI / SwiftData (iOS 17+ deployment target, already set).

## Global Constraints

- iOS deployment target is 17.0 (confirmed in `project.pbxproj`) — SwiftData, `@Query`, and `#Predicate` are all available, no compatibility shims needed.
- The project has **no XCTest target today** and none is added by this plan (adding one is out-of-scope Xcode-project surgery, per the "don't unilaterally restructure" rule). Every iOS task instead ends with a real, concrete verification step: either `xcodebuild build` succeeding, or — for the one piece of pure, UIKit-free business logic (`ResolutionDiff`) — a standalone `swiftc`-compiled assertion script run directly from the command line (no Xcode project changes required).
- The backend has no existing test infra; this plan adds `pytest` as a **dev-only** dependency (`backend/requirements-dev.txt`), not to the deployed `requirements.txt`, so App Engine deploys are unaffected.
- All secrets/build conventions from the existing `fetch-secrets.sh` / `reload.sh` scripts apply unchanged — do not bypass them.
- This is a pre-release/personal app (no external API consumers) — the backend's `routineSuggestions` → `routineSteps` schema change is a breaking API change made deliberately, per the approved spec, with backend deploy deferred to the final task so the change ships together with the iOS rebuild rather than sitting live-but-mismatched for multiple intermediate tasks.
- Full spec: `docs/superpowers/specs/2026-07-06-ai-routine-progress-tracking-design.md`.

---

### Task 1: Backend — structured routine schema

**Files:**
- Modify: `backend/main.py:96-123` (ANALYSIS_PROMPT), `backend/main.py:133-154` (`_normalize`)
- Create: `backend/requirements-dev.txt`
- Create: `backend/test_main.py`

**Interfaces:**
- Produces: `_normalize(parsed: dict) -> dict` now returns `result["routineSteps"]` as `list[dict]` with keys `time` ("AM"/"PM"), `category`, `title`, `detail`, `tags` (list[str], max 3), capped at 8 items — replacing the old `routineSuggestions: list[str]`.

- [ ] **Step 1: Replace the `routineSuggestions` schema line in `ANALYSIS_PROMPT`**

In `backend/main.py`, replace line 116 (`  "routineSuggestions": [<3-5 short routine steps tailored to this face>]`) with:

```python
  "routineSteps": [
    {{
      "time": <"AM" or "PM">,
      "category": <e.g. "Cleanser","Treatment","Moisturizer","Sunscreen">,
      "title": <short product/step name, max 40 chars>,
      "detail": <one sentence on why/how, max 140 chars>,
      "tags": [<0-3 short tags, e.g. "Fragrance-free">]
    }}
    // 4-8 steps total, a mix of AM and PM, tailored to the metrics above
  ]
```

- [ ] **Step 2: Add routine-step coercion and use it in `_normalize`**

In `backend/main.py`, add this helper directly above `_normalize` (after `_safe_int`, before line 133):

```python
def _normalize_routine_step(s: dict) -> dict:
    """Coerce one routine-step object into the exact shape the app expects."""
    time = s.get("time") if s.get("time") in {"AM", "PM"} else "AM"
    return {
        "time": time,
        "category": str(s.get("category", ""))[:40],
        "title": str(s.get("title", ""))[:40],
        "detail": str(s.get("detail", ""))[:160],
        "tags": [str(x) for x in (s.get("tags") or [])][:3],
    }
```

Then replace line 153 (`"routineSuggestions": [str(x) for x in (parsed.get("routineSuggestions") or [])][:5],`) with:

```python
        "routineSteps": [
            _normalize_routine_step(s) for s in (parsed.get("routineSteps") or [])
            if isinstance(s, dict)
        ][:8],
```

- [ ] **Step 3: Add dev-only pytest dependency**

Create `backend/requirements-dev.txt`:

```
-r requirements.txt
pytest
```

- [ ] **Step 4: Write pytest unit tests for the new normalize behavior**

Create `backend/test_main.py`:

```python
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from main import _normalize, METRICS


def _full_metric(name):
    return {
        "name": name, "value": 50, "severity": "Mild",
        "summary": "test", "ingredients": ["A"], "tips": ["B"],
    }


def _base_parsed(**overrides):
    parsed = {
        "clearScore": 80, "confidence": 90, "skinType": "Normal", "summary": "ok",
        "metrics": [_full_metric(m) for m in METRICS],
    }
    parsed.update(overrides)
    return parsed


def test_normalize_routine_steps_valid_passthrough():
    parsed = _base_parsed(routineSteps=[
        {"time": "AM", "category": "Cleanser", "title": "Foam Wash",
         "detail": "Cleanses gently.", "tags": ["Fragrance-free"]},
        {"time": "PM", "category": "Treatment", "title": "Retinol Serum",
         "detail": "Renews overnight.", "tags": []},
    ])
    result = _normalize(parsed)
    assert result["routineSteps"] == [
        {"time": "AM", "category": "Cleanser", "title": "Foam Wash",
         "detail": "Cleanses gently.", "tags": ["Fragrance-free"]},
        {"time": "PM", "category": "Treatment", "title": "Retinol Serum",
         "detail": "Renews overnight.", "tags": []},
    ]


def test_normalize_routine_steps_missing_key_defaults_empty():
    result = _normalize(_base_parsed())
    assert result["routineSteps"] == []


def test_normalize_routine_steps_invalid_time_defaults_to_am():
    parsed = _base_parsed(routineSteps=[
        {"time": "Evening", "category": "Cleanser", "title": "X", "detail": "Y", "tags": []},
    ])
    result = _normalize(parsed)
    assert result["routineSteps"][0]["time"] == "AM"


def test_normalize_routine_steps_caps_tags_and_step_count():
    one_step = {"time": "AM", "category": "C", "title": "T", "detail": "D",
                "tags": ["a", "b", "c", "d", "e"]}
    parsed = _base_parsed(routineSteps=[one_step] * 10)
    result = _normalize(parsed)
    assert len(result["routineSteps"]) == 8
    assert len(result["routineSteps"][0]["tags"]) == 3


def test_normalize_routine_steps_ignores_non_dict_items():
    parsed = _base_parsed(routineSteps=[
        "just a string",
        {"time": "PM", "category": "C", "title": "T", "detail": "D", "tags": []},
    ])
    result = _normalize(parsed)
    assert len(result["routineSteps"]) == 1
    assert result["routineSteps"][0]["time"] == "PM"
```

- [ ] **Step 5: Run the tests and verify they pass**

Run:
```bash
cd backend && pip install -r requirements-dev.txt -q && python3 -m pytest test_main.py -v
```
Expected: all 5 tests `PASSED`.

- [ ] **Step 6: Commit**

```bash
git add backend/main.py backend/requirements-dev.txt backend/test_main.py
git commit -m "Backend: return structured AM/PM routine steps instead of flat strings"
```

---

### Task 2: iOS — update the API contract to match

**Files:**
- Modify: `ClearMaxxApp/ClearMaxx/Services/SkinAnalysisService.swift:20-27`

**Interfaces:**
- Consumes: backend's `routineSteps` shape from Task 1 (`time`, `category`, `title`, `detail`, `tags`).
- Produces: `SkinAnalysis.routineSteps: [APIRoutineStep]`, `struct APIRoutineStep: Codable { time, category, title, detail, tags }`.

- [ ] **Step 1: Replace `routineSuggestions` with `routineSteps` on `SkinAnalysis` and add `APIRoutineStep`**

In `SkinAnalysisService.swift`, replace lines 20-27:

```swift
struct SkinAnalysis: Codable {
    let clearScore: Int
    let confidence: Int
    let skinType: String
    let summary: String
    let metrics: [APIMetric]
    let routineSuggestions: [String]
}

struct APIMetric: Codable {
    let name: String
    let value: Int
    let severity: String
    let summary: String
    let ingredients: [String]
    let tips: [String]
}
```

with:

```swift
struct SkinAnalysis: Codable {
    let clearScore: Int
    let confidence: Int
    let skinType: String
    let summary: String
    let metrics: [APIMetric]
    let routineSteps: [APIRoutineStep]
}

struct APIMetric: Codable {
    let name: String
    let value: Int
    let severity: String
    let summary: String
    let ingredients: [String]
    let tips: [String]
}

struct APIRoutineStep: Codable {
    let time: String       // "AM" or "PM"
    let category: String
    let title: String
    let detail: String
    let tags: [String]
}
```

- [ ] **Step 2: Verify the project still builds**

Run:
```bash
cd ClearMaxxApp && xcodebuild -project ClearMaxx.xcodeproj -scheme ClearMaxx -configuration Debug \
  -destination "generic/platform=iOS Simulator" build 2>&1 | tail -20
```
Expected: `** BUILD SUCCEEDED **`. (Nothing in the app currently reads `analysis.routineSuggestions`, so this rename has no other call sites to fix yet.)

- [ ] **Step 3: Commit**

```bash
git add ClearMaxxApp/ClearMaxx/Services/SkinAnalysisService.swift
git commit -m "iOS: decode structured routineSteps instead of flat routineSuggestions"
```

---

### Task 3: iOS — SwiftData persistence models + resolution-diff logic

**Files:**
- Create: `ClearMaxxApp/ClearMaxx/Models/ResolutionDiff.swift`
- Create: `ClearMaxxApp/ClearMaxx/Models/ScanHistory.swift`
- Modify: `ClearMaxxApp/ClearMaxx/ClearMaxxApp.swift`

**Interfaces:**
- Produces: `struct PersistedMetric: Codable, Hashable { name, value, severity }`; `enum ResolutionDiff { static func newlyResolved(current: [PersistedMetric], previous: [PersistedMetric]?) -> [PersistedMetric] }`; `@Model class ScanRecord { date, clearScore, confidence, skinType, summary, metrics: [PersistedMetric], photoFileName }`; `@Model class DailyRoutineChecklist { day, steps: [PersistedRoutineStep] }`; `struct PersistedRoutineStep: Codable, Hashable { time, category, title, detail, tags, done }`; app-wide `ModelContainer` registered for `ScanRecord` and `DailyRoutineChecklist`.

- [ ] **Step 1: Create the pure diff logic (no SwiftData/UIKit dependency, so it's independently verifiable)**

Create `ClearMaxxApp/ClearMaxx/Models/ResolutionDiff.swift`:

```swift
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
```

- [ ] **Step 2: Verify the diff logic with a standalone compiled assertion script**

Run:
```bash
VERIFY_DIR=$(mktemp -d)
cat > "$VERIFY_DIR/main.swift" <<'EOF'
import Foundation

let noPrevious = ResolutionDiff.newlyResolved(
    current: [PersistedMetric(name: "Acne", value: 10, severity: "Good")], previous: nil)
assert(noPrevious.isEmpty, "expected no resolution without a previous scan")

let previouslyModerate = [PersistedMetric(name: "Acne", value: 60, severity: "Moderate")]
let nowGood = [PersistedMetric(name: "Acne", value: 10, severity: "Good")]
let resolved = ResolutionDiff.newlyResolved(current: nowGood, previous: previouslyModerate)
assert(resolved == nowGood, "expected Acne to be newly resolved")

let alreadyGood = [PersistedMetric(name: "Acne", value: 10, severity: "Good")]
let stillGood = ResolutionDiff.newlyResolved(current: nowGood, previous: alreadyGood)
assert(stillGood.isEmpty, "expected no re-celebration for an already-Good metric")

let mixed = ResolutionDiff.newlyResolved(
    current: [PersistedMetric(name: "Acne", value: 10, severity: "Good"),
              PersistedMetric(name: "Redness", value: 55, severity: "Moderate")],
    previous: [PersistedMetric(name: "Acne", value: 60, severity: "Moderate"),
               PersistedMetric(name: "Redness", value: 55, severity: "Moderate")])
assert(mixed == [PersistedMetric(name: "Acne", value: 10, severity: "Good")], "expected only Acne to resolve")

print("All ResolutionDiff tests passed")
EOF
swiftc "$VERIFY_DIR/main.swift" "ClearMaxxApp/ClearMaxx/Models/ResolutionDiff.swift" -o "$VERIFY_DIR/verify" \
  && "$VERIFY_DIR/verify"
```
Expected output: `All ResolutionDiff tests passed`, exit code 0.

- [ ] **Step 3: Create the SwiftData persistence models**

Create `ClearMaxxApp/ClearMaxx/Models/ScanHistory.swift`:

```swift
//
//  ScanHistory.swift
//  ClearMaxx — SwiftData persistence: one record per scan, one checklist per day.
//

import Foundation
import SwiftData

@Model
final class ScanRecord {
    var date: Date
    var clearScore: Int
    var confidence: Int
    var skinType: String
    var summary: String
    var metrics: [PersistedMetric]
    var photoFileName: String

    init(date: Date, clearScore: Int, confidence: Int, skinType: String,
         summary: String, metrics: [PersistedMetric], photoFileName: String) {
        self.date = date
        self.clearScore = clearScore
        self.confidence = confidence
        self.skinType = skinType
        self.summary = summary
        self.metrics = metrics
        self.photoFileName = photoFileName
    }
}

@Model
final class DailyRoutineChecklist {
    var day: Date
    var steps: [PersistedRoutineStep]

    init(day: Date, steps: [PersistedRoutineStep]) {
        self.day = day
        self.steps = steps
    }
}

struct PersistedRoutineStep: Codable, Hashable {
    var time: String       // "AM" or "PM"
    var category: String
    var title: String
    var detail: String
    var tags: [String]
    var done: Bool
}
```

- [ ] **Step 4: Register the SwiftData container at the app root**

In `ClearMaxxApp.swift`, replace the full file with:

```swift
//
//  ClearMaxxApp.swift
//  ClearMaxx — AI Skin & Face Scanner
//

import SwiftUI
import SwiftData

@main
struct ClearMaxxApp: App {
    @StateObject private var state = AppState()

    init() { startHotReload() }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(state)
                .tint(CMColor.violet)
                .preferredColorScheme(.light)
        }
        .modelContainer(for: [ScanRecord.self, DailyRoutineChecklist.self])
    }
}
```

- [ ] **Step 5: Verify the project builds**

Run:
```bash
cd ClearMaxxApp && xcodebuild -project ClearMaxx.xcodeproj -scheme ClearMaxx -configuration Debug \
  -destination "generic/platform=iOS Simulator" build 2>&1 | tail -20
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add ClearMaxxApp/ClearMaxx/Models/ResolutionDiff.swift ClearMaxxApp/ClearMaxx/Models/ScanHistory.swift ClearMaxxApp/ClearMaxx/ClearMaxxApp.swift
git commit -m "iOS: add SwiftData scan history + daily checklist models, wire ModelContainer"
```

---

### Task 4: iOS — on-device photo storage

**Files:**
- Create: `ClearMaxxApp/ClearMaxx/Services/ScanPhotoStore.swift`

**Interfaces:**
- Produces: `enum ScanPhotoStore { static func save(_ image: UIImage) throws -> String; static func load(_ fileName: String) -> UIImage? }`.

- [ ] **Step 1: Write the photo store**

Create `ClearMaxxApp/ClearMaxx/Services/ScanPhotoStore.swift`:

```swift
//
//  ScanPhotoStore.swift
//  ClearMaxx — saves/loads each scan's photo as a JPEG in the app's Documents dir.
//

import UIKit

enum ScanPhotoStore {
    private static var directory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("ScanPhotos", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// Saves `image` as a JPEG and returns the filename (not full path) to store on a `ScanRecord`.
    static func save(_ image: UIImage) throws -> String {
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            throw CocoaError(.fileWriteUnknown)
        }
        let fileName = "\(UUID().uuidString).jpg"
        try data.write(to: directory.appendingPathComponent(fileName))
        return fileName
    }

    static func load(_ fileName: String) -> UIImage? {
        UIImage(contentsOfFile: directory.appendingPathComponent(fileName).path)
    }
}
```

- [ ] **Step 2: Verify the project builds**

Run:
```bash
cd ClearMaxxApp && xcodebuild -project ClearMaxx.xcodeproj -scheme ClearMaxx -configuration Debug \
  -destination "generic/platform=iOS Simulator" build 2>&1 | tail -20
```
Expected: `** BUILD SUCCEEDED **`. (This type does real file I/O with `UIImage`, which cannot be exercised outside a running app/simulator — its round-trip behavior is confirmed in Task 10's manual end-to-end pass.)

- [ ] **Step 3: Commit**

```bash
git add ClearMaxxApp/ClearMaxx/Services/ScanPhotoStore.swift
git commit -m "iOS: add on-device JPEG storage for scan photos"
```

---

### Task 5: iOS — wire persistence into AppState, remove mock routine

**Files:**
- Modify: `ClearMaxxApp/ClearMaxx/Models/Models.swift`
- Modify: `ClearMaxxApp/ClearMaxx/Screens/AnalyzingView.swift:8-12,81-97`

**Interfaces:**
- Consumes: `PersistedMetric`/`ResolutionDiff` (Task 3), `ScanRecord`/`DailyRoutineChecklist`/`PersistedRoutineStep` (Task 3), `ScanPhotoStore` (Task 4), `SkinAnalysis.routineSteps: [APIRoutineStep]` (Task 2).
- Produces: `AppState.runAnalysis(_ image: UIImage, modelContext: ModelContext) async`; `AppState.newlyResolved: [PersistedMetric]`; `AppState.celebrationBeforeImage: UIImage?`; `AppState.celebrationScoreDelta: Int`. Removes `AppState.routine(for:)` and `RoutineStep`.

- [ ] **Step 1: Remove the now-unused `RoutineStep` struct (keep `RoutineTime`)**

In `Models.swift`, replace lines 21-33:

```swift
// MARK: - Routine

enum RoutineTime: String, CaseIterable { case am = "AM Routine", pm = "PM Routine" }

struct RoutineStep: Identifiable, Hashable {
    let id = UUID()
    let index: Int
    let category: String
    let title: String
    let detail: String
    let tags: [String]
    var done: Bool = false
}
```

with:

```swift
// MARK: - Routine

enum RoutineTime: String, CaseIterable { case am = "AM Routine", pm = "PM Routine" }
```

- [ ] **Step 2: Add `import SwiftData` and the new published properties**

At the top of `Models.swift`, replace:

```swift
import SwiftUI
import UIKit
```

with:

```swift
import SwiftUI
import UIKit
import SwiftData
```

Then, in `AppState`, replace:

```swift
    // MARK: Live AI analysis (nil until a real scan completes)
    @Published var analysis: SkinAnalysis?
    @Published var isAnalyzing = false
    @Published var analysisError: String?
    @Published var hideTabBar = false
    var pendingImage: UIImage?
```

with:

```swift
    // MARK: Live AI analysis (nil until a real scan completes)
    @Published var analysis: SkinAnalysis?
    @Published var isAnalyzing = false
    @Published var analysisError: String?
    @Published var hideTabBar = false
    var pendingImage: UIImage?

    // MARK: Set right after a successful scan, read by the celebration screen
    @Published var newlyResolved: [PersistedMetric] = []
    @Published var celebrationBeforeImage: UIImage?
    @Published var celebrationScoreDelta: Int = 0
```

- [ ] **Step 3: Replace `runAnalysis`/`resetAnalysis` to persist each scan**

Replace:

```swift
    /// Runs a real scan against the backend. Updates `analysis` / `analysisError`.
    func runAnalysis(_ image: UIImage) async {
        isAnalyzing = true
        analysisError = nil
        do {
            let result = try await SkinAnalysisService.analyze(image: image)
            analysis = result
            clearScore = result.clearScore   // keep Progress/Profile tabs in sync
        } catch {
            analysisError = error.localizedDescription
        }
        isAnalyzing = false
    }

    func resetAnalysis() {
        analysis = nil
        analysisError = nil
        pendingImage = nil
    }
```

with:

```swift
    /// Runs a real scan against the backend. Updates `analysis` / `analysisError`,
    /// and — on success — persists the scan into SwiftData.
    func runAnalysis(_ image: UIImage, modelContext: ModelContext) async {
        isAnalyzing = true
        analysisError = nil
        newlyResolved = []
        do {
            let result = try await SkinAnalysisService.analyze(image: image)
            analysis = result
            clearScore = result.clearScore   // keep Progress/Profile tabs in sync
            persistScan(image: image, result: result, modelContext: modelContext)
        } catch {
            analysisError = error.localizedDescription
        }
        isAnalyzing = false
    }

    private func persistScan(image: UIImage, result: SkinAnalysis, modelContext: ModelContext) {
        guard let photoFileName = try? ScanPhotoStore.save(image) else {
            print("[AppState] Could not save scan photo — skipping history for this scan.")
            return
        }
        let persistedMetrics = result.metrics.map {
            PersistedMetric(name: $0.name, value: $0.value, severity: $0.severity)
        }

        var previousDescriptor = FetchDescriptor<ScanRecord>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        previousDescriptor.fetchLimit = 1
        let previous = try? modelContext.fetch(previousDescriptor).first

        newlyResolved = ResolutionDiff.newlyResolved(current: persistedMetrics, previous: previous?.metrics)
        celebrationBeforeImage = previous.flatMap { ScanPhotoStore.load($0.photoFileName) }
        celebrationScoreDelta = result.clearScore - (previous?.clearScore ?? result.clearScore)

        let record = ScanRecord(date: Date(), clearScore: result.clearScore, confidence: result.confidence,
                                 skinType: result.skinType, summary: result.summary,
                                 metrics: persistedMetrics, photoFileName: photoFileName)
        modelContext.insert(record)

        upsertTodayChecklist(from: result.routineSteps, modelContext: modelContext)

        do {
            try modelContext.save()
        } catch {
            print("[AppState] Could not save scan history: \(error)")
        }
    }

    /// Regenerates today's checklist from the latest scan's AI routine, preserving
    /// `done` state for any step whose title survives from the prior version of
    /// today's checklist (so a mid-day rescan doesn't wipe checked-off items).
    private func upsertTodayChecklist(from apiSteps: [APIRoutineStep], modelContext: ModelContext) {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        var descriptor = FetchDescriptor<DailyRoutineChecklist>(
            predicate: #Predicate { $0.day == startOfDay })
        descriptor.fetchLimit = 1
        let existing = try? modelContext.fetch(descriptor).first
        let doneByTitle = Dictionary(uniqueKeysWithValues: (existing?.steps ?? []).map { ($0.title, $0.done) })

        let newSteps = apiSteps.map { step in
            PersistedRoutineStep(time: step.time, category: step.category, title: step.title,
                                  detail: step.detail, tags: step.tags,
                                  done: doneByTitle[step.title] ?? false)
        }

        if let existing {
            existing.steps = newSteps
        } else {
            modelContext.insert(DailyRoutineChecklist(day: startOfDay, steps: newSteps))
        }
    }

    func resetAnalysis() {
        analysis = nil
        analysisError = nil
        pendingImage = nil
        newlyResolved = []
        celebrationBeforeImage = nil
        celebrationScoreDelta = 0
    }
```

- [ ] **Step 4: Delete the mock `routine(for:)` function**

In `Models.swift`, delete this entire function (it directly follows the `tint(for:)` static function and the mock `metrics` array):

```swift
    func routine(for time: RoutineTime) -> [RoutineStep] {
        switch time {
        case .am:
            return [
                .init(index: 1, category: "Cleanser", title: "Gentle Cloud Foam",
                      detail: "A pH-balanced formula that lifts impurities without stripping your skin's natural barrier.",
                      tags: ["Squalane", "Amino Acids"]),
                .init(index: 2, category: "Vitamin C Serum", title: "Morning Glow Drops",
                      detail: "Potent antioxidant protection to brighten dark spots and shield against pollution.",
                      tags: ["Vitamin C"]),
                .init(index: 3, category: "Moisturizer & SPF", title: "HydraShield SPF 50",
                      detail: "Double-duty hydration with broad-spectrum protection. Lightweight and non-greasy.",
                      tags: ["SPF 50"])
            ]
        case .pm:
            return [
                .init(index: 1, category: "Cleanser", title: "Midnight Melt Balm",
                      detail: "Dissolves sunscreen, makeup and grime so actives absorb cleanly.",
                      tags: ["Squalane"]),
                .init(index: 2, category: "Treatment", title: "Clarifying Night Serum",
                      detail: "Salicylic acid clears congestion while you sleep, reducing breakouts.",
                      tags: ["Salicylic Acid", "Niacinamide"]),
                .init(index: 3, category: "Moisturizer", title: "Barrier Repair Cream",
                      detail: "Ceramide-rich cream locks in hydration and rebuilds the skin barrier overnight.",
                      tags: ["Ceramides", "Hyaluronic Acid"])
            ]
        }
    }
```

Leave `metrics`, `recentDiary`, and `weeklyConsistency` exactly as they are — they're out of scope for this change (kept as the demo-results fallback and the still-decorative weekly-consistency chart respectively).

- [ ] **Step 5: Update `AnalyzingView`'s call site for the new `runAnalysis` signature**

In `AnalyzingView.swift`, replace the property declarations:

```swift
struct AnalyzingView: View {
    @ObserveInjection var inject
    var onDone: () -> Void
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss
```

with:

```swift
struct AnalyzingView: View {
    @ObserveInjection var inject
    var onDone: () -> Void
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
```

Then replace the line `await state.runAnalysis(img)` with:

```swift
                await state.runAnalysis(img, modelContext: modelContext)
```

- [ ] **Step 6: Verify the project builds**

Run:
```bash
cd ClearMaxxApp && xcodebuild -project ClearMaxx.xcodeproj -scheme ClearMaxx -configuration Debug \
  -destination "generic/platform=iOS Simulator" build 2>&1 | tail -30
```
Expected: **`** BUILD FAILED **`, with the only error being in `DailyRoutineView.swift`** (`value of type 'AppState' has no member 'routine'` at its `loadSteps()` call) — this is expected at this checkpoint, since Task 8 hasn't rewired that file yet. Confirm that is the *only* error reported (no errors in `Models.swift`, `AnalyzingView.swift`, or elsewhere), then proceed.

- [ ] **Step 7: Commit**

```bash
git add ClearMaxxApp/ClearMaxx/Models/Models.swift ClearMaxxApp/ClearMaxx/Screens/AnalyzingView.swift
git commit -m "iOS: persist each scan to SwiftData, detect newly-resolved metrics"
```

---

### Task 6: iOS — real photos in the before/after slider + celebration screen

**Files:**
- Modify: `ClearMaxxApp/ClearMaxx/Screens/SkinProgressView.swift:111-148` (the `BeforeAfterSlider` struct only)
- Modify: `ClearMaxxApp/ClearMaxx/Screens/GlowUpShareView.swift`

**Interfaces:**
- Produces: `BeforeAfterSlider(value:beforeImage:afterImage:)` (both image params optional, default `nil`, falling back to the existing gradient placeholders); `GlowUpShareView(beforeImage:afterImage:scoreDelta:resolvedMetricNames:onContinue:)` (all params optional/defaulted so existing no-arg callers still compile).

- [ ] **Step 1: Give `BeforeAfterSlider` optional real-photo support**

In `SkinProgressView.swift`, replace lines 111-148 (the entire `BeforeAfterSlider` struct) with:

```swift
// Draggable before/after comparison
struct BeforeAfterSlider: View {
    @Binding var value: CGFloat
    var beforeImage: UIImage? = nil
    var afterImage: UIImage? = nil

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .leading) {
                beforeLayer
                    .overlay(Text("BEFORE").font(CMFont.inter(10, .bold)).foregroundStyle(.white)
                        .padding(6).background(.black.opacity(0.4), in: Capsule()).padding(10),
                             alignment: .topLeading)
                afterLayer
                    .overlay(Text("AFTER").font(CMFont.inter(10, .bold)).foregroundStyle(.white)
                        .padding(6).background(.black.opacity(0.3), in: Capsule()).padding(10),
                             alignment: .topTrailing)
                    .mask(HStack { Spacer().frame(width: w * value); Rectangle() })
                // handle — only this narrow strip is draggable, so vertical
                // scrolling on the rest of the image passes through to the ScrollView.
                ZStack {
                    Color.clear
                        .frame(width: 60)
                        .frame(maxHeight: .infinity)
                        .contentShape(Rectangle())
                    Circle().fill(.white).frame(width: 36, height: 36)
                        .overlay(Image(systemName: "arrow.left.and.right").foregroundStyle(CMColor.ink))
                        .bloomShadow()
                }
                .offset(x: w * value - 30)
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .named("beforeAfter"))
                        .onChanged { value = max(0, min(1, $0.location.x / w)) }
                )
            }
            .coordinateSpace(name: "beforeAfter")
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .frame(height: 260)
    }

    @ViewBuilder private var beforeLayer: some View {
        if let beforeImage {
            Image(uiImage: beforeImage).resizable().scaledToFill()
        } else {
            LinearGradient(colors: [Color(hex: "C98F6A"), Color(hex: "9A6A4A")], startPoint: .top, endPoint: .bottom)
        }
    }

    @ViewBuilder private var afterLayer: some View {
        if let afterImage {
            Image(uiImage: afterImage).resizable().scaledToFill()
        } else {
            CMGradient.auraDiagonal
        }
    }
}
```

- [ ] **Step 2: Rework `GlowUpShareView` to take real data and a working save action**

Replace the entire contents of `GlowUpShareView.swift` with:

```swift
//
//  GlowUpShareView.swift
//  ClearMaxx — before/after celebration + share card, fed real scan data.
//

import SwiftUI

struct GlowUpShareView: View {
    @ObserveInjection var inject
    @Environment(\.dismiss) private var dismiss
    @State private var slider: CGFloat = 0.5
    @State private var saveConfirmation = false

    var beforeImage: UIImage? = nil
    var afterImage: UIImage? = nil
    var scoreDelta: Int = 0
    var resolvedMetricNames: [String] = []
    /// Non-nil when shown as a post-scan celebration (adds a "Continue" button);
    /// nil when shown as the plain "Share My Glow-Up" sheet from Progress.
    var onContinue: (() -> Void)? = nil

    var body: some View {
        DewyBackground {
            VStack(spacing: 20) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left").font(.system(size: 18, weight: .semibold)).foregroundStyle(CMColor.ink)
                    }
                    Spacer(); ClearMaxxWordmark(size: 22); Spacer()
                    Image(systemName: "chevron.left").opacity(0)
                }
                .padding(.horizontal, 24).padding(.top, 12)

                if !resolvedMetricNames.isEmpty {
                    Text("\(resolvedMetricNames.joined(separator: " & ")) Cleared! 🎉")
                        .font(CMFont.headlineMd).foregroundStyle(CMColor.ink)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                // Share card
                VStack(spacing: 0) {
                    BeforeAfterSlider(value: $slider, beforeImage: beforeImage, afterImage: afterImage)
                        .frame(height: 300)
                        .overlay(alignment: .bottom) {
                            VStack(spacing: 2) {
                                Text(scoreDeltaText).font(CMFont.inter(26, .heavy)).foregroundStyle(.white)
                                Text("ClearScore change").font(CMFont.labelMd).foregroundStyle(.white.opacity(0.9))
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(CMGradient.aura.opacity(0.92))
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                    HStack {
                        ClearMaxxWordmark(size: 16)
                        Text("AI Dermatology Analysis").font(CMFont.labelSm).foregroundStyle(CMColor.inkSoft)
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.seal.fill").foregroundStyle(CMColor.violet)
                            Text("Verified Result").font(CMFont.labelSm).foregroundStyle(CMColor.violetDeep)
                        }
                    }
                    .padding(14)
                    .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .padding(.top, 10)
                }
                .padding(.horizontal, 24)

                Text("Flex your glow").font(CMFont.headlineMd).foregroundStyle(CMColor.ink)

                HStack(spacing: 14) {
                    shareButton("TikTok", "music.note", .black)
                    shareButton("Instagram", "camera.fill", nil)
                }
                .padding(.horizontal, 24)

                AuraButton(title: saveConfirmation ? "Saved!" : "Save to Photos",
                           systemImage: saveConfirmation ? "checkmark" : "square.and.arrow.down") {
                    saveToPhotos()
                }
                .padding(.horizontal, 24)

                if let onContinue {
                    Button("Continue", action: onContinue)
                        .font(CMFont.labelMd).foregroundStyle(CMColor.violetDeep)
                }

                Spacer()
            }
        }
        .presentationDragIndicator(.visible)
    }

    private var scoreDeltaText: String {
        scoreDelta >= 0 ? "+\(scoreDelta) ClearScore" : "\(scoreDelta) ClearScore"
    }

    private func saveToPhotos() {
        guard let afterImage else { return }
        UIImageWriteToSavedPhotosAlbum(afterImage, nil, nil, nil)
        saveConfirmation = true
    }

    private func shareButton(_ label: String, _ icon: String, _ bg: Color?) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon); Text(label).font(CMFont.labelMd)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity).padding(.vertical, 16)
        .background(bg != nil ? AnyShapeStyle(bg!) : AnyShapeStyle(CMGradient.aura),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#Preview { GlowUpShareView() }
```

Note: `NSPhotoLibraryAddUsageDescription` must already be present in the app's Info settings for `UIImageWriteToSavedPhotosAlbum` to work without crashing — if the build/manual test in Task 10 shows a missing-usage-description crash on save, add that key with a short description (e.g. "Save your glow-up photos to your library.") via the target's Info tab before re-testing; do not skip this if it comes up.

- [ ] **Step 3: Verify the project builds**

Run:
```bash
cd ClearMaxxApp && xcodebuild -project ClearMaxx.xcodeproj -scheme ClearMaxx -configuration Debug \
  -destination "generic/platform=iOS Simulator" build 2>&1 | tail -30
```
Expected: same as Task 5's Step 6 — **`** BUILD FAILED **` with the sole error still being `DailyRoutineView.swift`'s reference to the deleted `state.routine(for:)`**, unchanged and not worsened by this task's edits. Confirm no *new* errors were introduced, then proceed.

- [ ] **Step 4: Commit**

```bash
git add ClearMaxxApp/ClearMaxx/Screens/SkinProgressView.swift ClearMaxxApp/ClearMaxx/Screens/GlowUpShareView.swift
git commit -m "iOS: real before/after photos in BeforeAfterSlider, real data + save action in GlowUpShareView"
```

---

### Task 7: iOS — route to the celebration screen on a resolved metric

**Files:**
- Modify: `ClearMaxxApp/ClearMaxx/Screens/CameraScanView.swift:13,26-37`

**Interfaces:**
- Consumes: `AppState.newlyResolved`, `celebrationBeforeImage`, `celebrationScoreDelta` (Task 5); `GlowUpShareView(beforeImage:afterImage:scoreDelta:resolvedMetricNames:onContinue:)` (Task 6).
- Produces: `ScanRoute.celebration` case.

- [ ] **Step 1: Add the `celebration` route and branch to it when a metric just resolved**

In `CameraScanView.swift`, replace line 13:

```swift
enum ScanRoute: Hashable { case analyzing, results, issue(SkinMetric) }
```

with:

```swift
enum ScanRoute: Hashable { case analyzing, results, issue(SkinMetric), celebration }
```

Then replace the `navigationDestination` switch (lines 26-37):

```swift
            .navigationDestination(for: ScanRoute.self) { route in
                switch route {
                case .analyzing:
                    AnalyzingView { path.append(ScanRoute.results) }
                case .results:
                    ResultsDashboardView(
                        onIssue: { path.append(ScanRoute.issue($0)) },
                        onRescan: { state.resetAnalysis(); path = NavigationPath() })
                case .issue(let metric):
                    IssueDetailView(metric: metric)
                }
            }
```

with:

```swift
            .navigationDestination(for: ScanRoute.self) { route in
                switch route {
                case .analyzing:
                    AnalyzingView {
                        if state.newlyResolved.isEmpty {
                            path.append(ScanRoute.results)
                        } else {
                            path.append(ScanRoute.celebration)
                        }
                    }
                case .celebration:
                    GlowUpShareView(
                        beforeImage: state.celebrationBeforeImage,
                        afterImage: state.pendingImage,
                        scoreDelta: state.celebrationScoreDelta,
                        resolvedMetricNames: state.newlyResolved.map(\.name),
                        onContinue: { path.append(ScanRoute.results) })
                case .results:
                    ResultsDashboardView(
                        onIssue: { path.append(ScanRoute.issue($0)) },
                        onRescan: { state.resetAnalysis(); path = NavigationPath() })
                case .issue(let metric):
                    IssueDetailView(metric: metric)
                }
            }
```

- [ ] **Step 2: Verify the project builds**

Run:
```bash
cd ClearMaxxApp && xcodebuild -project ClearMaxx.xcodeproj -scheme ClearMaxx -configuration Debug \
  -destination "generic/platform=iOS Simulator" build 2>&1 | tail -30
```
Expected: same as Tasks 5-6 — **`** BUILD FAILED **` with the sole error still being `DailyRoutineView.swift`'s reference to the deleted `state.routine(for:)`**, unchanged and not worsened by this task's edits. Confirm no *new* errors were introduced, then proceed.

- [ ] **Step 3: Commit**

```bash
git add ClearMaxxApp/ClearMaxx/Screens/CameraScanView.swift
git commit -m "iOS: route to a celebration screen when a scan resolves a metric"
```

---

### Task 8: iOS — Routine tab reads the real daily checklist

**Files:**
- Modify: `ClearMaxxApp/ClearMaxx/Screens/DailyRoutineView.swift` (entire file)

**Interfaces:**
- Consumes: `DailyRoutineChecklist`, `PersistedRoutineStep` (Task 3).
- Produces: no new symbols consumed elsewhere; this is the leaf view for the Routine tab.

- [ ] **Step 1: Replace the mock-driven view with one backed by `@Query`**

Replace the entire contents of `DailyRoutineView.swift` with:

```swift
//
//  DailyRoutineView.swift
//  ClearMaxx — Routine tab. AM/PM toggle over today's AI-generated checklist.
//

import SwiftUI
import SwiftData

struct DailyRoutineView: View {
    @ObserveInjection var inject
    @EnvironmentObject var state: AppState
    @State private var time: RoutineTime = .am
    @Query private var checklists: [DailyRoutineChecklist]

    init() {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        _checklists = Query(filter: #Predicate<DailyRoutineChecklist> { $0.day == startOfDay })
    }

    private var todaySteps: [PersistedRoutineStep] { checklists.first?.steps ?? [] }

    private var filteredSteps: [(offset: Int, step: PersistedRoutineStep)] {
        let wanted = time == .am ? "AM" : "PM"
        return Array(todaySteps.enumerated()).filter { $0.element.time == wanted }
    }

    var body: some View {
        DewyBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Daily Ritual").font(CMFont.headlineLg).foregroundStyle(CMColor.ink)
                        Text("Consistency is the key to that healthy glow.")
                            .font(CMFont.bodyMd).foregroundStyle(CMColor.inkSoft)
                    }

                    // AM/PM segmented toggle
                    HStack(spacing: 0) {
                        ForEach(RoutineTime.allCases, id: \.self) { t in
                            Button { withAnimation { time = t } } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: t == .am ? "sun.max.fill" : "moon.fill")
                                    Text(t.rawValue)
                                }
                                .font(CMFont.labelMd)
                                .foregroundStyle(time == t ? CMColor.violetDeep : CMColor.inkSoft)
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(time == t ? AnyShapeStyle(Color.white) : AnyShapeStyle(Color.clear),
                                            in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(4)
                    .background(CMColor.cardSoft, in: Capsule())

                    if todaySteps.isEmpty {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("No routine yet").font(CMFont.title).foregroundStyle(CMColor.ink)
                                Text("Scan your face to get today's AI-recommended routine.")
                                    .font(CMFont.bodyMd).foregroundStyle(CMColor.inkSoft)
                            }
                        }
                    } else {
                        ForEach(filteredSteps, id: \.step.title) { entry in
                            RoutineStepCard(index: entry.offset + 1, step: entry.step) {
                                toggleDone(at: entry.offset)
                            }
                        }
                    }

                    // Weekly consistency — still illustrative, out of scope for this pass.
                    GlassCard {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("Weekly Consistency").font(CMFont.title).foregroundStyle(CMColor.ink)
                                Spacer()
                                Text("85%").font(CMFont.title).foregroundStyle(CMColor.violetDeep)
                            }
                            HStack(alignment: .bottom, spacing: 10) {
                                ForEach(Array(state.weeklyConsistency.enumerated()), id: \.offset) { i, v in
                                    VStack(spacing: 6) {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(v > 0.5 ? AnyShapeStyle(CMGradient.aura) : AnyShapeStyle(CMColor.cardSoft))
                                            .frame(height: 90 * v)
                                        Text(["M","T","W","T","F","S","S"][i])
                                            .font(CMFont.labelSm).foregroundStyle(CMColor.inkSoft)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            }
                            .frame(height: 110, alignment: .bottom)
                        }
                    }
                    .padding(.bottom, 100)
                }
                .padding(.horizontal, 24).padding(.top, 8)
            }
        }
    }

    private func toggleDone(at index: Int) {
        guard let checklist = checklists.first else { return }
        checklist.steps[index].done.toggle()
    }
}

private struct RoutineStepCard: View {
    let index: Int
    let step: PersistedRoutineStep
    let onToggle: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle().stroke(CMColor.violet.opacity(0.3), lineWidth: 1.5).frame(width: 40, height: 40)
                Text(String(format: "%02d", index))
                    .font(CMFont.labelMd).foregroundStyle(CMColor.violetDeep)
            }
            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        CategoryLabel(text: step.category, color: CMColor.coralDeep)
                        Spacer()
                        Button(action: onToggle) {
                            Image(systemName: step.done ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 22))
                                .foregroundStyle(step.done ? CMColor.success : CMColor.outline.opacity(0.6))
                        }.buttonStyle(.plain)
                    }
                    Text(step.title).font(CMFont.title).foregroundStyle(CMColor.ink)
                    Text(step.detail).font(CMFont.bodyMd).foregroundStyle(CMColor.inkSoft)
                    HStack {
                        ForEach(step.tags, id: \.self) { TagChip(text: $0) }
                    }
                }
            }
        }
    }
}

#Preview {
    DailyRoutineView()
        .environmentObject(AppState())
        .modelContainer(for: [ScanRecord.self, DailyRoutineChecklist.self], inMemory: true)
}
```

- [ ] **Step 2: Verify the project builds**

Run:
```bash
cd ClearMaxxApp && xcodebuild -project ClearMaxx.xcodeproj -scheme ClearMaxx -configuration Debug \
  -destination "generic/platform=iOS Simulator" build 2>&1 | tail -30
```
Expected: `** BUILD SUCCEEDED **` — this should now be a clean build with no remaining caveats from Tasks 5-7.

- [ ] **Step 3: Commit**

```bash
git add ClearMaxxApp/ClearMaxx/Screens/DailyRoutineView.swift
git commit -m "iOS: Routine tab reads today's real AI-generated checklist from SwiftData"
```

---

### Task 9: iOS — Progress tab reads real scan history

**Files:**
- Modify: `ClearMaxxApp/ClearMaxx/Screens/SkinProgressView.swift:1-108` (everything above the `BeforeAfterSlider` struct, which Task 6 already updated)

**Interfaces:**
- Consumes: `ScanRecord`, `PersistedMetric` (Task 3), `ScanPhotoStore` (Task 4), `BeforeAfterSlider(value:beforeImage:afterImage:)` and `GlowUpShareView(...)` (Task 6).
- Produces: no new symbols consumed elsewhere; leaf view for the Progress tab.

- [ ] **Step 1: Replace the `SkinProgressView` struct with a real-data-driven version**

In `SkinProgressView.swift`, replace lines 1-108 (everything from the file header through the end of the `SkinProgressView` struct, i.e. everything above `// Draggable before/after comparison`) with:

```swift
//
//  SkinProgressView.swift
//  ClearMaxx — Progress tab. Real scan history: before/after, ClearScore trend, per-metric deltas.
//

import SwiftUI
import SwiftData

struct SkinProgressView: View {
    @ObserveInjection var inject
    @EnvironmentObject var state: AppState
    @Query(sort: \ScanRecord.date) private var scanRecords: [ScanRecord]
    @State private var slider: CGFloat = 0.5
    @State private var showShare = false

    private var first: ScanRecord? { scanRecords.first }
    private var latest: ScanRecord? { scanRecords.last }
    private var previous: ScanRecord? { scanRecords.count >= 2 ? scanRecords[scanRecords.count - 2] : nil }

    var body: some View {
        DewyBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Your Journey").font(CMFont.labelMd).foregroundStyle(CMColor.inkSoft)
                            Text("Skin Evolution").font(CMFont.headlineLg).foregroundStyle(CMColor.ink)
                        }
                        Spacer()
                        HStack(spacing: 6) {
                            Image(systemName: "flame.fill")
                            Text("\(state.scanStreak) Day Streak!").font(CMFont.labelMd)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(CMGradient.aura, in: Capsule())
                    }

                    if scanRecords.isEmpty {
                        emptyState(title: "No scans yet",
                                   body: "Scan your face to start tracking your skin's progress.")
                    } else {
                        BeforeAfterSlider(value: $slider,
                                          beforeImage: first.flatMap { ScanPhotoStore.load($0.photoFileName) },
                                          afterImage: latest.flatMap { ScanPhotoStore.load($0.photoFileName) })

                        clearScoreTrendCard

                        if scanRecords.count < 2 {
                            emptyState(title: "Scan again to see your trend",
                                       body: "One more scan will start showing how each metric is changing.")
                        } else {
                            metricDeltaCard
                        }

                        AuraButton(title: "Share My Glow-Up", systemImage: "square.and.arrow.up") { showShare = true }
                            .padding(.bottom, 100)
                    }
                }
                .padding(.horizontal, 24).padding(.top, 8)
            }
        }
        .sheet(isPresented: $showShare) {
            GlowUpShareView(
                beforeImage: first.flatMap { ScanPhotoStore.load($0.photoFileName) },
                afterImage: latest.flatMap { ScanPhotoStore.load($0.photoFileName) },
                scoreDelta: (latest?.clearScore ?? 0) - (first?.clearScore ?? 0))
        }
    }

    private var clearScoreTrendCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading) {
                        Text("ClearScore").font(CMFont.title).foregroundStyle(CMColor.ink)
                        if let first, let latest {
                            let delta = latest.clearScore - first.clearScore
                            Text(delta >= 0 ? "+\(delta) since your first scan" : "\(delta) since your first scan")
                                .font(CMFont.labelSm).foregroundStyle(delta >= 0 ? CMColor.success : CMColor.error)
                        }
                    }
                    Spacer()
                    Text("\(latest?.clearScore ?? state.clearScore)")
                        .font(CMFont.inter(40, .heavy)).foregroundStyle(CMColor.coralDeep)
                }
                HStack(alignment: .bottom, spacing: 6) {
                    let recent = Array(scanRecords.suffix(8))
                    ForEach(Array(recent.enumerated()), id: \.offset) { i, record in
                        RoundedRectangle(cornerRadius: 5)
                            .fill(i == recent.count - 1
                                  ? AnyShapeStyle(CMGradient.aura) : AnyShapeStyle(CMColor.outline.opacity(0.35)))
                            .frame(height: max(8, CGFloat(record.clearScore) * 0.9))
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 100, alignment: .bottom)
                HStack {
                    Text(first?.date.formatted(date: .abbreviated, time: .omitted) ?? "")
                        .font(CMFont.inter(9, .semibold)).foregroundStyle(CMColor.inkSoft)
                    Spacer()
                    Text("TODAY").font(CMFont.inter(9, .semibold)).foregroundStyle(CMColor.inkSoft)
                }
            }
        }
    }

    private var metricDeltaCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Metric Progress").font(CMFont.headlineMd).foregroundStyle(CMColor.ink)
                ForEach(latest?.metrics ?? [], id: \.name) { metric in
                    metricRow(metric)
                }
            }
        }
    }

    private func metricRow(_ metric: PersistedMetric) -> some View {
        let prevMetric = previous?.metrics.first(where: { $0.name == metric.name })
        let justResolved = metric.severity == "Good" && prevMetric?.severity != "Good"
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: justResolved ? "checkmark.seal.fill" : "chart.line.uptrend.xyaxis")
                .foregroundStyle(justResolved ? CMColor.success : CMColor.violet)
                .font(.system(size: 18))
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(metric.name).font(CMFont.labelMd).foregroundStyle(CMColor.ink)
                    if justResolved {
                        Text("Cleared 🎉").font(CMFont.labelSm).foregroundStyle(CMColor.success)
                    }
                }
                if let prevValue = prevMetric?.value {
                    let delta = metric.value - prevValue
                    Text("\(prevValue) → \(metric.value) (\(delta >= 0 ? "+" : "")\(delta)) since last scan")
                        .font(CMFont.bodyMd).foregroundStyle(CMColor.inkSoft)
                } else {
                    Text("Value: \(metric.value)").font(CMFont.bodyMd).foregroundStyle(CMColor.inkSoft)
                }
            }
        }
    }

    private func emptyState(title: String, body: String) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(CMFont.title).foregroundStyle(CMColor.ink)
                Text(body).font(CMFont.bodyMd).foregroundStyle(CMColor.inkSoft)
            }
        }
    }
}
```

Leave everything from `// Draggable before/after comparison` onward (the `BeforeAfterSlider` struct Task 6 already rewrote, and its `#Preview`) untouched. Update that trailing preview to supply a model container:

```swift
#Preview {
    SkinProgressView()
        .environmentObject(AppState())
        .modelContainer(for: [ScanRecord.self, DailyRoutineChecklist.self], inMemory: true)
}
```

- [ ] **Step 2: Verify the project builds**

Run:
```bash
cd ClearMaxxApp && xcodebuild -project ClearMaxx.xcodeproj -scheme ClearMaxx -configuration Debug \
  -destination "generic/platform=iOS Simulator" build 2>&1 | tail -30
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add ClearMaxxApp/ClearMaxx/Screens/SkinProgressView.swift
git commit -m "iOS: Progress tab reads real scan history — trend, before/after, per-metric deltas"
```

---

### Task 10: Deploy backend + full manual end-to-end verification

**Files:** None (deployment + manual verification only).

**Interfaces:** None — this task validates the whole chain built in Tasks 1-9.

- [ ] **Step 1: Deploy the updated backend**

```bash
cd backend && gcloud app deploy app.yaml --project faraz-mobile-apps
```
Expected: deploy succeeds; note the promoted version URL matches the existing `https://clearmaxx-dot-faraz-mobile-apps.uc.r.appspot.com`.

- [ ] **Step 2: Confirm the backend is healthy**

```bash
curl -s https://clearmaxx-dot-faraz-mobile-apps.uc.r.appspot.com/health
```
Expected: `{"status": "ok", "vertex_configured": true, "auth_required": true}`.

- [ ] **Step 3: Rebuild and launch the iOS app on the simulator**

```bash
./reload.sh --shot
```
Expected: build succeeds, app launches, screenshot saved to `/tmp/clearmaxx-shot.png` showing the app running (not a crash screen).

- [ ] **Step 4: Perform the first scan and verify the routine tab**

In the simulator: go to the Scan tab, capture/select a clear face photo, wait for analysis to complete, land on Results. Then open the Routine tab.

Expected: Routine tab shows real AI-generated steps (not "Gentle Cloud Foam"/"Midnight Melt Balm" placeholder copy), split correctly across AM/PM. Toggle one step's checkbox on.

- [ ] **Step 5: Perform a second scan a few minutes later and verify persistence + Progress tab**

Capture/select a different (or the same) face photo again. After analysis completes, open the Progress tab.

Expected:
- Before/after slider shows two distinct real photos (not gradients).
- ClearScore trend shows two real bars/values, not the old hardcoded staircase.
- "Metric Progress" card shows real per-metric delta lines (e.g. `"62 → 41 (-21) since last scan"`) for all 8 metrics.
- Returning to the Routine tab, the step checked off in Step 4 is still checked (if its title is unchanged in the new routine) — confirms same-day `done`-state persistence across a rescan.

- [ ] **Step 6: Verify the resolved-metric celebration path**

Using two face photos chosen (or edited) so that at least one metric's severity plausibly shifts into `"Good"` on the second scan, repeat a scan and confirm: right after analysis, the app shows the celebration screen (resolved metric name(s), real before/after photos, real ClearScore delta) before the normal Results screen. Tap "Continue" and confirm it proceeds to Results as expected. Tap "Save to Photos" and confirm no crash (check Photos app for the saved image, or console log if using an `NSPhotoLibraryAddUsageDescription` gap flagged in Task 6).

- [ ] **Step 7: Confirm no regressions in the untouched flows**

Spot-check: Scan tab capture flow still works end-to-end (unchanged from before this plan); Diary and Profile tabs still render (untouched, expected to remain as-is); "Use demo results" path in `AnalyzingView`'s error card still works if you can trigger a scan failure (e.g. airplane mode) — confirms the mock `metrics` fallback in `AppState` was correctly left in place.

- [ ] **Step 8: Final commit (only if any fixes were needed during verification)**

If any of the above steps required a code fix, stage and commit it with a message describing what was wrong and fixed. If everything passed as implemented, no commit is needed for this task.
