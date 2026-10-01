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
