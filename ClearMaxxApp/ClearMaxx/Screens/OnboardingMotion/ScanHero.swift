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
