# AI Routine + Real Progress Tracking — Design Spec

Date: 2026-07-06
Status: Approved for planning

## Problem

ClearMaxx's core loop is meant to be: **scan → AI finds the issue → AI prescribes a fix → progress is tracked → issue resolved.** Today, the scan/diagnose half works (Vertex AI Gemini backend returns a ClearScore + 8 metrics with severity, ingredients, tips). But the loop breaks after diagnosis:

- The backend already returns `routineSuggestions` (a flat array of strings) per scan, but the Routine tab (`DailyRoutineView`) ignores it entirely and shows hardcoded AM/PM steps instead. The AI never actually gets to prescribe anything the user sees.
- The Progress tab (`SkinProgressView`) is 100% fake — hardcoded trend chart, hardcoded before/after gradients, hardcoded insight copy. There is no persistence anywhere in the app (no Core Data/SwiftData/UserDefaults) — every scan result is discarded the moment you leave the screen.

This spec covers closing both gaps so the full loop is real: diagnose → prescribe → track → celebrate resolution.

## Goals

- Wire the AI's routine recommendations into a real, structured daily routine checklist.
- Persist every scan (score, per-metric severity, photo) locally on-device.
- Make the Progress tab show real trends, a real before/after photo slider, and per-metric deltas since the last scan.
- Detect when a metric resolves (improves into the "Good" severity tier) and give the user a real celebratory moment.
- Track all 8 metrics in parallel (no single "primary issue" concept) — every metric gets equal tracking and can independently resolve.

## Non-goals

- No AI-generated natural-language comparison text (e.g. an LLM call to phrase "you improved") — deltas are computed locally and shown via a template. Avoids extra latency/cost/backend surface area per the "single focused app" directive.
- No social share deep-linking (TikTok/Instagram) — `GlowUpShareView`'s share buttons stay stubbed; only "Save to Photos" becomes real in this pass.
- No cloud sync/backup of scan history — SwiftData is local-only, matching the app's current no-accounts model.
- No changes to the Diary tab, Quiz, Premium/paywall, or the camera capture flow (covered by a separate design).

## Architecture

### 1. Backend routine schema change (`backend/main.py`)

`ANALYSIS_PROMPT`'s `routineSuggestions: [string]` key is replaced with `routineSteps`, an array of structured objects:

```json
"routineSteps": [
  {
    "time": "AM" | "PM",
    "category": "Cleanser | Treatment | Moisturizer | Sunscreen | ...",
    "title": "short product/step name, max ~40 chars",
    "detail": "one sentence on why/how, max ~140 chars",
    "tags": ["0-3 short tags, e.g. Fragrance-free"]
  }
]
```

4-8 steps total, a mix of AM and PM, tailored to the metrics just diagnosed.

`_normalize()` gains a matching branch: coerce each item's `time` to `"AM"`/`"PM"` (default `"AM"` if invalid/missing), clamp `category`/`title`/`detail` to string + length limits, cap `tags` at 3 items, cap total steps at 8.

This is a breaking API contract change. Since both the backend and iOS client are controlled by the same team with no external consumers, they ship together — no versioning/back-compat shim needed.

### 2. iOS Codable contract (`SkinAnalysisService.swift`)

`SkinAnalysis.routineSuggestions: [String]` → `SkinAnalysis.routineSteps: [APIRoutineStep]`:

```swift
struct APIRoutineStep: Codable {
    let time: String       // "AM" / "PM"
    let category: String
    let title: String
    let detail: String
    let tags: [String]
}
```

### 3. SwiftData persistence (new, iOS 17+ deployment target already supports this)

```swift
@Model
class ScanRecord {
    var date: Date
    var clearScore: Int
    var confidence: Int
    var skinType: String
    var summary: String
    var metrics: [PersistedMetric]
    var photoFileName: String   // JPEG stored in Documents/ScanPhotos/, not inline in the DB
}

struct PersistedMetric: Codable {
    let name: String
    let value: Int
    let severity: String   // "Good"/"Mild"/"Moderate"/"Severe", reused verbatim from backend
}

@Model
class DailyRoutineChecklist {
    var day: Date               // truncated to start-of-day; one record per day
    var steps: [PersistedRoutineStep]
}

struct PersistedRoutineStep: Codable {
    var time: String
    var category: String
    var title: String
    var detail: String
    var tags: [String]
    var done: Bool
}
```

