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

enum RoutineTime: String, CaseIterable {
    case am, pm
    /// "AM"/"PM" stay canonical in persistence; only the label is translated.
    var label: String { self == .am ? L("routine.am") : L("routine.pm") }
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
    @Published var isPremium = false

    // MARK: Live AI analysis (nil until a real scan completes)
    @Published var analysis: SkinAnalysis?
    @Published var isAnalyzing = false
    @Published var analysisError: String?
    @Published var hideTabBar = false
    /// Real bytes-sent fraction for the in-flight scan upload (0...1). 1.0 means
    /// "uploaded, now waiting on the AI" — there's no signal for that server-side phase.
    @Published var uploadProgress: Double = 0
    var pendingImage: UIImage?

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
        uploadProgress = 0
        do {
            let result = try await SkinAnalysisService.analyze(image: image, profile: SkinProfileStore.load()) { [weak self] progress in
                Task { @MainActor in self?.uploadProgress = progress }
            }
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

    /// Replaces today's routine checklist with the AI's progress-adapted
    /// steps, preserving `done` state exactly like a normal rescan would
    /// (via `upsertTodayChecklist`'s existing title-matching behavior).
    func applyUpdatedRoutine(_ steps: [APIRoutineStep], modelContext: ModelContext) {
        upsertTodayChecklist(from: steps, modelContext: modelContext)
        do {
            try modelContext.save()
        } catch {
            print("[AppState] Could not save updated routine: \(error)")
        }
    }

    func resetAnalysis() {
        analysis = nil
        analysisError = nil
        pendingImage = nil
    }

    /// Syncs `isPremium` with RevenueCat on launch (e.g. restored subscription from a prior install).
    func refreshPremiumStatus() async {
        isPremium = await PurchaseService.shared.refreshEntitlement()
    }

    // Demo analysis results — shown only when a real scan hasn't landed yet
    // (e.g. the "Use demo results" fallback on the Analyzing screen).
    var metrics: [SkinMetric] {
        [
            .init(name: "Acne", value: 32, tint: CMColor.primary,
                  blurb: L("demo.acne.blurb"),
                  ingredients: [L("ingredient.salicylicAcid"), L("ingredient.niacinamide")]),
            .init(name: "Pores", value: 45, tint: Color(hex: "8A2BE2"),
                  blurb: L("demo.pores.blurb"),
                  ingredients: [L("ingredient.niacinamide"), L("ingredient.retinol")]),
            .init(name: "Hydration", value: 78, tint: Color(hex: "2BB3C0"),
                  blurb: L("demo.hydration.blurb"),
                  ingredients: [L("ingredient.hyaluronicAcid"), L("ingredient.ceramides")]),
            .init(name: "Dark Spots", value: 28, tint: Color(hex: "B8860B"),
                  blurb: L("demo.darkSpots.blurb"),
                  ingredients: [L("ingredient.vitaminC"), L("ingredient.azelaicAcid")]),
            .init(name: "Redness", value: 40, tint: CMColor.error,
                  blurb: L("demo.redness.blurb"),
                  ingredients: [L("ingredient.centella"), L("ingredient.niacinamide"), L("ingredient.hyaluronicAcid")]),
            .init(name: "Wrinkles", value: 18, tint: CMColor.inkSoft,
                  blurb: L("demo.wrinkles.blurb"),
                  ingredients: [L("ingredient.retinol"), L("ingredient.vitaminC"), L("ingredient.peptides")])
        ]
    }

    var recentDiary: [DiaryEntry] {
        [
            .init(day: L("diary.yesterday"), notes: [L("diary.sleep8h"), L("diary.water25l")], emoji: "✨"),
            .init(day: L("diary.day2"), notes: [L("diary.sleep6h"), L("diary.highStress")], emoji: "💧"),
            .init(day: L("diary.day3"), notes: [L("diary.sleep9h"), L("diary.cleanDiet")], emoji: "☀️")
        ]
    }

    let weeklyConsistency: [Double] = [0.35, 0.85, 0.95, 1.0, 0.9, 0.25, 0.2]  // M..S
}
