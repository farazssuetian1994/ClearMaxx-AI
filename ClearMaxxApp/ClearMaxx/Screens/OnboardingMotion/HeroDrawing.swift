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
