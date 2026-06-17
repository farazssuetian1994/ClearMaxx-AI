//
//  Models.swift
//  ClearMaxx — data models + app state (mock data for now; swap for API/Core Data later)
//

import SwiftUI

// MARK: - Skin issue / metric

struct SkinMetric: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let value: Int              // 0...100 severity/health score
    let tint: Color
    let blurb: String           // "what this means"
    let ingredients: [String]
}

// MARK: - Routine

enum RoutineTime: String, CaseIterable { case am = "AM Routine", pm = "PM Routine" }

struct RoutineStep: Identifiable, Hashable {
    let id = UUID()
    let index: Int
    let category: String
    let title: String
    let detail: String
    let tags: [String]
    var done: Bool = false
}

// MARK: - Diary

struct DiaryEntry: Identifiable, Hashable {
    let id = UUID()
    let day: String
    let notes: [String]
    let emoji: String
}

// MARK: - App State (single source of truth, injected as @EnvironmentObject)

@MainActor
final class AppState: ObservableObject {
    enum Stage { case splash, onboarding, quiz, main }
    @Published var stage: Stage = .splash
    @Published var hasCompletedOnboarding = false
    @Published var clearScore = 84
    @Published var scanStreak = 12
    @Published var isPremium = false

    // Mock analysis results matching the Stitch results dashboard
    let metrics: [SkinMetric] = [
        .init(name: "Acne", value: 32, tint: CMColor.coral,
              blurb: "Localized breakouts detected in the T-zone. Driven by excess sebum and clogged pores.",
              ingredients: ["Salicylic Acid", "Niacinamide"]),
        .init(name: "Pores", value: 45, tint: CMColor.violet,
              blurb: "Mildly enlarged pores around the nose and cheeks.",
              ingredients: ["Niacinamide", "Retinol"]),
        .init(name: "Hydration", value: 78, tint: Color(hex: "2BB3C0"),
              blurb: "Hydration levels are healthy. Keep sealing in moisture morning and night.",
              ingredients: ["Hyaluronic Acid", "Ceramides"]),
        .init(name: "Dark Spots", value: 28, tint: Color(hex: "B8860B"),
              blurb: "Some post-acne marks (PIH). These fade with consistent SPF and brightening actives.",
              ingredients: ["Vitamin C", "Azelaic Acid"]),
        .init(name: "Redness", value: 40, tint: CMColor.error,
              blurb: "Localized erythema across the cheeks suggesting a compromised skin barrier or mild inflammation.",
              ingredients: ["Centella", "Niacinamide", "Hyaluronic Acid"]),
        .init(name: "Wrinkles", value: 18, tint: CMColor.inkSoft,
              blurb: "Very early fine-line activity. Prevention with SPF and antioxidants is key.",
              ingredients: ["Retinol", "Vitamin C", "Peptides"])
    ]

    func routine(for time: RoutineTime) -> [RoutineStep] {
        switch time {
        case .am:
            return [
                .init(index: 1, category: "Cleanser", title: "Gentle Cloud Foam",
                      detail: "A pH-balanced formula that lifts impurities without stripping your skin's natural barrier.",
                      tags: ["Squalane", "Amino Acids"]),
                .init(index: 2, category: "Vitamin C Serum", title: "Morning Glow Drops",
                      detail: "Potent antioxidant protection to brighten dark spots and shield against pollution.",
                      tags: ["Vitamin C"]),
                .init(index: 3, category: "Moisturizer & SPF", title: "HydraShield SPF 50",
                      detail: "Double-duty hydration with broad-spectrum protection. Lightweight and non-greasy.",
                      tags: ["SPF 50"])
            ]
        case .pm:
            return [
                .init(index: 1, category: "Cleanser", title: "Midnight Melt Balm",
                      detail: "Dissolves sunscreen, makeup and grime so actives absorb cleanly.",
                      tags: ["Squalane"]),
                .init(index: 2, category: "Treatment", title: "Clarifying Night Serum",
                      detail: "Salicylic acid clears congestion while you sleep, reducing breakouts.",
                      tags: ["Salicylic Acid", "Niacinamide"]),
                .init(index: 3, category: "Moisturizer", title: "Barrier Repair Cream",
                      detail: "Ceramide-rich cream locks in hydration and rebuilds the skin barrier overnight.",
                      tags: ["Ceramides", "Hyaluronic Acid"])
            ]
        }
    }

    let recentDiary: [DiaryEntry] = [
        .init(day: "Yesterday", notes: ["8h Sleep", "2.5L Water"], emoji: "✨"),
        .init(day: "Oct 22", notes: ["6h Sleep", "High Stress"], emoji: "💧"),
        .init(day: "Oct 21", notes: ["9h Sleep", "Clean Diet"], emoji: "☀️")
    ]

    let weeklyConsistency: [Double] = [0.35, 0.85, 0.95, 1.0, 0.9, 0.25, 0.2]  // M..S
}