`AppState.runAnalysis()` gains, after a successful analysis:
1. Save the captured photo as a JPEG in `Documents/ScanPhotos/`.
2. Insert a new `ScanRecord`.
3. Upsert today's `DailyRoutineChecklist` from `analysis.routineSteps` — steps whose `title` matches an existing entry for today keep their `done` flag; new/changed steps are added fresh. This prevents a mid-day rescan from wiping already-checked-off items.
4. Diff the new metrics against the most recent prior `ScanRecord` (see Resolution detection below) and populate `AppState.newlyResolved`.

No data migration path is needed — there is no pre-existing persisted scan history to migrate from.

### 4. Routine tab rewire (`DailyRoutineView.swift`)

Reads today's `DailyRoutineChecklist` from SwiftData instead of `state.routine(for: time)`. The existing AM/PM toggle UI and `RoutineStepCard` component are unchanged — only the data source changes, constructing the existing `RoutineStep` render struct from `PersistedRoutineStep`. Checking a step off writes `done = true` back to SwiftData immediately.

If no scan has happened today (or ever), show an empty state ("Scan your face to get today's routine") instead of falling back to mock data.

`AppState.routine(for:)` and its hardcoded mock arrays are deleted.

### 5. Progress tab rewire (`SkinProgressView.swift`)

Reads all `ScanRecord`s from SwiftData, sorted by date:

- **ClearScore trend**: real chart from `scanRecords.map(\.clearScore)` over `date`.
- **Before/after slider**: first `ScanRecord`'s photo vs. latest `ScanRecord`'s photo, loaded from `Documents/ScanPhotos/`.
- **Per-metric rows** (all 8 metrics, no single "primary" issue): latest value, delta vs. previous scan, templated line (e.g. "Acne: 62 → 41 (−21) since last scan"), and a "Cleared 🎉" badge when severity has just transitioned into `"Good"` from a worse tier vs. any prior scan.
- With only one scan on record, trend/delta sections show "Scan again to see your trend" instead of fabricated data.

### 6. Resolution detection & celebration

On each successful analysis, for each metric: if `severity == "Good"` now but was not `"Good"` on the immediately preceding scan, add it to `AppState.newlyResolved`.

Navigation: after `AnalyzingView` finishes, if `newlyResolved` is non-empty, push a celebration screen (repurposed `GlowUpShareView`) showing the before photo (first scan where that metric wasn't `"Good"`) vs. the after photo (latest), the resolved metric name(s), and the real ClearScore delta — before landing on the normal `ResultsDashboardView`. If nothing newly resolved, skip straight to results, unchanged from today's flow.

`GlowUpShareView`'s hardcoded "+18 ClearScore" text is replaced with the real delta. Its "Save to Photos" button becomes a real, working action. TikTok/Instagram share buttons remain stubbed (non-goal, see above).

### 7. Error handling & edge cases

- SwiftData save failures (e.g. disk full) are logged but non-fatal — the in-memory `analysis` result still displays normally for that session; persistence for that scan is just skipped. No user-facing error surfaced for this.
- Uninstalling/reinstalling the app naturally wipes SwiftData + the Documents photo files together — no orphaned file references possible.
- First-ever scan: no prior scan to diff against, so no deltas or celebration fire — it only establishes the baseline.

### 8. Testing approach

- Backend: unit tests for `_normalize()`'s new `routineSteps` handling — malformed/missing `time`, oversized arrays, missing keys, non-string fields.
- iOS: unit tests for the "newly resolved" diff logic in `AppState` across various severity sequences (e.g. Severe→Moderate→Good, Good→Good, Mild→Good).
- Manual verification: run the full loop twice in the simulator using two different demo images a few minutes apart, to confirm real trend data appears, the daily checklist persists `done` state correctly across a rescan, and — using an image pair chosen to shift severity into "Good" — confirm the celebration screen fires correctly.

## Decisions log

- **All 8 metrics tracked in parallel**, not a single user-chosen "focus issue" — simpler mental model, matches how the backend already scores every metric on every scan.
- **Photos are persisted** alongside scores, enabling a real before/after slider — accepted trade-off of increased local storage over time.
- **Local/templated progress narration**, not a second AI-generated comparison endpoint — keeps the app to one core AI call (the scan itself), avoiding added latency, cost, and backend surface area.
- **Full celebration screen** (not just a badge) on metric resolution, reusing the existing `GlowUpShareView` rather than building a new screen from scratch.
- **Daily routine checklist persists and carries `done` state across same-day rescans**, matched by step title.
