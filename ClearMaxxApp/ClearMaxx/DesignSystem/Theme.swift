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

enum CMColor {
    static let coral        = Color(hex: "FF7F50")   // primary
    static let coralDeep    = Color(hex: "A43C12")   // primary / wordmark "Clear"
    static let violet       = Color(hex: "8A2BE2")   // secondary
    static let violetDeep   = Color(hex: "821DDA")   // wordmark "Maxx"
    static let ink          = Color(hex: "1C1B1B")   // on-surface text
    static let inkSoft       = Color(hex: "57423B")  // on-surface-variant
    static let surface      = Color(hex: "FCF9F8")   // dewy base
    static let card         = Color.white
    static let cardSoft     = Color(hex: "F6F3F2")
    static let outline      = Color(hex: "DEC0B6")
    static let success      = Color(hex: "168A4A")
    static let error        = Color(hex: "BA1A1A")
}

// MARK: - Gradients

enum CMGradient {
    /// The signature Coral -> Violet "Aura" gradient.
    static let aura = LinearGradient(
        colors: [CMColor.coral, CMColor.violet],
        startPoint: .leading, endPoint: .trailing)

    static let auraDiagonal = LinearGradient(
        colors: [CMColor.coral, CMColor.violet],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    /// Soft peachy-pink -> lavender background wash (never pure white).
    static let dewy = LinearGradient(
        colors: [Color(hex: "FDEDE6"), Color(hex: "FCF9F8"), Color(hex: "F1E9FB")],
        startPoint: .topLeading, endPoint: .bottomTrailing)
}

// MARK: - Typography (Inter, with system fallback)

enum CMFont {
    /// Uses "Inter" if the font files are added to the bundle, otherwise the system font.
    static func inter(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
    static let displayLg  = inter(48, .heavy)
    static let headlineLg = inter(28, .bold)
    static let headlineMd = inter(24, .semibold)
    static let title      = inter(20, .bold)
    static let bodyLg     = inter(18, .regular)
    static let bodyMd     = inter(16, .regular)
    static let labelMd    = inter(14, .semibold)
    static let labelSm    = inter(12, .medium)
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
