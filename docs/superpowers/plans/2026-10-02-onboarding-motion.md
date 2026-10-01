# Onboarding Motion Graphics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the three static icon tiles in the ClearMaxx onboarding carousel with looping, natively drawn motion graphics: the face scan finds problems, a routine builds for them, and the skin clears while the score climbs.

**Architecture:** Each slide's hero is a pure function of one loop position `t` (0 ..< 1). A `XxxFrame` struct computes every opacity, offset and value for a given `t` (unit tested). A `XxxHero` view draws that frame with SwiftUI `Canvas` in a fixed 200 × 240 design space. `OnboardingHero` owns the clock (`TimelineView`), restarts the loop when its slide becomes visible, and shows one fixed "story" frame under Reduce Motion.

**Tech Stack:** SwiftUI (iOS 17), `Canvas` / `GraphicsContext`, `TimelineView`, XCTest. No new dependencies.

## Global Constraints

- iOS deployment target 17.0. Swift 5 language mode.
- No new dependencies, no image/video/Lottie assets: everything is drawn in code.
- Every user-facing string goes through `L("key")` and exists in all 12 catalogs in `ClearMaxx/Localization/Locales/*.json` (en zh es ar hi ja ko fr de pt tr ru).
- Brand colours come from `CMColor` (`primary` #FF7F50, `primaryDark` #F2643A, `surface`, `outline`, `ink`, `inkSoft`). Face and skin tones are illustration-only colours that live in `FaceIllustration`.
- Loop length 6 s for every hero (`MotionTimeline.loopDuration`).
- The hero card must not mirror in RTL (`.environment(\.layoutDirection, .leftToRight)`), and it is `accessibilityHidden(true)`.
- Reduce Motion → no `TimelineView`, one static frame per hero (`restingT`).
- The app target `ClearMaxx/` is a synchronized group: new app files need no project edits. The **test** target is NOT synchronized: new test files must be registered with the `xcodeproj` gem.
- Test command (run from `ClearMaxxApp/`):
  `xcodebuild test -project ClearMaxx.xcodeproj -scheme ClearMaxx -destination 'platform=iOS Simulator,id=46C10105-EE20-45D3-B475-53FC676682F8' -only-testing:ClearMaxxTests/OnboardingMotionTests 2>&1 | grep -E "Test Case|error:|\*\* TEST" | tail -40`
  (46C10105… is the booted iPhone 17 Pro simulator; any iOS 26 iPhone simulator UUID works.)

---

### Task 1: Motion timeline maths

**Files:**
- Create: `ClearMaxxApp/ClearMaxx/Screens/OnboardingMotion/MotionTimeline.swift`
- Create: `ClearMaxxApp/ClearMaxxTests/OnboardingMotionTests.swift`
- Modify: `ClearMaxxApp/ClearMaxx.xcodeproj/project.pbxproj` (register the test file)

**Interfaces:**
- Produces: `enum MotionTimeline` with
  `static let loopDuration: TimeInterval` (6),
  `static func progress(elapsed: TimeInterval, duration: TimeInterval = loopDuration) -> Double`,
  `static func linear(_ t: Double, from: Double, to: Double) -> Double`,
  `static func ramp(_ t: Double, from: Double, to: Double) -> Double`,
  `static func window(_ t: Double, appear: ClosedRange<Double>, disappear: ClosedRange<Double>) -> Double`,
  `static func lerp(_ a: Double, _ b: Double, _ x: Double) -> Double`,
  `static func pop(_ t: Double, from: Double, to: Double, overshoot: Double = 1.3) -> Double`,
  `static func easeOutBack(_ x: Double) -> Double`,
  `static func countUp(_ t: Double, from start: Int, to end: Int, over range: ClosedRange<Double>) -> Int`,
  `static func subPhase(_ t: Double, period: TimeInterval) -> Double`.

- [ ] **Step 1: Write the failing tests**

Create `ClearMaxxApp/ClearMaxxTests/OnboardingMotionTests.swift`:

```swift
import XCTest
@testable import ClearMaxx

/// The onboarding motion graphics are pure functions of one loop position `t`.
/// These pin down the keyframe maths and the story each slide must tell, most
/// importantly the single frame Reduce Motion users see instead of the loop.
final class OnboardingMotionTests: XCTestCase {

    // MARK: - MotionTimeline

    func test_progress_wrapsEverySixSeconds() {
        XCTAssertEqual(MotionTimeline.progress(elapsed: 0), 0)
        XCTAssertEqual(MotionTimeline.progress(elapsed: 3), 0.5, accuracy: 1e-9)
        XCTAssertEqual(MotionTimeline.progress(elapsed: 7.5), 0.25, accuracy: 1e-9)
    }

    func test_progress_treatsAClockReadJustBeforeARestartAsTheLoopStart() {
        XCTAssertEqual(MotionTimeline.progress(elapsed: -0.2), 0)
    }

    func test_linear_clampsOutsideItsRange() {
        XCTAssertEqual(MotionTimeline.linear(0.1, from: 0.2, to: 0.4), 0)
        XCTAssertEqual(MotionTimeline.linear(0.3, from: 0.2, to: 0.4), 0.5, accuracy: 1e-9)
        XCTAssertEqual(MotionTimeline.linear(0.9, from: 0.2, to: 0.4), 1)
    }

    func test_ramp_easesBetweenItsEnds() {
        XCTAssertEqual(MotionTimeline.ramp(0.2, from: 0.2, to: 0.4), 0)
        XCTAssertEqual(MotionTimeline.ramp(0.3, from: 0.2, to: 0.4), 0.5, accuracy: 1e-9)
        XCTAssertEqual(MotionTimeline.ramp(0.4, from: 0.2, to: 0.4), 1)
        // Eased, not linear: a quarter of the way in, it has moved less than a quarter.
        XCTAssertLessThan(MotionTimeline.ramp(0.25, from: 0.2, to: 0.4), 0.25)
    }

    func test_ramp_withAnEmptyRange_isAStep() {
        XCTAssertEqual(MotionTimeline.ramp(0.49, from: 0.5, to: 0.5), 0)
        XCTAssertEqual(MotionTimeline.ramp(0.5, from: 0.5, to: 0.5), 1)
    }

    func test_window_appearsHoldsAndDisappears() {
        let window = { MotionTimeline.window($0, appear: 0.1...0.2, disappear: 0.8...0.9) }
        XCTAssertEqual(window(0.05), 0)
        XCTAssertEqual(window(0.5), 1)
        XCTAssertEqual(window(0.95), 0)
    }

    func test_pop_overshootsThenSettlesOnOne() {
        XCTAssertEqual(MotionTimeline.pop(0.0, from: 0.2, to: 0.4), 0.2, accuracy: 1e-9)
        XCTAssertEqual(MotionTimeline.pop(0.3, from: 0.2, to: 0.4), 1.3, accuracy: 1e-9)
        XCTAssertEqual(MotionTimeline.pop(0.5, from: 0.2, to: 0.4), 1, accuracy: 1e-9)
    }

    func test_easeOutBack_startsAtZero_overshoots_andLandsOnOne() {
        XCTAssertEqual(MotionTimeline.easeOutBack(0), 0, accuracy: 1e-9)
        XCTAssertGreaterThan(MotionTimeline.easeOutBack(0.7), 1)
        XCTAssertEqual(MotionTimeline.easeOutBack(1), 1, accuracy: 1e-9)
    }

    func test_countUp_countsAcrossItsRange() {
        XCTAssertEqual(MotionTimeline.countUp(0.0, from: 62, to: 84, over: 0.44...0.76), 62)
        XCTAssertEqual(MotionTimeline.countUp(0.6, from: 62, to: 84, over: 0.44...0.76), 73)
        XCTAssertEqual(MotionTimeline.countUp(0.9, from: 62, to: 84, over: 0.44...0.76), 84)
    }

    func test_subPhase_repeatsEveryPeriodInsideTheLoop() {
        // 0.325 s is a quarter of a 1.3 s pulse; one full period later it is a quarter again.
        XCTAssertEqual(MotionTimeline.subPhase(0.325 / 6, period: 1.3), 0.25, accuracy: 1e-9)
        XCTAssertEqual(MotionTimeline.subPhase(1.625 / 6, period: 1.3), 0.25, accuracy: 1e-9)
    }
}
```

- [ ] **Step 2: Register the test file with the (non-synchronized) test target**

Run from `ClearMaxxApp/`:

```bash
ruby -e '
require "xcodeproj"
project = Xcodeproj::Project.open("ClearMaxx.xcodeproj")
target = project.targets.find { |t| t.name == "ClearMaxxTests" }
group = project.main_group.children.find { |g| g.respond_to?(:path) && g.path == "ClearMaxxTests" }
ref = group.new_reference("OnboardingMotionTests.swift")
target.add_file_references([ref])
project.save
'
grep -c "OnboardingMotionTests.swift" ClearMaxx.xcodeproj/project.pbxproj
```

Expected: `4` (build file, file reference, group child, sources phase).

- [ ] **Step 3: Run the tests to verify they fail**

Run the Global Constraints test command.
Expected: build failure, `error: cannot find 'MotionTimeline' in scope`.

- [ ] **Step 4: Write the implementation**

Create `ClearMaxxApp/ClearMaxx/Screens/OnboardingMotion/MotionTimeline.swift`:

```swift
//
//  MotionTimeline.swift
//  ClearMaxx — the clock and keyframe maths behind the onboarding motion graphics.
//
//  Every onboarding hero is a pure function of one number: `t`, its position in
//  a looping 6-second timeline (0 ..< 1). All the time-based maths lives here,
//  free of SwiftUI, so the choreography is unit-testable and any single frame
//  can be rendered on demand (previews, Reduce Motion).
//

import Foundation

enum MotionTimeline {
    /// Every onboarding hero loops on the same beat.
    static let loopDuration: TimeInterval = 6

    /// Position in the loop, `0 ..< 1`, after `elapsed` seconds. A clock read
    /// from just before a restart (zero or negative elapsed) is the loop start.
    static func progress(elapsed: TimeInterval, duration: TimeInterval = loopDuration) -> Double {
        guard duration > 0, elapsed > 0 else { return 0 }
        return elapsed.truncatingRemainder(dividingBy: duration) / duration
    }

    /// 0 before `from`, 1 after `to`, a straight line between.
    static func linear(_ t: Double, from: Double, to: Double) -> Double {
        guard to > from else { return t >= to ? 1 : 0 }
        return min(max((t - from) / (to - from), 0), 1)
    }

    /// 0 before `from`, 1 after `to`, eased in and out between (smoothstep).
    static func ramp(_ t: Double, from: Double, to: Double) -> Double {
        let x = linear(t, from: from, to: to)
        return x * x * (3 - 2 * x)
    }

    /// Fades in across `appear`, holds at 1, fades out across `disappear`.
    static func window(_ t: Double, appear: ClosedRange<Double>, disappear: ClosedRange<Double>) -> Double {
        ramp(t, from: appear.lowerBound, to: appear.upperBound)
            * (1 - ramp(t, from: disappear.lowerBound, to: disappear.upperBound))
    }

    static func lerp(_ a: Double, _ b: Double, _ x: Double) -> Double { a + (b - a) * x }

    /// Scale for a "pop": small before `from`, overshoots to `overshoot` at the
    /// midpoint, then settles on exactly 1 by `to`.
    static func pop(_ t: Double, from: Double, to: Double, overshoot: Double = 1.3) -> Double {
        let mid = (from + to) / 2
        if t < mid { return lerp(0.2, overshoot, ramp(t, from: from, to: mid)) }
        return lerp(overshoot, 1, ramp(t, from: mid, to: to))
    }

    /// Ease-out that runs slightly past 1 before settling: a springy arrival.
    static func easeOutBack(_ x: Double) -> Double {
        let c1 = 1.70158, c3 = c1 + 1
        let u = x - 1
        return 1 + c3 * u * u * u + c1 * u * u
    }

    /// An integer counting from `start` to `end` across `range`.
    static func countUp(_ t: Double, from start: Int, to end: Int, over range: ClosedRange<Double>) -> Int {
        let x = ramp(t, from: range.lowerBound, to: range.upperBound)
        return start + Int((Double(end - start) * x).rounded())
    }

    /// Phase (0 ..< 1) of a shorter effect that repeats every `period` seconds
    /// inside the main loop, such as a pulse ring.
    static func subPhase(_ t: Double, period: TimeInterval) -> Double {
        let cycles = t * loopDuration / period
        return cycles - cycles.rounded(.down)
    }
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run the Global Constraints test command.
Expected: all 10 `OnboardingMotionTests` cases pass, `** TEST SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add ClearMaxxApp/ClearMaxx/Screens/OnboardingMotion/MotionTimeline.swift ClearMaxxApp/ClearMaxxTests/OnboardingMotionTests.swift ClearMaxxApp/ClearMaxx.xcodeproj/project.pbxproj
git commit -m "iOS: keyframe maths for the onboarding motion graphics"
```

---

### Task 2: Strings for the animations in all 12 languages

**Files:**
- Modify: `ClearMaxxApp/ClearMaxx/Localization/Locales/{en,zh,es,ar,hi,ja,ko,fr,de,pt,tr,ru}.json`
- Test: `ClearMaxxApp/ClearMaxxTests/OnboardingMotionTests.swift`

**Interfaces:**
- Produces keys: `onboarding.anim.morningRitual`, `onboarding.anim.step1` … `step4`, `onboarding.anim.builtFromScan`, `onboarding.anim.day` (with `{0}`). English `onboarding.slide1.title` becomes "Smart Scan".
- Later tasks also use existing keys: `concern.acne`, `concern.redness`, `concern.darkSpots`, `category.cleanser`, `category.serum`, `category.moisturizer`, `category.sunscreen`, `progress.clearScore`.

- [ ] **Step 1: Write the failing test**

Append inside `OnboardingMotionTests` (before the final `}`):

```swift
    // MARK: - Strings

    func test_everyLanguageHasTheAnimationStrings() throws {
        let keys = ["onboarding.anim.morningRitual", "onboarding.anim.step1", "onboarding.anim.step2",
                    "onboarding.anim.step3", "onboarding.anim.step4", "onboarding.anim.builtFromScan",
                    "onboarding.anim.day"]
        for code in CMLanguages.codes {
            let catalog = try Self.catalog(code)
            for key in keys {
                XCTAssertFalse(catalog[key, default: ""].isEmpty, "\(code) is missing \(key)")
            }
            XCTAssertTrue(catalog["onboarding.anim.day", default: ""].contains("{0}"),
                          "\(code): the day label needs its {0} placeholder")
        }
    }

    func test_englishScanTitle_saysSmartScanLikeEveryOtherLanguage() throws {
        XCTAssertEqual(try Self.catalog("en")["onboarding.slide1.title"], "Smart Scan")
    }

    private static func catalog(_ code: String) throws -> [String: String] {
        let url = try XCTUnwrap(Bundle.main.url(forResource: code, withExtension: "json")
            ?? Bundle.main.url(forResource: code, withExtension: "json", subdirectory: "Locales"),
            "no catalog for \(code)")
        return try JSONDecoder().decode([String: String].self, from: Data(contentsOf: url))
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run the Global Constraints test command.
Expected: FAIL. `en is missing onboarding.anim.morningRitual` (and the others), and `"Illustrate Scan"` is not equal to `"Smart Scan"`.

- [ ] **Step 3: Add the strings**

Run from `ClearMaxxApp/` (inserts the new keys after `onboarding.slide3.body`, keeping each file's order and its lack of a trailing newline):

```bash
python3 - <<'PY'
import json, collections, pathlib
root = pathlib.Path("ClearMaxx/Localization/Locales")
keys = ["morningRitual", "step1", "step2", "step3", "step4", "builtFromScan", "day"]
new = {
 "en": ["Your morning ritual", "Salicylic acid · for acne", "Niacinamide · for redness", "Ceramides · for your barrier", "Daily · for dark spots", "Built from your scan", "Day {0}"],
 "zh": ["你的晨间护肤", "水杨酸 · 针对痘痘", "烟酰胺 · 针对泛红", "神经酰胺 · 修护屏障", "每日 · 针对色斑", "根据你的扫描定制", "第{0}天"],
 "es": ["Tu ritual de mañana", "Ácido salicílico · para el acné", "Niacinamida · para las rojeces", "Ceramidas · para tu barrera", "A diario · para las manchas oscuras", "Creada a partir de tu escaneo", "Día {0}"],
 "ar": ["روتينك الصباحي", "حمض الساليسيليك · لحب الشباب", "نياسيناميد · للاحمرار", "سيراميدات · لحاجز بشرتك", "يوميًا · للبقع الداكنة", "مبني على فحصك", "اليوم {0}"],
 "hi": ["आपकी सुबह की दिनचर्या", "सैलिसिलिक एसिड · मुंहासों के लिए", "नियासिनामाइड · लालिमा के लिए", "सेरामाइड्स · त्वचा की सुरक्षा परत के लिए", "रोज़ाना · काले धब्बों के लिए", "आपके स्कैन के आधार पर", "दिन {0}"],
 "ja": ["朝のスキンケア", "サリチル酸 · ニキビに", "ナイアシンアミド · 赤みに", "セラミド · バリア機能に", "毎日 · シミに", "スキャン結果から作成", "{0}日目"],
 "ko": ["나의 아침 루틴", "살리실산 · 여드름 케어", "나이아신아마이드 · 홍조 케어", "세라마이드 · 피부 장벽 케어", "매일 · 잡티 케어", "스캔 결과로 맞춤 설계", "{0}일차"],
 "fr": ["Votre rituel du matin", "Acide salicylique · contre l'acné", "Niacinamide · contre les rougeurs", "Céramides · pour votre barrière cutanée", "Chaque jour · contre les taches brunes", "Créé à partir de votre scan", "Jour {0}"],
 "de": ["Deine Morgenroutine", "Salicylsäure · gegen Akne", "Niacinamid · gegen Rötungen", "Ceramide · für deine Hautbarriere", "Täglich · gegen dunkle Flecken", "Aus deinem Scan erstellt", "Tag {0}"],
 "pt": ["Seu ritual da manhã", "Ácido salicílico · para acne", "Niacinamida · para vermelhidão", "Ceramidas · para sua barreira", "Diário · para manchas escuras", "Criado a partir do seu escaneamento", "Dia {0}"],
 "tr": ["Sabah ritüelin", "Salisilik asit · akne için", "Niasinamid · kızarıklık için", "Seramidler · cilt bariyerin için", "Her gün · koyu lekeler için", "Taramana göre hazırlandı", "{0}. gün"],
 "ru": ["Ваш утренний ритуал", "Салициловая кислота · против акне", "Ниацинамид · против покраснений", "Церамиды · для защитного барьера", "Ежедневно · против пигментных пятен", "Создано по вашему скану", "День {0}"],
}
for code, values in new.items():
    path = root / f"{code}.json"
    data = json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=collections.OrderedDict)
    out = collections.OrderedDict()
    for k, v in data.items():
        out[k] = v
        if k == "onboarding.slide3.body":
            for key, value in zip(keys, values):
                out[f"onboarding.anim.{key}"] = value
    if code == "en":
        out["onboarding.slide1.title"] = "Smart Scan"
    path.write_text(json.dumps(out, ensure_ascii=False, indent=2), encoding="utf-8")
PY
git diff --stat ClearMaxx/Localization/Locales
```

Expected: `en.json` shows `8 insertions(+), 1 deletion(-)`; every other catalog shows `7 insertions(+)` and no deletions. If any file shows more deletions, the re-serialisation changed escaping: `git checkout` that file and investigate before continuing.

- [ ] **Step 4: Run the tests to verify they pass**

Run the Global Constraints test command.
Expected: all 12 tests pass.

- [ ] **Step 5: Commit**

```bash
git add ClearMaxxApp/ClearMaxx/Localization/Locales ClearMaxxApp/ClearMaxxTests/OnboardingMotionTests.swift
git commit -m "iOS: onboarding animation strings in 12 languages; English slide 1 title is Smart Scan"
```

---

### Task 3: Shared drawing + slide 1 (Scan)

**Files:**
- Create: `ClearMaxxApp/ClearMaxx/Screens/OnboardingMotion/HeroDrawing.swift`
- Create: `ClearMaxxApp/ClearMaxx/Screens/OnboardingMotion/FaceIllustration.swift`
- Create: `ClearMaxxApp/ClearMaxx/Screens/OnboardingMotion/ScanHero.swift`
- Test: `ClearMaxxApp/ClearMaxxTests/OnboardingMotionTests.swift`

**Interfaces:**
- Consumes: `MotionTimeline` (Task 1); string keys (Task 2).
- Produces:
  - `enum HeroPaint`: `static let designSize: CGSize` (200 × 240); `static func designSpace(_ context: GraphicsContext, size: CGSize) -> GraphicsContext`; `static func circle(_ center: CGPoint, _ radius: CGFloat) -> Path`; `enum PillStyle { case outline, coral, dark }`; `static func pill(_ text: String, center: CGPoint, style: PillStyle, fontSize: CGFloat = 8.5, height: CGFloat = 16, maxWidth: CGFloat = 120, in context: GraphicsContext)`; `static func text(_ string: String, size: CGFloat, weight: Font.Weight, color: Color, at point: CGPoint, anchor: UnitPoint, maxWidth: CGFloat, in context: GraphicsContext)`.
  - `enum FaceIllustration`: `static let acne, redness, darkSpot: CGPoint`; `static func drawFace(in context: GraphicsContext)`; `static func drawSpots(in context: GraphicsContext)`.
  - `struct ScanFrame` (`init(t: Double)`, `static let markers: [Marker]`, `static let restingT: Double`) and `struct ScanHero: View` (`init(t: Double, pulses: Bool = true)`).

- [ ] **Step 1: Write the failing tests**

Append inside `OnboardingMotionTests`:

```swift
    // MARK: - Slide 1 · Scan

    func test_scan_eachRingPopsAsTheScanLineReachesIt() {
        for marker in ScanFrame.markers {
            XCTAssertEqual(ScanFrame(t: marker.start).scanY, Double(marker.center.y), accuracy: 12,
                           "\(marker.labelKey) pops out of step with the scan line")
        }
    }

    func test_scan_restingFrame_showsEveryProblemRingedAndLabelled() {
        let frame = ScanFrame(t: ScanFrame.restingT)
        XCTAssertEqual(frame.scanOpacity, 0, accuracy: 1e-9, "no scan line frozen mid-face")
        XCTAssertEqual(frame.spotsOpacity, 1, accuracy: 1e-9)
        for i in ScanFrame.markers.indices {
            XCTAssertEqual(frame.markerOpacity(i), 1, accuracy: 1e-9)
            XCTAssertEqual(frame.markerScale(i), 1, accuracy: 1e-9)
            XCTAssertEqual(frame.labelOpacity(i), 1, accuracy: 1e-9)
        }
        XCTAssertEqual(frame.chipOpacity, 0, accuracy: 1e-9)
    }

    func test_scan_loopSeamIsInvisible() {
        let end = ScanFrame(t: 0.9999), start = ScanFrame(t: 0)
        XCTAssertEqual(end.spotsOpacity, start.spotsOpacity, accuracy: 0.01)
        XCTAssertEqual(end.chipOpacity, 0, accuracy: 0.01)
        for i in ScanFrame.markers.indices {
            XCTAssertEqual(end.markerOpacity(i), 0, accuracy: 0.01)
            XCTAssertEqual(start.markerOpacity(i), 0, accuracy: 1e-9)
        }
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run the Global Constraints test command.
Expected: build failure, `cannot find 'ScanFrame' in scope`.

- [ ] **Step 3: Write `HeroDrawing.swift`**

```swift
//
//  HeroDrawing.swift
//  ClearMaxx — shared drawing helpers for the onboarding heroes.
//
//  Heroes draw in a fixed 200 × 240 design space (the geometry of the approved
//  mockups) and are scaled to whatever size the card is given.
//

import SwiftUI

enum HeroPaint {
    static let designSize = CGSize(width: 200, height: 240)

    /// A copy of `context` scaled so drawing can use design-space coordinates.
    static func designSpace(_ context: GraphicsContext, size: CGSize) -> GraphicsContext {
        var scaled = context
        scaled.scaleBy(x: size.width / designSize.width, y: size.height / designSize.height)
        return scaled
    }

    static func circle(_ center: CGPoint, _ radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }

    enum PillStyle { case outline, coral, dark }

    /// Draws `text` in a capsule centred on `center`. Long translations shrink
    /// (to 70 % at most) and the capsule slides sideways rather than cross the
    /// card edge.
    static func pill(_ text: String, center: CGPoint, style: PillStyle, fontSize: CGFloat = 8.5,
                     height: CGFloat = 16, maxWidth: CGFloat = 120, in context: GraphicsContext) {
        let padding: CGFloat = 7
        let color = style == .outline ? CMColor.primaryDark : Color.white
        let label = fitted(text, size: fontSize, weight: .bold, color: color,
                           maxWidth: maxWidth - padding * 2, minScale: 0.7, in: context)
        let width = label.width + padding * 2
        let x = min(max(center.x, 2 + width / 2), designSize.width - 2 - width / 2)
        let rect = CGRect(x: x - width / 2, y: center.y - height / 2, width: width, height: height)
        let capsule = Path(roundedRect: rect, cornerRadius: height / 2)
        switch style {
        case .outline:
            context.fill(capsule, with: .color(CMColor.surface))
            context.stroke(capsule, with: .color(CMColor.primary), lineWidth: 1)
        case .coral:
            context.fill(capsule, with: .linearGradient(
                Gradient(colors: [CMColor.primary, CMColor.primaryDark]),
                startPoint: CGPoint(x: rect.minX, y: rect.midY), endPoint: CGPoint(x: rect.maxX, y: rect.midY)))
        case .dark:
            context.fill(capsule, with: .color(CMColor.ink.opacity(0.8)))
        }
        context.draw(label.text, at: CGPoint(x: x, y: center.y), anchor: .center)
    }

    /// Draws one line of text, shrinking it (to 60 % at most) to fit `maxWidth`.
    static func text(_ string: String, size: CGFloat, weight: Font.Weight, color: Color,
                     at point: CGPoint, anchor: UnitPoint, maxWidth: CGFloat, in context: GraphicsContext) {
        let label = fitted(string, size: size, weight: weight, color: color,
                           maxWidth: maxWidth, minScale: 0.6, in: context)
        context.draw(label.text, at: point, anchor: anchor)
    }

    private static let unbounded = CGSize(width: CGFloat.greatestFiniteMagnitude,
                                          height: CGFloat.greatestFiniteMagnitude)

    /// `string` resolved at the largest size (down to `minScale` × `size`) that fits `maxWidth`.
    private static func fitted(_ string: String, size: CGFloat, weight: Font.Weight, color: Color,
                               maxWidth: CGFloat, minScale: CGFloat,
                               in context: GraphicsContext) -> (text: GraphicsContext.ResolvedText, width: CGFloat) {
        func make(_ points: CGFloat) -> Text {
            Text(string).font(.system(size: points, weight: weight)).foregroundStyle(color)
        }
        let natural = context.resolve(make(size)).measure(in: unbounded).width
        let scale = min(1, max(minScale, maxWidth / max(natural, 1)))
        return (context.resolve(make(size * scale)), natural * scale)
    }
}
```

- [ ] **Step 4: Write `FaceIllustration.swift`**

```swift
//
//  FaceIllustration.swift
//  ClearMaxx — the illustrated face shared by all three onboarding heroes.
//
//  Drawn in the 200 × 240 design space. The paths are ported one-to-one from
//  the approved SVG mockup, so every slide shows the face that was signed off.
//

import SwiftUI

enum FaceIllustration {
    /// Where the three skin problems sit, for heroes that point at them.
    static let acne = CGPoint(x: 118, y: 70)
    static let redness = CGPoint(x: 62, y: 140)
    static let darkSpot = CGPoint(x: 140, y: 150)

    // Illustration palette: skin, hair and blemish tones, deliberately outside the brand tokens.
    private static let skinLight = Color(hex: "F7D2B6")
    private static let skinShade = Color(hex: "ECB08E")
    private static let neck = Color(hex: "E3A584")
    private static let top = Color(hex: "FFE3D6")
    private static let hair = Color(hex: "3B2A24")
    private static let blush = Color(hex: "F4A08F")
    private static let features = Color(hex: "5A3A2E")
    private static let noseLine = Color(hex: "C98868")
    private static let lips = Color(hex: "E07F78")
    private static let pimple = Color(hex: "E2665A")
    private static let rednessPatch = Color(hex: "E8796B")
    private static let rednessDot = Color(hex: "D9574B")
    private static let pigment = Color(hex: "A86B4E")

    static func drawFace(in context: GraphicsContext) {
        context.fill(shoulders, with: .color(top))
        context.fill(Path(CGRect(x: 80, y: 176, width: 40, height: 40)), with: .color(neck))
        context.fill(Path(ellipseIn: CGRect(x: 26, y: 99, width: 16, height: 26)), with: .color(skinShade))
        context.fill(Path(ellipseIn: CGRect(x: 158, y: 99, width: 16, height: 26)), with: .color(skinShade))
        context.fill(head, with: .linearGradient(Gradient(colors: [skinLight, skinShade]),
                                                 startPoint: CGPoint(x: 100, y: 22), endPoint: CGPoint(x: 100, y: 208)))
        context.fill(hairCap, with: .color(hair))
        context.fill(Path(ellipseIn: CGRect(x: 53, y: 138, width: 26, height: 16)), with: .color(blush.opacity(0.35)))
        context.fill(Path(ellipseIn: CGRect(x: 121, y: 138, width: 26, height: 16)), with: .color(blush.opacity(0.35)))
        context.stroke(browsAndEyes, with: .color(features),
                       style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
        context.stroke(nose, with: .color(noseLine),
                       style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        context.fill(mouth, with: .color(lips))
    }

    static func drawSpots(in context: GraphicsContext) {
        context.fill(HeroPaint.circle(acne, 6), with: .color(pimple.opacity(0.25)))
        context.fill(HeroPaint.circle(acne, 3), with: .color(pimple))
        context.fill(Path(ellipseIn: CGRect(x: 50, y: 132, width: 24, height: 16)), with: .color(rednessPatch.opacity(0.4)))
        context.fill(HeroPaint.circle(CGPoint(x: 58, y: 138), 1.8), with: .color(rednessDot))
        context.fill(HeroPaint.circle(CGPoint(x: 65, y: 143), 1.6), with: .color(rednessDot))
        context.fill(HeroPaint.circle(CGPoint(x: 67, y: 136), 1.4), with: .color(rednessDot))
        context.fill(HeroPaint.circle(darkSpot, 3.6), with: .color(pigment.opacity(0.7)))
    }

    // MARK: - Paths (design space)

    private static var shoulders: Path {
        var p = Path()
        p.move(to: pt(28, 240))
        p.addCurve(to: pt(100, 204), control1: pt(38, 214), control2: pt(68, 204))
        p.addCurve(to: pt(172, 240), control1: pt(132, 204), control2: pt(162, 214))
        p.closeSubpath()
        return p
    }

    private static var head: Path {
        var p = Path()
        p.move(to: pt(100, 22))
        p.addCurve(to: pt(167, 106), control1: pt(146, 22), control2: pt(168, 58))
        p.addCurve(to: pt(100, 208), control1: pt(166, 152), control2: pt(140, 196))
        p.addCurve(to: pt(33, 106), control1: pt(60, 196), control2: pt(34, 152))
        p.addCurve(to: pt(100, 22), control1: pt(32, 58), control2: pt(54, 22))
        p.closeSubpath()
        return p
    }

    private static var hairCap: Path {
        var p = Path()
        p.move(to: pt(33, 106))
        p.addCurve(to: pt(100, 14), control1: pt(30, 50), control2: pt(58, 14))
        p.addCurve(to: pt(167, 106), control1: pt(142, 14), control2: pt(170, 50))
        p.addCurve(to: pt(128, 56), control1: pt(160, 84), control2: pt(150, 62))
        p.addCurve(to: pt(70, 62), control1: pt(110, 51), control2: pt(84, 54))
        p.addCurve(to: pt(33, 106), control1: pt(52, 72), control2: pt(40, 88))
        p.closeSubpath()
        return p
    }

    private static var browsAndEyes: Path {
        var p = Path()
        p.move(to: pt(58, 90)); p.addQuadCurve(to: pt(89, 88), control: pt(73, 82))
        p.move(to: pt(111, 88)); p.addQuadCurve(to: pt(142, 90), control: pt(127, 82))
        p.move(to: pt(62, 104)); p.addQuadCurve(to: pt(88, 104), control: pt(75, 112))
        p.move(to: pt(112, 104)); p.addQuadCurve(to: pt(138, 104), control: pt(125, 112))
        return p
    }

    private static var nose: Path {
        var p = Path()
        p.move(to: pt(100, 112))
        p.addQuadCurve(to: pt(95, 136), control: pt(98, 128))
        p.addQuadCurve(to: pt(106, 137), control: pt(100, 140))
        return p
    }

    private static var mouth: Path {
        var p = Path()
        p.move(to: pt(84, 165))
        p.addQuadCurve(to: pt(100, 163), control: pt(92, 160))
        p.addQuadCurve(to: pt(116, 165), control: pt(108, 160))
        p.addQuadCurve(to: pt(84, 165), control: pt(100, 178))
        p.closeSubpath()
        return p
    }
}

private func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }
```

- [ ] **Step 5: Write `ScanHero.swift`**

```swift
//
//  ScanHero.swift
//  ClearMaxx — onboarding slide 1: the scan finds acne, redness and a dark
//  spot, then the skin clears and the ClearScore lands.
//

import SwiftUI

/// Where everything on the scan slide is at loop position `t`. Pure values,
/// no drawing, so the choreography can be tested.
struct ScanFrame {
    struct Marker {
        let center: CGPoint
        let ringRadius: CGFloat
        let labelKey: String
        let labelCenter: CGPoint
        /// Loop position where the ring pops, timed to the scan line reaching it.
        let start: Double
    }

    static let markers: [Marker] = [
        Marker(center: FaceIllustration.acne, ringRadius: 8, labelKey: "concern.acne",
               labelCenter: CGPoint(x: 152, y: 46), start: 0.19),
        Marker(center: FaceIllustration.redness, ringRadius: 14, labelKey: "concern.redness",
               labelCenter: CGPoint(x: 30, y: 114), start: 0.35),
        Marker(center: FaceIllustration.darkSpot, ringRadius: 8, labelKey: "concern.darkSpots",
               labelCenter: CGPoint(x: 168, y: 174), start: 0.39),
    ]

    /// The Reduce Motion frame: every problem ringed and labelled, no scan line.
    static let restingT = 0.58

    let t: Double

    var scanY: Double { 20 + 190 * MotionTimeline.linear(t, from: 0.08, to: 0.52) }
    var scanOpacity: Double { MotionTimeline.window(t, appear: 0.08...0.10, disappear: 0.52...0.56) }

    /// The spots fade as the skin "clears" and are back by the loop seam.
    var spotsOpacity: Double {
        1 - MotionTimeline.ramp(t, from: 0.62, to: 0.70) + MotionTimeline.ramp(t, from: 0.94, to: 1.0)
    }

    /// Rings and labels leave together, just before the spots do.
    private var overlayOpacity: Double { 1 - MotionTimeline.ramp(t, from: 0.62, to: 0.68) }

    func markerOpacity(_ i: Int) -> Double {
        let s = Self.markers[i].start
        return MotionTimeline.ramp(t, from: s, to: s + 0.03) * overlayOpacity
    }

    func markerScale(_ i: Int) -> Double {
        let s = Self.markers[i].start
        return MotionTimeline.pop(t, from: s, to: s + 0.06)
    }

    func labelOpacity(_ i: Int) -> Double {
        let s = Self.markers[i].start
        return MotionTimeline.ramp(t, from: s + 0.03, to: s + 0.07) * overlayOpacity
    }

    /// How far below its resting place the label still is as it rises in.
    func labelRise(_ i: Int) -> Double {
        let s = Self.markers[i].start
        return 5 * (1 - MotionTimeline.ramp(t, from: s + 0.03, to: s + 0.07))
    }

    var chipOpacity: Double { MotionTimeline.window(t, appear: 0.68...0.74, disappear: 0.90...0.96) }
    var chipRise: Double { 8 * (1 - MotionTimeline.ramp(t, from: 0.68, to: 0.74)) }

    /// The pulse ring around each marker repeats every 1.3 s.
    var pulsePhase: Double { MotionTimeline.subPhase(t, period: 1.3) }
}

struct ScanHero: View {
    let t: Double
    /// Off under Reduce Motion: the pulse rings are pure decoration.
    var pulses: Bool = true

    var body: some View {
        let frame = ScanFrame(t: t)
        let labels = ScanFrame.markers.map { L($0.labelKey) }
        let score = "\(L("progress.clearScore")) 84 ↑"
        Canvas { context, size in
            let ctx = HeroPaint.designSpace(context, size: size)
            FaceIllustration.drawFace(in: ctx)
            var spots = ctx
            spots.opacity = frame.spotsOpacity
            FaceIllustration.drawSpots(in: spots)
            ctx.stroke(Self.brackets, with: .color(CMColor.primary),
                       style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            drawScanLine(frame, in: ctx)
            for i in ScanFrame.markers.indices {
                drawMarker(i, frame: frame, label: labels[i], in: ctx)
            }
            if frame.chipOpacity > 0 {
                var chip = ctx
                chip.opacity = frame.chipOpacity
                HeroPaint.pill(score, center: CGPoint(x: 100, y: 222 + frame.chipRise),
                               style: .coral, height: 20, in: chip)
            }
        }
    }

    private func drawScanLine(_ frame: ScanFrame, in context: GraphicsContext) {
        guard frame.scanOpacity > 0 else { return }
        var c = context
        c.opacity = frame.scanOpacity
        let y = frame.scanY
        let glow = CGRect(x: 20, y: y - 16, width: 160, height: 32)
        c.fill(Path(glow), with: .linearGradient(
            Gradient(stops: [.init(color: CMColor.primary.opacity(0), location: 0),
                             .init(color: CMColor.primary.opacity(0.35), location: 0.5),
                             .init(color: CMColor.primary.opacity(0), location: 1)]),
            startPoint: CGPoint(x: 100, y: glow.minY), endPoint: CGPoint(x: 100, y: glow.maxY)))
        var line = Path()
        line.move(to: CGPoint(x: 20, y: y))
        line.addLine(to: CGPoint(x: 180, y: y))
        c.stroke(line, with: .color(CMColor.primary), lineWidth: 2)
    }

    private func drawMarker(_ i: Int, frame: ScanFrame, label: String, in context: GraphicsContext) {
        let marker = ScanFrame.markers[i]
        let opacity = frame.markerOpacity(i)
        if opacity > 0 {
            var ring = context
            ring.opacity = opacity
            ring.stroke(HeroPaint.circle(marker.center, marker.ringRadius * frame.markerScale(i)),
                        with: .color(CMColor.primary), lineWidth: 2)
            if pulses {
                let phase = frame.pulsePhase
                var pulse = context
                pulse.opacity = opacity * 0.8 * (1 - phase)
                pulse.stroke(HeroPaint.circle(marker.center, marker.ringRadius * (1 + 1.4 * phase)),
                             with: .color(CMColor.primary), lineWidth: 1.5)
            }
        }
        let labelOpacity = frame.labelOpacity(i)
        guard labelOpacity > 0 else { return }
        var c = context
        c.opacity = labelOpacity
        let target = CGPoint(x: marker.labelCenter.x, y: marker.labelCenter.y + frame.labelRise(i))
        let dx = target.x - marker.center.x, dy = target.y - marker.center.y
        let length = max(hypot(dx, dy), 1)
        // The leader runs from the ring's edge to the pill's centre; the pill covers its far end.
        var leader = Path()
        leader.move(to: CGPoint(x: marker.center.x + dx / length * marker.ringRadius,
                                y: marker.center.y + dy / length * marker.ringRadius))
        leader.addLine(to: target)
        c.stroke(leader, with: .color(CMColor.primary), lineWidth: 1.2)
        HeroPaint.pill(label, center: target, style: .outline, in: c)
    }

    /// Viewfinder corners framing the face.
    private static var brackets: Path {
        var p = Path()
        p.move(to: CGPoint(x: 14, y: 30)); p.addLine(to: CGPoint(x: 14, y: 14)); p.addLine(to: CGPoint(x: 30, y: 14))
        p.move(to: CGPoint(x: 170, y: 14)); p.addLine(to: CGPoint(x: 186, y: 14)); p.addLine(to: CGPoint(x: 186, y: 30))
        p.move(to: CGPoint(x: 186, y: 210)); p.addLine(to: CGPoint(x: 186, y: 226)); p.addLine(to: CGPoint(x: 170, y: 226))
        p.move(to: CGPoint(x: 30, y: 226)); p.addLine(to: CGPoint(x: 14, y: 226)); p.addLine(to: CGPoint(x: 14, y: 210))
        return p
    }
}

#Preview("Scan · problems found") {
    ScanHero(t: ScanFrame.restingT).frame(width: 230, height: 276).background(.white)
}
```

- [ ] **Step 6: Run the tests to verify they pass**

Run the Global Constraints test command.
Expected: all 15 tests pass.

- [ ] **Step 7: Commit**

```bash
git add ClearMaxxApp/ClearMaxx/Screens/OnboardingMotion ClearMaxxApp/ClearMaxxTests/OnboardingMotionTests.swift
git commit -m "iOS: onboarding scan hero: the face scan finds acne, redness and a dark spot"
```

---

### Task 4: Slide 2 (Routine)

**Files:**
- Create: `ClearMaxxApp/ClearMaxx/Screens/OnboardingMotion/RoutineHero.swift`
- Test: `ClearMaxxApp/ClearMaxxTests/OnboardingMotionTests.swift`

**Interfaces:**
- Consumes: `MotionTimeline`, `HeroPaint.designSpace / circle / pill / text` (Task 3), keys from Task 2.
- Produces: `struct RoutineFrame` (`init(t: Double)`, `static let rowCount = 4`, `static let restingT: Double`, `static func rowStart(_ i: Int) -> Double`, `rowOpacity(_:)`, `rowSlide(_:)`, `checkFill(_:)`, `tickDraw(_:)`, `chipOpacity`, `chipRise`, `sunDegrees`) and `struct RoutineHero: View` (`init(t: Double)`).

- [ ] **Step 1: Write the failing tests**

Append inside `OnboardingMotionTests`:

```swift
    // MARK: - Slide 2 · Routine

    func test_routine_stepsArriveInOrder() {
        for i in 1..<RoutineFrame.rowCount {
            XCTAssertGreaterThan(RoutineFrame.rowStart(i), RoutineFrame.rowStart(i - 1))
        }
    }

    func test_routine_restingFrame_showsEveryStepInAndTicked() {
        let frame = RoutineFrame(t: RoutineFrame.restingT)
        for i in 0..<RoutineFrame.rowCount {
            XCTAssertEqual(frame.rowOpacity(i), 1, accuracy: 1e-9)
            XCTAssertEqual(frame.rowSlide(i), 0, accuracy: 1e-9)
            XCTAssertEqual(frame.checkFill(i), 1, accuracy: 1e-9)
            XCTAssertEqual(frame.tickDraw(i), 1, accuracy: 1e-9)
        }
        XCTAssertEqual(frame.chipOpacity, 1, accuracy: 1e-9)
    }

    func test_routine_everythingHasLeftByTheLoopSeam() {
        let end = RoutineFrame(t: 0.9999)
        for i in 0..<RoutineFrame.rowCount {
            XCTAssertEqual(end.rowOpacity(i), 0, accuracy: 1e-9)
        }
        XCTAssertEqual(end.chipOpacity, 0, accuracy: 1e-9)
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run the Global Constraints test command.
Expected: build failure, `cannot find 'RoutineFrame' in scope`.

- [ ] **Step 3: Write `RoutineHero.swift`**

```swift
//
//  RoutineHero.swift
//  ClearMaxx — onboarding slide 2: a morning routine builds itself, one step
//  per problem the scan found, each ticking off as it lands.
//

import SwiftUI

/// Where everything on the routine slide is at loop position `t`.
struct RoutineFrame {
    static let rowCount = 4
    /// Rows land 0.55 s apart.
    static let stagger = 0.55 / MotionTimeline.loopDuration
    /// The Reduce Motion frame: every step in and ticked, chip showing.
    static let restingT = 0.62

    static func rowStart(_ i: Int) -> Double { 0.04 + Double(i) * stagger }

    let t: Double

    /// Rows leave in the same order they arrived, all gone before the loop seam.
    func rowOpacity(_ i: Int) -> Double {
        let a = Self.rowStart(i), d = 0.70 + Double(i) * 0.06
        return MotionTimeline.ramp(t, from: a, to: a + 0.05) * (1 - MotionTimeline.ramp(t, from: d, to: d + 0.05))
    }

    /// Distance still to travel as the row slides in from the trailing side, with a springy overshoot.
    func rowSlide(_ i: Int) -> Double {
        let a = Self.rowStart(i)
        return 18 * (1 - MotionTimeline.easeOutBack(MotionTimeline.linear(t, from: a, to: a + 0.07)))
    }

    /// The check fills 0.35 s after its row starts to land.
    func checkFill(_ i: Int) -> Double {
        let c = Self.rowStart(i) + 0.35 / MotionTimeline.loopDuration
        return MotionTimeline.ramp(t, from: c, to: c + 0.03)
    }

    func tickDraw(_ i: Int) -> Double {
        let c = Self.rowStart(i) + 0.35 / MotionTimeline.loopDuration
        return MotionTimeline.ramp(t, from: c + 0.01, to: c + 0.05)
    }

    var chipOpacity: Double { MotionTimeline.window(t, appear: 0.52...0.58, disappear: 0.92...0.97) }
    var chipRise: Double { 8 * (1 - MotionTimeline.ramp(t, from: 0.52, to: 0.58)) }

    /// Half a turn per loop. The eight-ray sun looks identical at 0° and 180°, so the seam is invisible.
    var sunDegrees: Double { t * 180 }
}

struct RoutineHero: View {
    let t: Double

    var body: some View {
        let frame = RoutineFrame(t: t)
        let header = L("onboarding.anim.morningRitual")
        let titles = [L("category.cleanser"), L("category.serum"), L("category.moisturizer"),
                      "\(L("category.sunscreen")) SPF 50"]
        let details = (1...RoutineFrame.rowCount).map { L("onboarding.anim.step\($0)") }
        let chip = "\(L("onboarding.anim.builtFromScan")) ✦"
        Canvas { context, size in
            let ctx = HeroPaint.designSpace(context, size: size)
            drawSun(degrees: frame.sunDegrees, in: ctx)
            HeroPaint.text(header, size: 10.5, weight: .bold, color: CMColor.ink,
                           at: CGPoint(x: 36, y: 20), anchor: .leading, maxWidth: 150, in: ctx)
            for i in 0..<RoutineFrame.rowCount {
                let opacity = frame.rowOpacity(i)
                guard opacity > 0 else { continue }
                var row = ctx
                row.opacity = opacity
                row.translateBy(x: 12 + frame.rowSlide(i), y: 38 + 42 * CGFloat(i))
                drawRow(i, title: titles[i], detail: details[i], frame: frame, in: row)
            }
            if frame.chipOpacity > 0 {
                var c = ctx
                c.opacity = frame.chipOpacity
                HeroPaint.pill(chip, center: CGPoint(x: 100, y: 220 + frame.chipRise),
                               style: .coral, height: 20, in: c)
            }
        }
    }

    private func drawSun(degrees: Double, in context: GraphicsContext) {
        var c = context
        c.translateBy(x: 22, y: 20)
        c.rotate(by: .degrees(degrees))
        c.fill(HeroPaint.circle(.zero, 4), with: .color(CMColor.primary))
        var rays = Path()
        for k in 0..<8 {
            let angle = Double(k) * .pi / 4
            rays.move(to: CGPoint(x: cos(angle) * 6.4, y: sin(angle) * 6.4))
            rays.addLine(to: CGPoint(x: cos(angle) * 8, y: sin(angle) * 8))
        }
        c.stroke(rays, with: .color(CMColor.primary), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
    }

    /// One step card, drawn in its own 176 × 36 coordinate space.
    private func drawRow(_ i: Int, title: String, detail: String, frame: RoutineFrame, in c: GraphicsContext) {
        let card = Path(roundedRect: CGRect(x: 0, y: 0, width: 176, height: 36), cornerRadius: 10)
        c.fill(card, with: .color(CMColor.surface))
        c.stroke(card, with: .color(CMColor.outline), lineWidth: 1)
        drawProduct(i, in: c)
        HeroPaint.text(title, size: 9, weight: .bold, color: CMColor.ink,
                       at: CGPoint(x: 34, y: 13), anchor: .leading, maxWidth: 112, in: c)
        HeroPaint.text(detail, size: 7.2, weight: .medium, color: CMColor.inkSoft,
                       at: CGPoint(x: 34, y: 25), anchor: .leading, maxWidth: 112, in: c)

        let check = HeroPaint.circle(CGPoint(x: 160, y: 18), 8)
        c.fill(check, with: .color(CMColor.surface))
        c.stroke(check, with: .color(CMColor.outline), lineWidth: 1.5)
        let fill = frame.checkFill(i)
        if fill > 0 {
            c.fill(check, with: .color(CMColor.primary.opacity(fill)))
            c.stroke(check, with: .color(CMColor.primary.opacity(fill)), lineWidth: 1.5)
        }
        let draw = frame.tickDraw(i)
        if draw > 0 {
            var tick = Path()
            tick.move(to: CGPoint(x: 156, y: 18.3))
            tick.addLine(to: CGPoint(x: 158.8, y: 21.1))
            tick.addLine(to: CGPoint(x: 164, y: 15.5))
            c.stroke(tick.trimmedPath(from: 0, to: draw), with: .color(.white),
                     style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
        }
    }

    /// A tiny product glyph per step: cleanser bottle, serum dropper, moisturiser jar, sunscreen tube.
    private func drawProduct(_ i: Int, in c: GraphicsContext) {
        func box(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat, _ color: Color) {
            c.fill(Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: r), with: .color(color))
        }
        switch i {
        case 0:
            box(12, 10, 11, 20, 3, Color(hex: "FFD9C9")); box(14.5, 5, 6, 6, 1.5, CMColor.primary)
        case 1:
            box(13, 12, 9, 18, 4.5, Color(hex: "FFC2AE")); box(15.5, 8, 4, 4, 0, CMColor.primaryDark)
            box(14, 4, 7, 4, 2, CMColor.primaryDark)
        case 2:
            box(10, 14, 15, 14, 4, Color(hex: "FFE7DC")); box(10, 10, 15, 5, 2, Color(hex: "FF9A76"))
        default:
            box(12, 8, 11, 22, 3, Color(hex: "FFB199")); box(12, 15, 11, 6, 0, Color.white.opacity(0.7))
        }
    }
}

#Preview("Routine · built") {
    RoutineHero(t: RoutineFrame.restingT).frame(width: 230, height: 276).background(.white)
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run the Global Constraints test command.
Expected: all 18 tests pass.

- [ ] **Step 5: Commit**

```bash
git add ClearMaxxApp/ClearMaxx/Screens/OnboardingMotion/RoutineHero.swift ClearMaxxApp/ClearMaxxTests/OnboardingMotionTests.swift
git commit -m "iOS: onboarding routine hero: steps build and tick off, each tied to a scan finding"
```

---

### Task 5: Slide 3 (Progress)

**Files:**
- Create: `ClearMaxxApp/ClearMaxx/Screens/OnboardingMotion/ProgressHero.swift`
- Test: `ClearMaxxApp/ClearMaxxTests/OnboardingMotionTests.swift`

**Interfaces:**
- Consumes: `MotionTimeline`, `HeroPaint`, `FaceIllustration` (Tasks 1, 3), keys from Task 2.
- Produces: `struct ProgressFrame` (`init(t: Double)`, `static let startScore = 62`, `static let endScore = 84`, `static let restingT: Double`, `handleX`, `handleOpacity`, `spotsClipX`, `dayOpacity`, `lineDraw`, `dotOpacity`, `dotScale`, `score`) and `struct ProgressHero: View` (`init(t: Double)`).

- [ ] **Step 1: Write the failing tests**

Append inside `OnboardingMotionTests`:

```swift
    // MARK: - Slide 3 · Progress

    func test_progress_startsFromDayOne() {
        let frame = ProgressFrame(t: 0)
        XCTAssertEqual(frame.score, ProgressFrame.startScore)
        XCTAssertEqual(frame.spotsClipX, 170, accuracy: 1e-9, "every spot is still showing")
        XCTAssertEqual(frame.lineDraw, 0, accuracy: 1e-9)
    }

    func test_progress_restingFrame_isTheFinishedBeforeAndAfter() {
        let frame = ProgressFrame(t: ProgressFrame.restingT)
        XCTAssertEqual(frame.score, ProgressFrame.endScore)
        XCTAssertEqual(frame.handleX, 100, accuracy: 1e-9)
        XCTAssertEqual(frame.spotsClipX, 100, accuracy: 1e-9)
        XCTAssertEqual(frame.lineDraw, 1, accuracy: 1e-9)
        XCTAssertEqual(frame.dayOpacity, 1, accuracy: 1e-9)
        XCTAssertEqual(frame.dotOpacity, 1, accuracy: 1e-9)
    }

    func test_progress_spotsAndLineResetBeforeTheLoopSeam() {
        let end = ProgressFrame(t: 0.99)
        XCTAssertEqual(end.spotsClipX, 170, accuracy: 1e-9)
        XCTAssertEqual(end.lineDraw, 0, accuracy: 1e-9)
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run the Global Constraints test command.
Expected: build failure, `cannot find 'ProgressFrame' in scope`.

- [ ] **Step 3: Write `ProgressHero.swift`**

```swift
//
//  ProgressHero.swift
//  ClearMaxx — onboarding slide 3: a before/after wipe across the same face,
//  then the ClearScore line draws itself and the score counts up.
//

import SwiftUI

/// Where everything on the progress slide is at loop position `t`.
struct ProgressFrame {
    static let startScore = 62
    static let endScore = 84
    /// The Reduce Motion frame: before/after split, line drawn, score at 84.
    static let restingT = 0.84
    /// The face is drawn at 54 % scale at the top of the card.
    static let faceOrigin = CGPoint(x: 46, y: 6)
    static let faceScale: CGFloat = 0.54

    let t: Double

    private var travel: Double { MotionTimeline.ramp(t, from: 0.14, to: 0.42) }

    /// The wipe handle slides from the right edge to the centre of the face.
    var handleX: Double { 170 - 70 * travel }
    var handleOpacity: Double { MotionTimeline.window(t, appear: 0.10...0.14, disappear: 0.88...0.94) }

    /// Spots show only left of this x ("Day 1"). It returns to the right edge before the loop seam.
    var spotsClipX: Double { 170 - 70 * (travel - MotionTimeline.ramp(t, from: 0.92, to: 0.98)) }

    var dayOpacity: Double { MotionTimeline.window(t, appear: 0.40...0.46, disappear: 0.88...0.94) }

    /// How much of the ClearScore line is drawn.
    var lineDraw: Double { MotionTimeline.ramp(t, from: 0.44, to: 0.76) - MotionTimeline.ramp(t, from: 0.92, to: 0.98) }

    var dotOpacity: Double { MotionTimeline.window(t, appear: 0.74...0.78, disappear: 0.92...0.98) }
    var dotScale: Double { MotionTimeline.pop(t, from: 0.74, to: 0.81, overshoot: 1.4) }

    var score: Int { MotionTimeline.countUp(t, from: Self.startScore, to: Self.endScore, over: 0.44...0.76) }
}

struct ProgressHero: View {
    let t: Double

    private static let chartPoints = [
        CGPoint(x: 14, y: 216), CGPoint(x: 42, y: 210), CGPoint(x: 70, y: 212), CGPoint(x: 98, y: 199),
        CGPoint(x: 126, y: 190), CGPoint(x: 154, y: 180), CGPoint(x: 186, y: 166),
    ]

    var body: some View {
        let frame = ProgressFrame(t: t)
        let dayOne = L("onboarding.anim.day", 1)
        let dayThirty = L("onboarding.anim.day", 30)
        let score = "\(L("progress.clearScore")) \(frame.score) ↑"
        Canvas { context, size in
            let ctx = HeroPaint.designSpace(context, size: size)
            FaceIllustration.drawFace(in: Self.faceSpace(ctx))
            var before = ctx
            before.clip(to: Path(CGRect(x: 0, y: 0, width: frame.spotsClipX, height: HeroPaint.designSize.height)))
            FaceIllustration.drawSpots(in: Self.faceSpace(before))
            drawHandle(frame, in: ctx)
            if frame.dayOpacity > 0 {
                var days = ctx
                days.opacity = frame.dayOpacity
                HeroPaint.pill(dayOne, center: CGPoint(x: 26, y: 17.5), style: .dark, height: 15, maxWidth: 60, in: days)
                HeroPaint.pill(dayThirty, center: CGPoint(x: 172, y: 17.5), style: .coral, height: 15, maxWidth: 60, in: days)
            }
            drawChart(frame, in: ctx)
            HeroPaint.pill(score, center: CGPoint(x: 56, y: 160), style: .coral, fontSize: 9.5,
                           height: 20, maxWidth: 110, in: ctx)
        }
    }

    /// `context` moved and scaled so the face's own 200 × 240 drawing lands small at the top.
    private static func faceSpace(_ context: GraphicsContext) -> GraphicsContext {
        var c = context
        c.translateBy(x: ProgressFrame.faceOrigin.x, y: ProgressFrame.faceOrigin.y)
        c.scaleBy(x: ProgressFrame.faceScale, y: ProgressFrame.faceScale)
        return c
    }

    private func drawHandle(_ frame: ProgressFrame, in context: GraphicsContext) {
        guard frame.handleOpacity > 0 else { return }
        var c = context
        c.opacity = frame.handleOpacity
        let x = frame.handleX
        var line = Path()
        line.move(to: CGPoint(x: x, y: 4))
        line.addLine(to: CGPoint(x: x, y: 138))
        c.stroke(line, with: .color(.white), lineWidth: 3)
        c.stroke(line, with: .color(CMColor.primary), lineWidth: 1.2)
        let knob = HeroPaint.circle(CGPoint(x: x, y: 72), 8)
        c.fill(knob, with: .color(.white))
        c.stroke(knob, with: .color(CMColor.primary), lineWidth: 2)
        var arrows = Path()
        arrows.move(to: CGPoint(x: x - 2.5, y: 69)); arrows.addLine(to: CGPoint(x: x - 5, y: 72)); arrows.addLine(to: CGPoint(x: x - 2.5, y: 75))
        arrows.move(to: CGPoint(x: x + 2.5, y: 69)); arrows.addLine(to: CGPoint(x: x + 5, y: 72)); arrows.addLine(to: CGPoint(x: x + 2.5, y: 75))
        c.stroke(arrows, with: .color(CMColor.primary), style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
    }

    private func drawChart(_ frame: ProgressFrame, in context: GraphicsContext) {
        var baseline = Path()
        baseline.move(to: CGPoint(x: 14, y: 224))
        baseline.addLine(to: CGPoint(x: 186, y: 224))
        context.stroke(baseline, with: .color(CMColor.outline), lineWidth: 1.5)
        guard frame.lineDraw > 0 else { return }
        var line = Path()
        line.addLines(Self.chartPoints)
        context.stroke(line.trimmedPath(from: 0, to: frame.lineDraw), with: .color(CMColor.primary),
                       style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
        guard frame.dotOpacity > 0, let end = Self.chartPoints.last else { return }
        var dot = context
        dot.opacity = frame.dotOpacity
        dot.fill(HeroPaint.circle(end, 6 * frame.dotScale), with: .color(CMColor.primary.opacity(0.25)))
        dot.fill(HeroPaint.circle(end, 3.4 * frame.dotScale), with: .color(CMColor.primaryDark))
    }
}

#Preview("Progress · before and after") {
    ProgressHero(t: ProgressFrame.restingT).frame(width: 230, height: 276).background(.white)
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run the Global Constraints test command.
Expected: all 21 tests pass.

- [ ] **Step 5: Commit**

```bash
git add ClearMaxxApp/ClearMaxx/Screens/OnboardingMotion/ProgressHero.swift ClearMaxxApp/ClearMaxxTests/OnboardingMotionTests.swift
git commit -m "iOS: onboarding progress hero: before/after wipe, ClearScore line and count-up"
```

---

### Task 6: Put the heroes into the onboarding carousel, and verify on the simulator

**Files:**
- Create: `ClearMaxxApp/ClearMaxx/Screens/OnboardingMotion/OnboardingHero.swift`
- Modify: `ClearMaxxApp/ClearMaxx/Screens/OnboardingView.swift` (whole file shown below)

**Interfaces:**
- Consumes: `ScanHero`, `RoutineHero`, `ProgressHero`, the `restingT` values, `MotionTimeline.progress`, `HeroPaint.designSize`.
- Produces: `enum OnboardingHeroKind { case scan, routine, progress }` with `var restingT: Double`; `struct OnboardingHero: View` (`init(kind: OnboardingHeroKind, isActive: Bool)`).

- [ ] **Step 1: Write `OnboardingHero.swift`**

```swift
//
//  OnboardingHero.swift
//  ClearMaxx — the animated card at the top of each onboarding slide.
//
//  Owns the clock. The visible slide's loop restarts each time it comes into
//  view, so every slide plays its story from the beginning, and slides off
//  screen are paused. Under Reduce Motion there is no loop at all, just the
//  one frame that tells the slide's story.
//

import SwiftUI

enum OnboardingHeroKind: Hashable {
    case scan, routine, progress

    /// The single frame shown under Reduce Motion.
    var restingT: Double {
        switch self {
        case .scan: ScanFrame.restingT
        case .routine: RoutineFrame.restingT
        case .progress: ProgressFrame.restingT
        }
    }
}

struct OnboardingHero: View {
    let kind: OnboardingHeroKind
    let isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var loopStart = Date.now

    var body: some View {
        content
            .aspectRatio(HeroPaint.designSize.width / HeroPaint.designSize.height, contentMode: .fit)
            .frame(maxWidth: 230)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(CMColor.surface))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(CMColor.outline, lineWidth: 1))
            .shadow(color: CMColor.violet.opacity(0.12), radius: 24, y: 10)
            // An illustration: its geometry must not mirror in right-to-left languages.
            .environment(\.layoutDirection, .leftToRight)
            // Decorative. The slide's title and body already say what it shows.
            .accessibilityHidden(true)
            .onChange(of: isActive) { _, active in
                if active { loopStart = .now }
            }
    }

    @ViewBuilder private var content: some View {
        if reduceMotion {
            hero(t: kind.restingT, animated: false)
        } else {
            TimelineView(.animation(paused: !isActive)) { timeline in
                hero(t: MotionTimeline.progress(elapsed: timeline.date.timeIntervalSince(loopStart)),
                     animated: true)
            }
        }
    }

    @ViewBuilder private func hero(t: Double, animated: Bool) -> some View {
        switch kind {
        case .scan: ScanHero(t: t, pulses: animated)
        case .routine: RoutineHero(t: t)
        case .progress: ProgressHero(t: t)
        }
    }
}
```

- [ ] **Step 2: Replace `OnboardingView.swift`**

Three changes: slides carry a hero kind instead of an SF Symbol; the slide id becomes that kind (the old `UUID()` minted new identities on every `body` pass, which would rebuild each hero and reset its clock); and a DEBUG-only launch argument opens straight onto a given slide for screenshots.

```swift
//
//  OnboardingView.swift
//  ClearMaxx — 3-slide intro carousel.
//

import SwiftUI

private struct OnboardSlide: Identifiable {
    let hero: OnboardingHeroKind
    let title: String
    let body: String
    /// Stable across `body` passes, so each slide's hero keeps its clock.
    var id: OnboardingHeroKind { hero }
}

struct OnboardingView: View {
    @ObserveInjection var inject
    @EnvironmentObject var state: AppState
    @State private var page: Int = {
        #if DEBUG
        // Open straight onto a slide for screenshots:
        //   xcrun simctl launch booted com.clearmaxx.app -cmOnboardingPage 2
        return min(max(UserDefaults.standard.integer(forKey: "cmOnboardingPage"), 0), 2)
        #else
        return 0
        #endif
    }()

    private var slides: [OnboardSlide] {
        [
            .init(hero: .scan, title: L("onboarding.slide1.title"),
                  body: L("onboarding.slide1.body")),
            .init(hero: .routine, title: L("onboarding.slide2.title"),
                  body: L("onboarding.slide2.body")),
            .init(hero: .progress, title: L("onboarding.slide3.title"),
                  body: L("onboarding.slide3.body"))
        ]
    }

    var body: some View {
        DewyBackground {
            VStack {
                HStack {
                    ClearMaxxWordmark(size: 22)
                    Spacer()
                    Button(L("common.skip")) { state.stage = .quiz }
                        .font(CMFont.labelMd)
                        .foregroundStyle(CMColor.ink)
                }
                .padding(.horizontal, 24).padding(.top, 8)

                TabView(selection: $page) {
                    ForEach(Array(slides.enumerated()), id: \.element.id) { i, slide in
                        VStack(spacing: 26) {
                            Spacer()
                            OnboardingHero(kind: slide.hero, isActive: page == i)
                            VStack(spacing: 12) {
                                Text(slide.title).font(CMFont.headlineLg).foregroundStyle(CMColor.ink)
                                Text(slide.body)
                                    .font(CMFont.bodyMd)
                                    .foregroundStyle(CMColor.inkSoft)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 30)
                            }
                            Spacer()
                        }
                        .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Custom dots
                HStack(spacing: 8) {
                    ForEach(0..<slides.count, id: \.self) { i in
                        Capsule()
                            .fill(i == page ? AnyShapeStyle(CMGradient.aura) : AnyShapeStyle(CMColor.outline.opacity(0.4)))
                            .frame(width: i == page ? 26 : 8, height: 8)
                            .animation(.spring, value: page)
                    }
                }
                .padding(.bottom, 20)

                AuraButton(title: page < slides.count - 1 ? L("common.next") : L("common.getStarted")) {
                    if page < slides.count - 1 {
                        withAnimation { page += 1 }
                    } else {
                        state.stage = .quiz
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 30)
            }
        }
    }
}

#Preview { OnboardingView().environmentObject(AppState()) }
```

- [ ] **Step 3: Run the whole test suite**

Run from `ClearMaxxApp/`:

```bash
xcodebuild test -project ClearMaxx.xcodeproj -scheme ClearMaxx -destination 'platform=iOS Simulator,id=46C10105-EE20-45D3-B475-53FC676682F8' 2>&1 | grep -E "Executed|error:|\*\* TEST" | tail -5
```

Expected: `** TEST SUCCEEDED **`. Every pre-existing test plus the 21 new ones pass.

- [ ] **Step 4: Build, install, and screenshot every slide on the iPhone 17 Pro**

Run from `ClearMaxxApp/`:

```bash
SIM=46C10105-EE20-45D3-B475-53FC676682F8
xcodebuild -project ClearMaxx.xcodeproj -scheme ClearMaxx -destination "platform=iOS Simulator,id=$SIM" -derivedDataPath build/DerivedData build 2>&1 | tail -1
xcrun simctl install $SIM build/DerivedData/Build/Products/Debug-iphonesimulator/ClearMaxx.app
for P in 0 1 2; do
  xcrun simctl launch --terminate-running-process $SIM com.clearmaxx.app -cm_completed_onboarding NO -cmOnboardingPage $P
  sleep 5   # 2.2 s splash, then ~2.8 s into the loop
  xcrun simctl io $SIM screenshot "$TMPDIR/onboarding-17pro-$P.png"
done
```

Expected: `** BUILD SUCCEEDED **`, then three screenshots. Open each one and check:
- **Slide 0:** face in coral corner brackets with ringed, labelled problems ("Acne", "Redness", "Dark Spots"); title "Smart Scan".
- **Slide 1:** "Your morning ritual" header with rows sliding in or ticked.
- **Slide 2:** the wipe handle mid-face or centred, and the chart drawing.

Also check: no label or pill crosses the card edge; the card is 230 pt wide and sits above the title.

- [ ] **Step 5: Screenshot the smallest screen and the long/RTL languages**

```bash
SE=$(xcrun simctl create "CM iPhone SE" com.apple.CoreSimulator.SimDeviceType.iPhone-SE-3rd-generation com.apple.CoreSimulator.SimRuntime.iOS-26-0 2>/dev/null || xcrun simctl list devices available | grep "iPhone 16e" | grep -oE "[0-9A-F-]{36}" | head -1)
xcrun simctl boot $SE 2>/dev/null; xcrun simctl bootstatus $SE -b >/dev/null
xcrun simctl install $SE build/DerivedData/Build/Products/Debug-iphonesimulator/ClearMaxx.app
xcrun simctl launch --terminate-running-process $SE com.clearmaxx.app -cm_completed_onboarding NO -cmOnboardingPage 0
sleep 5; xcrun simctl io $SE screenshot "$TMPDIR/onboarding-se-0.png"
SIM=46C10105-EE20-45D3-B475-53FC676682F8
for L in de ar; do for P in 0 1 2; do
  xcrun simctl launch --terminate-running-process $SIM com.clearmaxx.app -cm_completed_onboarding NO -cmOnboardingPage $P -cm_language $L
  sleep 5; xcrun simctl io $SIM screenshot "$TMPDIR/onboarding-$L-$P.png"
done; done
```

Expected, checked by opening each screenshot:
- **Small screen:** title, body, page dots and the button all visible with nothing clipped. The hero may shrink.
- **German:** long labels ("Dunkle Flecken", "Für deine Hautbarriere") shrink or shift but stay inside the card.
- **Arabic:** the hero is not mirrored (the face and labels sit exactly as in English); the Arabic text renders correctly. The rest of the screen is mirrored as usual.

If any check fails, fix the placement constant concerned (`labelCenter` in `ScanFrame.markers`, the `maxWidth` passed to `HeroPaint.pill` / `HeroPaint.text`), re-run Steps 3–5, and only then commit.

- [ ] **Step 6: Commit**

```bash
git add ClearMaxxApp/ClearMaxx/Screens/OnboardingMotion/OnboardingHero.swift ClearMaxxApp/ClearMaxx/Screens/OnboardingView.swift
git commit -m "iOS: animated onboarding: scan, routine and progress motion graphics replace the icon tiles"
```
