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
