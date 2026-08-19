//
//  CMLocale.swift
//  ClearMaxx — app-wide localization.
//
//  Mirrors the ChartSense i18n model, adapted to SwiftUI:
//    * flat `key -> string` JSON catalogs, one per language, bundled as resources
//    * device-language auto-detection on first launch (a user in France opens the
//      app already in French), persisted so it stays put afterwards
//    * an explicit in-app override from Profile → Language
//    * English is always loaded as the fallback catalog, so a key missing from a
//      translation renders in English rather than as a raw key.
//
//  Every user-facing string in the app goes through `L("some.key")`.
//

import SwiftUI

// MARK: - Supported languages

struct CMLanguage: Identifiable, Hashable {
    let code: String
    /// Endonym — the language's own name, always rendered in its own script.
    let nativeName: String
    /// Key for its English name, translated into the *current* language.
    var nameKey: String { "language.\(code)" }
    var id: String { code }
    /// Right-to-left scripts need the whole layout mirrored.
    var isRTL: Bool { code == "ar" }
}

enum CMLanguages {
    static let all: [CMLanguage] = [
        .init(code: "en", nativeName: "English"),
        .init(code: "zh", nativeName: "中文 (简体)"),
        .init(code: "es", nativeName: "Español"),
        .init(code: "ar", nativeName: "العربية"),
        .init(code: "hi", nativeName: "हिन्दी"),
        .init(code: "ja", nativeName: "日本語"),
        .init(code: "ko", nativeName: "한국어"),
        .init(code: "fr", nativeName: "Français"),
        .init(code: "de", nativeName: "Deutsch"),
        .init(code: "pt", nativeName: "Português"),
        .init(code: "tr", nativeName: "Türkçe"),
        .init(code: "ru", nativeName: "Русский"),
    ]

    static let codes: [String] = all.map(\.code)

    static func language(for code: String) -> CMLanguage {
        all.first { $0.code == code } ?? all[0]
    }
}

// MARK: - Manager

/// Not `@MainActor`: `L(...)` is called from `LocalizedError.errorDescription`,
/// which is `nonisolated`. The catalogs are only ever mutated from the main
/// thread (the Language screen), and reads are plain dictionary lookups.
final class CMLocale: ObservableObject, @unchecked Sendable {
    static let shared = CMLocale()

    private static let storageKey = "cm_language"

    @Published private(set) var language: String

    private var strings: [String: String] = [:]
    private var fallback: [String: String] = [:]

    private init() {
        let saved = UserDefaults.standard.string(forKey: Self.storageKey)
        let code = (saved.flatMap { CMLanguages.codes.contains($0) ? $0 : nil }) ?? Self.deviceLanguage()
        language = code
        UserDefaults.standard.set(code, forKey: Self.storageKey)
        fallback = Self.loadCatalog("en")
        strings = code == "en" ? fallback : Self.loadCatalog(code)
    }

    /// The language this device is set to, collapsed onto a supported code.
    /// `zh-Hans-CN` → `zh`, `pt-BR` → `pt`, `es-419` → `es`, anything we don't
    /// ship → English.
    static func deviceLanguage() -> String {
        for identifier in Locale.preferredLanguages {
            let base = identifier.split(separator: "-").first.map(String.init)?.lowercased()
            if let base, CMLanguages.codes.contains(base) { return base }
        }
        return "en"
    }

    private static func loadCatalog(_ code: String) -> [String: String] {
        // Synchronized-folder projects flatten resources into the bundle root,
        // but check the subdirectory too so this keeps working if the JSON is
        // ever added as a folder reference instead.
        let url = Bundle.main.url(forResource: code, withExtension: "json")
            ?? Bundle.main.url(forResource: code, withExtension: "json", subdirectory: "Locales")
        guard let url,
              let data = try? Data(contentsOf: url),
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else {
            print("[CMLocale] Missing or unreadable catalog for \(code) — falling back to English.")
            return [:]
        }
        return dict
    }

    func setLanguage(_ code: String) {
        guard CMLanguages.codes.contains(code), code != language else { return }
        strings = code == "en" ? fallback : Self.loadCatalog(code)
        UserDefaults.standard.set(code, forKey: Self.storageKey)
        language = code
    }

    var current: CMLanguage { CMLanguages.language(for: language) }

    /// Foundation locale for the chosen language — drives date/number formatting
    /// so `Date.formatted(...)` renders month names in the same language as the UI.
    var foundationLocale: Locale { Locale(identifier: language) }

