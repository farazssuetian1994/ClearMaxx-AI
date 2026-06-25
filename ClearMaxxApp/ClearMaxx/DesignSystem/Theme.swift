//
//  Theme.swift
//  ClearMaxx — "Radiance Aesthetic" design system
//
//  Aura Gradient (Coral -> Violet), dewy backgrounds, glassmorphism, Inter typography.
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
    static var coral: Color      { Color(hex: "FF7F50") }   // primary
    static var coralDeep: Color  { Color(hex: "A43C12") }   // primary / wordmark "Clear"
    static var violet: Color     { Color(hex: "8A2BE2") }   // secondary
    static var violetDeep: Color { Color(hex: "821DDA") }   // wordmark "Maxx"
    static var ink: Color        { Color(hex: "1C1B1B") }   // on-surface text
    static var inkSoft: Color    { Color(hex: "57423B") }   // on-surface-variant
    static var surface: Color    { Color(hex: "FCF9F8") }   // dewy base
    static var card: Color       { Color.white }
    static var cardSoft: Color   { Color(hex: "F6F3F2") }
    static var outline: Color    { Color(hex: "DEC0B6") }
    static var success: Color    { Color(hex: "168A4A") }
    static var error: Color      { Color(hex: "BA1A1A") }
}

// MARK: - Gradients

enum CMGradient {
    /// The signature Coral -> Violet "Aura" gradient.
    static var aura: LinearGradient {
        LinearGradient(colors: [CMColor.coral, CMColor.violet],
                       startPoint: .leading, endPoint: .trailing)
    }

    static var auraDiagonal: LinearGradient {
        LinearGradient(colors: [CMColor.coral, CMColor.violet],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Soft peachy-pink -> lavender background wash (never pure white).
    static var dewy: LinearGradient {
        LinearGradient(colors: [Color(hex: "FDEDE6"), Color(hex: "FCF9F8"), Color(hex: "F1E9FB")],
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
