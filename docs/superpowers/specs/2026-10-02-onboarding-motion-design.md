# Onboarding motion graphics: design

**Date:** 2026-10-02 · **Status:** approved (style C, all three slides, picked from browser mockups)

## Goal

Replace the three static SF Symbol tiles in the onboarding carousel with looping
motion graphics that show what ClearMaxx does: **scan the face, find pimples and
skin problems, build a routine for them, and track the skin clearing.** All three
slides share one illustrated face, so the slides read as a single story.

## Scope

- Slide 1 (Scan), slide 2 (Routine) and slide 3 (Progress) heroes in `OnboardingView`.
- Fix the English slide 1 title. "Illustrate Scan" is a mistranslation: every other
  locale says "Smart Scan", so English becomes "Smart Scan".

**Out of scope:** the carousel flow, buttons, Skip, page dots, the body copy, and
anything outside onboarding. No video or Lottie assets and no new dependencies:
everything is drawn natively in SwiftUI.

## The three heroes

All three heroes are drawn in one 200 × 240 design space, scaled to fit a white
rounded card (radius 24, `outline` border, coral bloom shadow). Each loops every
**6 s**. Percentages below are positions within that 6 s loop.

### 1 · Scan
Illustrated face (skin gradient, dark hair cap, closed eyes, blush, lips) inside
coral viewfinder corner brackets, with three skin problems drawn on it: a pimple on
the forehead, a cluster of redness on the left cheek, and a dark spot on the right cheek.

| % | Event |
|---|---|
| 8–52 | Coral scan line with a soft glow sweeps top → bottom |
| 19–25 | Forehead ring pops (overshoot 1.3 → 1), pulse ring repeats; "Acne" label rises in |
| 35–41 | Left cheek ring and "Redness" label |
| 39–45 | Right cheek ring and "Dark spot" label |
| 62–70 | Rings, labels and the spots themselves fade: the skin "clears" |
| 68–74 | "ClearScore 84 ↑" chip rises in, holds, and fades at 90–96 |

### 2 · Routine
Header: a slowly rotating sun and "Your morning ritual". Four step rows, each with
a small product glyph, a name and a subtitle tying it back to slide 1:

1. Cleanser: *Salicylic acid · for acne*
2. Serum: *Niacinamide · for redness*
3. Moisturizer: *Ceramides · for your barrier*
4. Sunscreen SPF 50: *Daily · for dark spots*

Rows slide in from the trailing side 0.55 s apart (spring overshoot). Each row's
check circle fills coral and its tick draws 0.35 s after the row lands. Then the
"Built from your scan ✦" chip rises in. Rows fade out in the same stagger before
the loop restarts.

### 3 · Progress
The same face at about 54 % scale at the top, with a before/after wipe handle that
slides from the right edge to the centre (14–42 %). The spots stay on the left
half ("Day 1") and are gone on the right half ("Day 30"). Both day chips appear at
40–46 %. Underneath, a rising ClearScore line draws itself (44–76 %), its end dot
pops in, and a "ClearScore N ↑" chip counts **62 → 84**.

## Architecture

New files in `ClearMaxx/Screens/OnboardingMotion/`. The app target is a
synchronized group, so they are picked up automatically.

| File | Responsibility |
|---|---|
| `MotionTimeline.swift` | Pure, UI-free keyframe math: loop progress from elapsed time, `ramp(t, from:to:)` with easing, `pop` overshoot, `window(t, in:out:)` for appear/hold/disappear, `lerp`. This is the only file with logic, and it's unit tested. |
| `FaceIllustration.swift` | The shared face (`FaceIllustration`) and spots (`SkinSpots`) as SwiftUI `Path`s ported from the mockup SVG, plus a `DesignSpace` helper that maps 200 × 240 coordinates into the card. |
| `ScanHero.swift`, `RoutineHero.swift`, `ProgressHero.swift` | Each one is a view of `t` (0..<1) only. No timers, no state, so any frame can be rendered for previews and Reduce Motion. |
| `OnboardingHero.swift` | Container: the card chrome, plus a `TimelineView(.animation(paused: !isActive))` clock. The clock restarts at `t = 0` whenever the slide becomes the visible page, so every slide plays its story from the beginning. |

`OnboardingView` change: `OnboardSlide.icon` becomes a hero kind (`.scan`,
`.routine`, `.progress`), and the coral tile is replaced by
`OnboardingHero(kind:isActive: page == i)`.

Labels are SwiftUI `Text` positioned in design space (not drawn into the paths),
so they localize and size to their content.

## Localization

Reuse the existing keys: `concern.acne`, `concern.redness`, `concern.darkSpots`,
`category.cleanser`, `category.serum`, `category.moisturizer`,
`category.sunscreen`, `progress.clearScore`.

New keys, added to all 12 locales:

- `onboarding.anim.morningRitual`: "Your morning ritual"
- `onboarding.anim.step1`: "Salicylic acid · for acne"
- `onboarding.anim.step2`: "Niacinamide · for redness"
- `onboarding.anim.step3`: "Ceramides · for your barrier"
- `onboarding.anim.step4`: "Daily · for dark spots"
- `onboarding.anim.builtFromScan`: "Built from your scan"
- `onboarding.anim.day`: "Day {0}"

**RTL:** the hero forces `.leftToRight` layout, like `ClearMaxxWordmark`, because
it's an illustration whose geometry must not mirror. The text inside still renders
right-to-left. Left-side labels anchor by their trailing edge and right-side labels
by their leading edge. Labels use `lineLimit(1)` + `minimumScaleFactor(0.7)` so
long German or Russian strings shrink instead of clipping.

## Accessibility and performance

- **Reduce Motion:** no loop. Each hero shows one static "story" frame: slide 1
  with all three problems ringed and labelled, slide 2 with all rows checked plus
  the chip, slide 3 with the wipe at the centre, the line drawn and the score at 84.
- The heroes are `accessibilityHidden(true)`. The slide title and body already say
  what the picture shows.
- Only the visible page's `TimelineView` runs. Neighbouring pages are paused.
  Everything is vector: no image assets, no bundle growth.
- The hero is 230 pt wide at a 200:240 aspect ratio and is allowed to shrink
  (`aspectRatio(.fit)` inside the slide's flexible space), so the iPhone SE still
  fits the title, body, dots and button.

## Testing

- **Unit (`OnboardingMotionTests`, added to the non-synchronized test target):**
  loop progress wraps at 6 s, `ramp` is 0 before / 1 after / eased between,
  `window` handles appear → hold → disappear, `pop` overshoots and settles, and the
  count-up maps 0 → 62 and 1 → 84.
- **Visual (simulator):** screenshot each slide mid-loop on an iPhone SE and an
  iPhone 16 Pro Max, and in German (long labels) and Arabic (RTL).
