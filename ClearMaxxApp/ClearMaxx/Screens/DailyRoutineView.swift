//
//  DailyRoutineView.swift
//  ClearMaxx — Routine tab. AM/PM toggle over today's AI-generated checklist.
//

import SwiftUI
import SwiftData

struct DailyRoutineView: View {
    @ObserveInjection var inject
    @EnvironmentObject var state: AppState
    @State private var time: RoutineTime = .am
    @Query private var checklists: [DailyRoutineChecklist]

    init() {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        _checklists = Query(filter: #Predicate<DailyRoutineChecklist> { $0.day == startOfDay })
    }

    private var todaySteps: [PersistedRoutineStep] { checklists.first?.steps ?? [] }

    private var filteredSteps: [(offset: Int, step: PersistedRoutineStep)] {
        let wanted = time == .am ? "AM" : "PM"
        return Array(todaySteps.enumerated())
            .filter { $0.element.time == wanted }
            .map { (offset: $0.offset, step: $0.element) }
    }

    var body: some View {
        DewyBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Daily Ritual").font(CMFont.headlineLg).foregroundStyle(CMColor.ink)
                        Text("Consistency is the key to that healthy glow.")
                            .font(CMFont.bodyMd).foregroundStyle(CMColor.inkSoft)
                    }

                    // AM/PM segmented toggle
                    HStack(spacing: 0) {
                        ForEach(RoutineTime.allCases, id: \.self) { t in
                            Button { withAnimation { time = t } } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: t == .am ? "sun.max.fill" : "moon.fill")
                                    Text(t.rawValue)
                                }
                                .font(CMFont.labelMd)
                                .foregroundStyle(time == t ? CMColor.violetDeep : CMColor.inkSoft)
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(time == t ? AnyShapeStyle(Color.white) : AnyShapeStyle(Color.clear),
                                            in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(4)
                    .background(CMColor.cardSoft, in: Capsule())

                    if todaySteps.isEmpty {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("No routine yet").font(CMFont.title).foregroundStyle(CMColor.ink)
                                Text("Scan your face to get today's AI-recommended routine.")
                                    .font(CMFont.bodyMd).foregroundStyle(CMColor.inkSoft)
                            }
                        }
                    } else {
                        ForEach(Array(filteredSteps.enumerated()), id: \.element.step.title) { i, entry in
                            RoutineStepCard(index: entry.offset + 1, step: entry.step,
                                            isLast: i == filteredSteps.count - 1) {
                                toggleDone(at: entry.offset)
                            }
                        }
                    }

                    // Weekly consistency — still illustrative, out of scope for this pass.
                    GlassCard {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("Weekly Consistency").font(CMFont.title).foregroundStyle(CMColor.ink)
                                Spacer()
                                Text("85%").font(CMFont.title).foregroundStyle(CMColor.violetDeep)
                            }
                            HStack(alignment: .bottom, spacing: 10) {
                                ForEach(Array(state.weeklyConsistency.enumerated()), id: \.offset) { i, v in
                                    VStack(spacing: 6) {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(v > 0.5 ? AnyShapeStyle(CMGradient.aura) : AnyShapeStyle(CMColor.cardSoft))
                                            .frame(height: 90 * v)
                                        Text(["M","T","W","T","F","S","S"][i])
                                            .font(CMFont.labelSm).foregroundStyle(CMColor.inkSoft)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            }
                            .frame(height: 110, alignment: .bottom)
                        }
                    }
                    .padding(.bottom, 24)
                }
                .padding(.horizontal, 24).padding(.top, 8)
            }
        }
    }

    private func toggleDone(at index: Int) {
        guard let checklist = checklists.first else { return }
        checklist.steps[index].done.toggle()
    }
}

private struct RoutineStepCard: View {
    let index: Int
    let step: PersistedRoutineStep
    let isLast: Bool
    let onToggle: () -> Void

    private var category: (icon: String, tint: Color) { Self.categoryStyle(step.category) }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                ZStack {
                    Circle().fill(.white).frame(width: 40, height: 40)
                        .overlay(Circle().stroke(CMColor.primary.opacity(0.3), lineWidth: 1.5))
                    Text(String(format: "%02d", index))
                        .font(CMFont.labelMd).foregroundStyle(CMColor.coralDeep)
                }
                if !isLast {
                    Rectangle().fill(CMColor.primary.opacity(0.18)).frame(width: 1.5)
                        .frame(maxHeight: .infinity)
                }
            }

            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        CategoryLabel(text: step.category, color: category.tint)
                        Spacer()
                        Button(action: onToggle) {
                            Image(systemName: step.done ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 22))
                                .foregroundStyle(step.done ? CMColor.success : CMColor.outline.opacity(0.6))
                        }.buttonStyle(.plain)
                    }

                    HStack(alignment: .top, spacing: 14) {
                        ZStack {
                            Circle().fill(category.tint.opacity(0.12)).frame(width: 64, height: 64)
                            Image(systemName: category.icon).font(.system(size: 24)).foregroundStyle(category.tint)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(step.title).font(CMFont.title).foregroundStyle(CMColor.ink)
                            Text(step.detail).font(CMFont.bodyMd).foregroundStyle(CMColor.inkSoft)
                        }
                    }

                    if !step.tags.isEmpty {
                        HStack {
                            ForEach(step.tags, id: \.self) { tag in
                                TagChip(text: tag, tint: category.tint, icon: Self.tagIcon(tag))
                            }
                        }
                    }
                }
            }
        }
    }

    /// Best-effort icon+tint from the AI-generated category string — a display
    /// heuristic only, not a fixed enum, since routine categories are free text.
    private static func categoryStyle(_ category: String) -> (icon: String, tint: Color) {
        let c = category.lowercased()
        if c.contains("cleans")                    { return ("bubbles.and.sparkles.fill", CMColor.coralDeep) }
        if c.contains("treat") || c.contains("serum") { return ("eyedropper.full", CMColor.violetDeep) }
        if c.contains("moistur")                    { return ("cylinder.fill", CMColor.success) }
        if c.contains("sun") || c.contains("spf")    { return ("sun.max.fill", Color(hex: "E08A2B")) }
        return ("sparkles", CMColor.coralDeep)
    }

    private static func tagIcon(_ tag: String) -> String {
        let t = tag.lowercased()
        if t.contains("oil")                          { return "drop.fill" }
        if t.contains("fragrance") || t.contains("gentle") || t.contains("strip") { return "leaf.fill" }
        if t.contains("pore")                          { return "circle.grid.3x3.fill" }
        if t.contains("spf") || t.contains("sun")       { return "sun.max.fill" }
        return "sparkle"
    }
}

#Preview {
    DailyRoutineView()
        .environmentObject(AppState())
        .modelContainer(for: [ScanRecord.self, DailyRoutineChecklist.self], inMemory: true)
}
