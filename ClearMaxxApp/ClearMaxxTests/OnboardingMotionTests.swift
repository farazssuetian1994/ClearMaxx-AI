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

    private static func catalog(_ code: String) throws -> [String: String] {
        let url = try XCTUnwrap(Bundle.main.url(forResource: code, withExtension: "json")
            ?? Bundle.main.url(forResource: code, withExtension: "json", subdirectory: "Locales"),
            "no catalog for \(code)")
        return try JSONDecoder().decode([String: String].self, from: Data(contentsOf: url))
    }
}
