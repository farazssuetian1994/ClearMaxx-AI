//
//  Models.swift
//  ClearMaxx — data models + app state (mock data for now; swap for API/Core Data later)
//

import SwiftUI
import UIKit
import SwiftData

// MARK: - Skin issue / metric

struct SkinMetric: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let value: Int              // 0...100 severity/health score
    let tint: Color
    let blurb: String           // "what this means"
    let ingredients: [String]
    var tips: [String] = []     // per-issue tips (from AI; empty = use defaults)
}

// MARK: - Routine

enum RoutineTime: String, CaseIterable { case am = "AM Routine", pm = "PM Routine" }

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

    // MARK: Live AI analysis (nil until a real scan completes)
    @Published var analysis: SkinAnalysis?
    @Published var isAnalyzing = false
    @Published var analysisError: String?
    @Published var hideTabBar = false
    var pendingImage: UIImage?

    // MARK: Set right after a successful scan, read by the celebration screen
    @Published var newlyResolved: [PersistedMetric] = []
    @Published var celebrationBeforeImage: UIImage?
    @Published var celebrationScoreDelta: Int = 0

    /// Score shown on the results ring — real if available, else the mock baseline.
    var displayScore: Int { analysis?.clearScore ?? clearScore }
    var scanConfidence: Int { analysis?.confidence ?? 98 }

    /// Metrics shown on the dashboard — mapped from the API when present.
    var displayMetrics: [SkinMetric] {
        guard let a = analysis else { return metrics }
        return a.metrics.map { m in
            SkinMetric(name: m.name, value: m.value, tint: Self.tint(for: m.name),
                       blurb: m.summary, ingredients: m.ingredients, tips: m.tips)
        }
    }

    static func tint(for name: String) -> Color {
        switch name {
        case "Acne":         return CMColor.primary
        case "Pores":        return Color(hex: "8A2BE2")
        case "Hydration":    return Color(hex: "2BB3C0")
        case "Dark Spots":   return Color(hex: "B8860B")
        case "Redness":      return CMColor.error
        case "Wrinkles":     return CMColor.inkSoft
        case "Oiliness":     return Color(hex: "E08A2B")
        case "Dark Circles": return Color(hex: "821DDA")
        default:             return CMColor.primary
        }
    }

    /// Runs a real scan against the backend. Updates `analysis` / `analysisError`,
    /// and — on success — persists the scan into SwiftData.
    func runAnalysis(_ image: UIImage, modelContext: ModelContext) async {
        isAnalyzing = true
        analysisError = nil
        newlyResolved = []
        do {
            let result = try await SkinAnalysisService.analyze(image: image)
            analysis = result
            clearScore = result.clearScore   // keep Progress/Profile tabs in sync
            persistScan(image: image, result: result, modelContext: modelContext)
        } catch {
            analysisError = error.localizedDescription
        }
        isAnalyzing = false
    }

    private func persistScan(image: UIImage, result: SkinAnalysis, modelContext: ModelContext) {
        guard let photoFileName = try? ScanPhotoStore.save(image) else {
            print("[AppState] Could not save scan photo — skipping history for this scan.")
            return
        }
        let persistedMetrics = result.metrics.map {
            PersistedMetric(name: $0.name, value: $0.value, severity: $0.severity)
        }

        var previousDescriptor = FetchDescriptor<ScanRecord>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        previousDescriptor.fetchLimit = 1
        let previous = try? modelContext.fetch(previousDescriptor).first

        newlyResolved = ResolutionDiff.newlyResolved(current: persistedMetrics, previous: previous?.metrics)
        celebrationBeforeImage = previous.flatMap { ScanPhotoStore.load($0.photoFileName) }
        celebrationScoreDelta = result.clearScore - (previous?.clearScore ?? result.clearScore)

        let record = ScanRecord(date: Date(), clearScore: result.clearScore, confidence: result.confidence,
                                 skinType: result.skinType, summary: result.summary,
                                 metrics: persistedMetrics, photoFileName: photoFileName)
        modelContext.insert(record)

        upsertTodayChecklist(from: result.routineSteps, modelContext: modelContext)

        do {
            try modelContext.save()
        } catch {
            print("[AppState] Could not save scan history: \(error)")
        }
    }

    /// Regenerates today's checklist from the latest scan's AI routine, preserving
    /// `done` state for any step whose title survives from the prior version of
    /// today's checklist (so a mid-day rescan doesn't wipe checked-off items).
    private func upsertTodayChecklist(from apiSteps: [APIRoutineStep], modelContext: ModelContext) {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        var descriptor = FetchDescriptor<DailyRoutineChecklist>(
            predicate: #Predicate { $0.day == startOfDay })
        descriptor.fetchLimit = 1
        let existing = try? modelContext.fetch(descriptor).first
        // Routine-step titles are AI-generated and not guaranteed unique, so use a
        // duplicate-tolerant initializer (first-wins) instead of `uniqueKeysWithValues`,
        // which traps at runtime if two steps share a title.
        let doneByTitle = Dictionary((existing?.steps ?? []).map { ($0.title, $0.done) }, uniquingKeysWith: { first, _ in first })

        let newSteps = apiSteps.map { step in
            PersistedRoutineStep(time: step.time, category: step.category, title: step.title,
                                  detail: step.detail, tags: step.tags,
                                  done: doneByTitle[step.title] ?? false)
        }

        if let existing {
            existing.steps = newSteps
        } else {
            modelContext.insert(DailyRoutineChecklist(day: startOfDay, steps: newSteps))
        }
    }

    func resetAnalysis() {
        analysis = nil
        analysisError = nil
        pendingImage = nil
        newlyResolved = []
        celebrationBeforeImage = nil
        celebrationScoreDelta = 0
    }

    // Mock analysis results matching the Stitch results dashboard
    let metrics: [SkinMetric] = [
        .init(name: "Acne", value: 32, tint: CMColor.primary,
              blurb: "Localized breakouts detected in the T-zone. Driven by excess sebum and clogged pores.",
              ingredients: ["Salicylic Acid", "Niacinamide"]),
        .init(name: "Pores", value: 45, tint: Color(hex: "8A2BE2"),
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

    let recentDiary: [DiaryEntry] = [
        .init(day: "Yesterday", notes: ["8h Sleep", "2.5L Water"], emoji: "✨"),
        .init(day: "Oct 22", notes: ["6h Sleep", "High Stress"], emoji: "💧"),
        .init(day: "Oct 21", notes: ["9h Sleep", "Clean Diet"], emoji: "☀️")
    ]

    let weeklyConsistency: [Double] = [0.35, 0.85, 0.95, 1.0, 0.9, 0.25, 0.2]  // M..S
}