    var layoutDirection: LayoutDirection { current.isRTL ? .rightToLeft : .leftToRight }

    // MARK: Lookup

    func t(_ key: String) -> String {
        strings[key] ?? fallback[key] ?? key
    }

    /// Substitutes `{0}`, `{1}`, … placeholders. Deliberately not
    /// `String(format:)`: a translator typo in a `%d` can crash that at runtime,
    /// while an unmatched `{0}` here just renders literally.
    func t(_ key: String, _ args: [String]) -> String {
        var out = t(key)
        for (i, arg) in args.enumerated() {
            out = out.replacingOccurrences(of: "{\(i)}", with: arg)
        }
        return out
    }
}

// MARK: - Global shorthand

func L(_ key: String) -> String { CMLocale.shared.t(key) }
func L(_ key: String, _ args: String...) -> String { CMLocale.shared.t(key, args) }
func L(_ key: String, _ args: Int...) -> String { CMLocale.shared.t(key, args.map(String.init)) }

// MARK: - Canonical value translation
//
// Metric names, severities and skin types stay in canonical English end to end
// (they key colors/icons, drive severity ranking, and are persisted in
// SwiftData + sent to the backend). They're translated only at the moment of
// display, so switching language re-labels history that's already on disk.

enum CMTerms {
    private static let metricKeys: [String: String] = [
        "Acne": "metric.acne",
        "Pores": "metric.pores",
        "Hydration": "metric.hydration",
        "Dark Spots": "metric.darkSpots",
        "Redness": "metric.redness",
        "Wrinkles": "metric.wrinkles",
        "Oiliness": "metric.oiliness",
        "Dark Circles": "metric.darkCircles",
    ]

    private static let severityKeys: [String: String] = [
        "Good": "severity.good",
        "Mild": "severity.mild",
        "Moderate": "severity.moderate",
        "Severe": "severity.severe",
    ]

    private static let skinTypeKeys: [String: String] = [
        "Oily": "skinType.oily",
        "Dry": "skinType.dry",
        "Combination": "skinType.combination",
        "Normal": "skinType.normal",
        "Sensitive": "skinType.sensitive",
    ]

    private static let goalKeys: [String: String] = [
        "Clear Acne": "goal.clearAcne",
        "Anti-Aging": "goal.antiAging",
        "Ultimate Glow": "goal.ultimateGlow",
    ]

    /// Routine-step categories: the backend pins these to canonical English so
    /// `RoutineStepCard.categoryStyle` can keep matching on them for the icon
    /// and tint. Only the visible label is translated.
    private static let routineCategoryKeys: [String: String] = [
        "Cleanser": "category.cleanser",
        "Toner": "category.toner",
        "Eye Cream": "category.eyeCream",
        "Treatment": "category.treatment",
        "Serum": "category.serum",
        "Moisturizer": "category.moisturizer",
        "Sunscreen": "category.sunscreen",
        "Mask": "category.mask",
        "Exfoliant": "category.exfoliant",
    ]

    private static let concernKeys: [String: String] = [
        "Acne": "concern.acne",
        "Dark Spots": "concern.darkSpots",
        "Redness": "concern.redness",
        "Large Pores": "concern.largePores",
        "Dryness": "concern.dryness",
        "Wrinkles": "concern.wrinkles",
    ]

    /// Falls back to the raw value: the backend can in principle return a metric
    /// name we don't have a key for, and showing it beats showing nothing.
    static func metric(_ name: String) -> String { metricKeys[name].map(L) ?? name }
    static func severity(_ value: String) -> String { severityKeys[value].map(L) ?? value }
    static func skinType(_ value: String) -> String { skinTypeKeys[value].map(L) ?? value }
    static func goal(_ value: String) -> String { goalKeys[value].map(L) ?? value }
    static func concern(_ value: String) -> String { concernKeys[value].map(L) ?? value }
    static func routineCategory(_ value: String) -> String { routineCategoryKeys[value].map(L) ?? value }
}

// MARK: - Locale-aware dates

extension Date {
    /// `Date.formatted(date:time:)` always renders in the *system* locale, which
    /// would leave month names in English after the user picks another language
    /// in-app. This routes through the chosen language instead.
    func cmFormatted(date: Date.FormatStyle.DateStyle, time: Date.FormatStyle.TimeStyle) -> String {
        formatted(Date.FormatStyle(date: date, time: time).locale(CMLocale.shared.foundationLocale))
    }
}
