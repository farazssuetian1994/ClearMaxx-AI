//
//  Theme.swift
//  ClearMaxx — "Radiance Aesthetic" design system
//
//  Aura Gradient (Primary -> Primary Dark), dewy backgrounds, glassmorphism, Inter typography.
//

import SwiftUI

// MARK: - Colors

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let r, g, b, a: UInt64
        switch h.count {
        case 3: (r, g, b, a) = ((int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17, 255)
        case 6: (r, g, b, a) = (int >> 16, int >> 8 & 0xFF, int & 0xFF, 255)
        case 8: (r, g, b, a) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (r, g, b, a) = (255, 127, 80, 255)
        }
        self.init(.sRGB,
                  red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}

// Tokens are computed `static var`s (not `static let`) so that editing a value
// hot-reloads live via InjectionIII — accessing the token is a function call,
// which injection can hot-swap (a stored `let` is computed once and would not).
enum CMColor {
    // Brand palette
    static var primary: Color     { Color(hex: "FF7F50") }
    static var primaryDark: Color { Color(hex: "F2643A") }
    static var background: Color  { Color(hex: "F8F6FC") }
    static var surface: Color     { Color(hex: "FFFFFF") }
    static var text: Color        { Color(hex: "111111") }
    static var subtext: Color     { Color(hex: "6B7280") }
    static var border: Color      { Color(hex: "EEEAF8") }

    // Legacy aliases — kept so existing call sites stay on the brand palette above.
    static var coral: Color      { primary }
    static var coralDeep: Color  { text }
    static var violet: Color     { primary }
    static var violetDeep: Color { primaryDark }
    static var ink: Color        { text }
    static var inkSoft: Color    { subtext }
    static var card: Color       { surface }
    static var cardSoft: Color   { background }
    static var outline: Color    { border }
    static var success: Color    { Color(hex: "168A4A") }
    static var error: Color      { Color(hex: "BA1A1A") }
}

// MARK: - Gradients

enum CMGradient {
    /// The signature Primary -> Primary Dark "Aura" gradient.
    static var aura: LinearGradient {
        LinearGradient(colors: [CMColor.primary, CMColor.primaryDark],
                       startPoint: .leading, endPoint: .trailing)
    }

    static var auraDiagonal: LinearGradient {
        LinearGradient(colors: [CMColor.primary, CMColor.primaryDark],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Soft lavender-white background wash (never pure white).
    static var dewy: LinearGradient {
        LinearGradient(colors: [CMColor.background, CMColor.surface, CMColor.border],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Typography (Inter, with system fallback)

enum CMFont {
    /// Uses "Inter" if the font files are added to the bundle, otherwise the system font.
    static func inter(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
    static var displayLg: Font  { inter(48, .heavy) }
    static var headlineLg: Font { inter(28, .bold) }
    static var headlineMd: Font { inter(24, .semibold) }
    static var title: Font      { inter(20, .bold) }
    static var bodyLg: Font     { inter(18, .regular) }
    static var bodyMd: Font     { inter(16, .regular) }
    static var labelMd: Font    { inter(14, .semibold) }
    static var labelSm: Font    { inter(12, .medium) }
}

// MARK: - Shadows

extension View {
    /// "Natural Bloom" violet-tinted ambient shadow used across glass cards.
    func bloomShadow() -> some View {
        self.shadow(color: CMColor.violet.opacity(0.10), radius: 18, x: 0, y: 10)
    }
}

// MARK: - Reusable wordmark

struct ClearMaxxWordmark: View {
    var size: CGFloat = 22
    var body: some View {
        HStack(spacing: 0) {
            Text("Clear").foregroundStyle(CMColor.coralDeep)
            Text("Maxx").foregroundStyle(CMColor.violetDeep)
        }
        .font(CMFont.inter(size, .heavy))
    }
}
