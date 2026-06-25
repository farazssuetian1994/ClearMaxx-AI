//
//  DailyRoutineView.swift
//  ClearMaxx — Routine tab. AM/PM toggle, numbered steps, weekly consistency chart.
//

import SwiftUI

struct DailyRoutineView: View {
    @ObserveInjection var inject
    @EnvironmentObject var state: AppState
    @State private var time: RoutineTime = .am
    @State private var steps: [RoutineStep] = []

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
                            Button { withAnimation { time = t; loadSteps() } } label: {
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

                    // Steps
                    ForEach($steps) { $step in
                        RoutineStepCard(step: $step)
                    }

                    // Weekly consistency
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
                    .padding(.bottom, 100)
                }
                .padding(.horizontal, 24).padding(.top, 8)
            }
        }
        .onAppear { if steps.isEmpty { loadSteps() } }
    }

    private func loadSteps() { steps = state.routine(for: time) }
}

private struct RoutineStepCard: View {
    @Binding var step: RoutineStep
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle().stroke(CMColor.violet.opacity(0.3), lineWidth: 1.5).frame(width: 40, height: 40)
                Text(String(format: "%02d", step.index))
                    .font(CMFont.labelMd).foregroundStyle(CMColor.violetDeep)
            }
            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        CategoryLabel(text: step.category, color: CMColor.coralDeep)
                        Spacer()
                        Button { step.done.toggle() } label: {
                            Image(systemName: step.done ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 22))
                                .foregroundStyle(step.done ? CMColor.success : CMColor.outline.opacity(0.6))
                        }.buttonStyle(.plain)
                    }
                    Text(step.title).font(CMFont.title).foregroundStyle(CMColor.ink)
                    Text(step.detail).font(CMFont.bodyMd).foregroundStyle(CMColor.inkSoft)
                    HStack {
                        ForEach(step.tags, id: \.self) { TagChip(text: $0) }
                    }
                }
            }
        }
    }
}

#Preview { DailyRoutineView().environmentObject(AppState()) }
