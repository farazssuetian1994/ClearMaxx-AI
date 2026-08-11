# Progress Analysis (History-Aware Skin Trend Report)

Status: approved (design), not yet planned/implemented
Date: 2026-08-12

## Objective

Let a user tap "Analyze My Progress" and get an AI read of whether their skin
is actually improving over time — using their existing scan history, not a
new scan — plus a routine that adapts to what's working. This replaces the
current "scan and get a one-off score" loop, which never looks backward and
never changes course.

Explicitly out of scope for this spec (deferred, see "Deferred" below):
daily-forced scanning changes, the Diary tab, routine-adherence signals.

## User-facing flow

1. Progress tab gets an **"Analyze My Progress"** button.
2. Gated to premium users (`PurchaseService.isPremium`), unlimited taps.
3. Enabled only when the user has **≥2 scans spanning ≥7 days**. Below that,
   an honest empty state explains why ("skin needs a few weeks to show
   change"), not a generic disabled button.
4. On tap: if a cached report already exists for the current latest scan,
   show it instantly with **no network call**. Otherwise call the backend,
   show a loading state, then the report.
5. Report shows: overall verdict, a short narrative, which metrics are
   working / stalled / to watch, and an **"Update my routine"** action that
   replaces today's AM/PM checklist with the adapted steps returned in the
   same response.

## Data flow

```
SkinProgressView → "Analyze My Progress" (premium, ≥2 scans, ≥7 days)
      ↓
Check ProgressReport cache keyed to latest ScanRecord.id
      ↓ (cache miss)
ProgressTrend.compute(scans)        ← pure Swift, no network, no AI
      ↓ overall 62→74 (+12)
      ↓ acne 55→31 (−24, BETTER)     ← polarity-aware
      ↓ hydration 40→52 (+12, BETTER) ← inverted metric handled correctly
      ↓ darkSpots 48→47 (−1, FLAT)   ← within noise threshold
      ↓ span: 71 days, 4 scans; sampled to ≤8 points
      ↓
ScanPhotoStore.downscaled(first), .downscaled(latest)   ← ≤768px long edge
      ↓
POST /api/skin/progress   (X-App-Token)
   { photos: [first, latest], trends: <computed facts>,
     currentRoutine: [...], spanDays: 71, scanCount: 4 }
      ↓
Gemini: judges photos + adapts routine. Told trends are given facts —
never recomputes deltas itself.
      ↓
ProgressReport { verdict, headline, narrative,
                 working[], stalled[], watch[], updatedRoutine[] }
      ↓
Cache report (keyed to latest scan ID) → ProgressReportView
      ↓ "Update my routine"
DailyRoutineChecklist (today) replaced with updatedRoutine
```

## Why trends are computed in Swift, not by the model

Language models are unreliable at exact arithmetic across many data points.
If Gemini computed deltas itself, it could occasionally report "improving"
when a metric actually worsened — a trust-killing bug in a feature whose
entire premise is "tell me the truth about my progress." `ProgressTrend`
computes every delta deterministically in Swift; Gemini receives them as
stated facts and is only asked to judge photos, explain the "why," and adapt
the routine — jobs only it can do.

## Metric polarity and noise threshold

Metrics have mixed direction: for Acne/Pores/Redness/Wrinkles/Oiliness/Dark
Spots/Dark Circles a *lower* score is better; for Hydration a *higher* score
is better (see `METRICS` / prompt in `backend/main.py`). `ProgressTrend`
encodes polarity per metric and reports direction as `.better` / `.worse` /
`.flat` — never a raw signed number a UI or user could misread.

A change within **±3 points** is reported as `.flat` regardless of polarity.
Without this, ordinary scoring noise reads as constant "progress," and the
feature becomes untrustworthy horoscope-style flattery.

## API cost controls

This feature is unlimited-tap for premium users, so controlling actual API
calls (not taps) is required:

1. **Report caching.** `ProgressReport` is cached in SwiftData keyed to the
   ID of the latest `ScanRecord` it was built from. Re-opening the report
   with no new scan since is a cache hit — zero network calls. A fresh call
   only happens when a new scan exists since the last cached report.
2. **Image downscaling.** Both photos sent are downscaled to a 768px long
   edge before upload (`ScanPhotoStore.downscaled(_:maxEdge:)`, shared
   helper). Gemini tiles images by size; staying under this threshold keeps
   each photo a single billing tile instead of several. (The existing
   single-scan `/api/skin/analyze` path currently sends full-resolution
   images — same helper should be applied there too as a low-risk side
   benefit, though it is not required for this feature to ship.)
3. **One call does both jobs.** The progress verdict and the adapted
   `updatedRoutine` are returned from the same request — never a separate
   follow-up call to regenerate the routine.
4. **History sampling.** At most first + latest + ~6 evenly-spaced
   intermediate points are sent, regardless of total scan count. Cost stays
   flat whether the user has 8 scans or 80.
5. **Bounded output.** `max_output_tokens` is capped — the response shape
   (verdict, three short lists, ≤8 routine steps) does not need an
   unbounded budget.

## Components

### Backend (`backend/main.py`)

| Component | Purpose |
|---|---|
| `POST /api/skin/progress` | New route; reuses existing `_authorized` token check |
| `PROGRESS_PROMPT` | Separate prompt; trends given as **stated facts**; model instructed not to recompute deltas and to defer to given trends if the two photos aren't visually comparable (different lighting/angle/distance) |
| `_normalize_progress()` | Coerces model output to the exact response shape; reuses existing `_normalize_routine_step` for the routine portion |
| `_generate()` (generalized) | Extended to accept an arbitrary prompt + parts list, shared by both endpoints' flash → flash-lite fallback chain |

### iOS

| Component | Purpose |
|---|---|
| `Models/ProgressTrend.swift` | Pure computation: polarity, flat-threshold, sampling, eligibility (`nil` if <2 scans or <7 days). No I/O — fully unit-testable |
| `Models/ProgressReport.swift` | `Codable` response type + `@Model` cache entity, keyed to latest scan ID |
| `Services/ProgressAnalysisService.swift` | HTTP client mirroring `SkinAnalysisService.swift` patterns |
| `Screens/ProgressReportView.swift` | Renders verdict, working/stalled/watch lists, "Update my routine" action |
| `ScanPhotoStore.downscaled(_:maxEdge:)` | Shared downscale helper for both scan paths |
| `SkinProgressView` (edit) | Adds the gated button and eligibility empty states |

## Edge cases

| Case | Behavior |
|---|---|
| Fewer than 2 scans | `ProgressTrend.compute` returns `nil`; button disabled, "scan at least twice" empty state |
| Span < 7 days | Returns `nil` with a distinct reason; "give your skin time" empty state, not a generic disabled button |
| A metric missing from an older scan (schema drift) | Metric skipped in the trend list — never zero-filled or fabricated |
| Change within ±3 points | Reported as `.flat`, regardless of polarity |
| All metrics flat | Verdict still computes (e.g. "steady"); UI shows this honestly, never forces an artificial win |
| `ScanPhotoStore.load()` returns nil for a photo | Analysis proceeds numbers-only (trends sent, that photo omitted) rather than failing outright |

## Error handling

- Backend: same `flash` → `flash-lite` fallback chain (generalized
  `_generate()`), same JSON-repair fallback (`raw.find("{")`/`rfind("}")`) as
  the existing `analyze_skin()` route. Both failing → `500`, surfaced in iOS
  as "Couldn't analyze your progress right now — try again shortly."
- No partial or unnormalized report is ever cached — the SwiftData cache is
  only written after a fully-normalized success.
- Model-contradicts-computed-trends (verdict says "improving" while every
  trend is `.worse`) is a known v1 gap, not code-enforced — accepted as a
  prompt-adherence concern for a future pass (e.g. "verdict must be
  consistent with the given trends" instruction), not a data-integrity one,
  since trends themselves are Swift-computed facts.
- Network/timeout: standard error banner; any existing cached report stays
  visible, untouched.
- Cache invalidation: purely "latest scan ID changed since this report was
  generated" — no TTL. A report about historical scans does not go stale on
  its own; only a new scan makes it incomplete.

## Testing

- **`ProgressTrendTests`** (pure): polarity correctness per metric
  direction, flat-threshold boundary (±3 vs ±3.01), missing-metric skip,
  <2-scans and <7-days nil cases, sampling behavior at 3/8/40 scans.
- **Backend**: extend `backend/test_main.py` with `/api/skin/progress`
  cases — auth required, malformed-JSON repair, both-models-fail path —
  following existing test structure/conventions in that file.
- **Manual**: two scans a week apart on simulator; confirm cache hit (no
  second network call) on re-opening the report with no new scan; confirm
  "Update my routine" correctly replaces today's `DailyRoutineChecklist`.

## Deferred (explicitly out of scope here)

- **Routine-adherence signal** (how many steps the user actually checked
  off) as an input to the progress call. Not included because
  `DailyRoutineChecklist` currently only exists on days the user scanned
  (see the "routine disappears the next day" gap discussed separately) —
  adherence data is too sparse today to be an honest signal. Becomes the
  next natural addition once that carry-forward gap is fixed.
- **Diary integration** (sleep/water/diet/stress). `SkinDiaryView` is
  currently unpersisted local `@State` with no backing model. Left out of
  v1 to avoid asking users to log daily in a feature whose premise is that
  it doesn't demand daily effort.
- **On-demand vs. forced-daily scanning cadence** changes — this spec
  assumes scanning stays user-initiated as it is today; it does not change
  scan frequency/prompting behavior.
- **Cross-check that the model's stated verdict is numerically consistent**
  with the Swift-computed trends (see Error handling above).
