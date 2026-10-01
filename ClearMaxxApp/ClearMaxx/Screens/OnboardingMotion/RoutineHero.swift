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
