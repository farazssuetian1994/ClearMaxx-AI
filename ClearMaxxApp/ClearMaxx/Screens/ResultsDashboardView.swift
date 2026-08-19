//
//  ResultsDashboardView.swift
//  ClearMaxx — ClearScore hero card + per-issue metric grid + "See Detailed Analysis".
//

import SwiftUI
import SwiftData

struct ResultsDashboardView: View {
    @ObserveInjection var inject
    @EnvironmentObject var state: AppState
    var onIssue: (SkinMetric) -> Void = { _ in }
    var onRescan: () -> Void = {}
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ScanRecord.date) private var scanRecords: [ScanRecord]

    private let cols = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    private var latestRecord: ScanRecord? { scanRecords.last }
    private var previousRecord: ScanRecord? { scanRecords.count >= 2 ? scanRecords[scanRecords.count - 2] : nil }
    private var score: Int { latestRecord?.clearScore ?? state.displayScore }

    /// Real delta vs. the previous scan — nil when there isn't one yet (first-ever scan).
    private var scoreDelta: Int? {
        guard let previous = previousRecord else { return nil }
        return score - previous.clearScore
    }

    private var deltaBadge: (text: String, tint: Color)? {
        guard let delta = scoreDelta, let previous = previousRecord, previous.clearScore > 0 else { return nil }
        let pct = abs(Double(delta)) / Double(previous.clearScore) * 100
        let pctText = String(format: "%.1f", pct)
        if delta > 0 { return (L("results.improving", pctText), CMColor.success) }
        if delta < 0 { return (L("results.down", pctText), CMColor.error) }
        return (L("results.steady"), CMColor.inkSoft)
    }

    private var headline: String {
        guard let delta = scoreDelta else { return L("results.headlineFirst") }
        if delta > 0 { return L("results.headlineUp") }
        if delta < 0 { return L("results.headlineDown") }
        return L("results.headlineFlat")
    }

    var body: some View {
        DewyBackground {
            ScrollView {
                VStack(spacing: 20) {
                    ScanHeroCard(score: score, badge: deltaBadge, headline: headline,
                                 summary: state.analysis?.summary, confidence: state.scanConfidence)
                        .padding(.top, 8)

                    HStack {
                        Text(L("results.metricBreakdown")).font(CMFont.headlineMd).foregroundStyle(CMColor.ink)
                        Spacer()
                    }

                    // Metric grid
                    LazyVGrid(columns: cols, spacing: 14) {
                        ForEach(state.displayMetrics) { m in
                            Button { onIssue(m) } label: {
                                GlassCard { metricCard(m) }
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    TipCard(title: L("results.tipTitle"),
                            message: L("results.tipBody"))

                    AuraButton(title: L("results.seeDetailed"), systemImage: "sparkles") {
                        if let first = state.displayMetrics.first { onIssue(first) }
                    }

                    Button(action: onRescan) {
                        Text(L("results.rescan")).font(CMFont.labelMd).foregroundStyle(CMColor.violetDeep)
                    }
                    .padding(.bottom, 90)
                }
                .padding(.horizontal, 24)
            }
            .safeAreaInset(edge: .top) {
                CMTopBar(showBack: true, onBack: { dismiss() }).background(.ultraThinMaterial)
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    private func metricCard(_ m: SkinMetric) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                Circle().fill(m.tint.opacity(0.15)).frame(width: 34, height: 34)
                Image(systemName: Self.icon(for: m.name)).foregroundStyle(m.tint).font(.system(size: 15, weight: .semibold))
            }
            MetricBar(label: CMTerms.metric(m.name), value: m.value, tint: m.tint)
        }
    }

    static func icon(for name: String) -> String {
        switch name {
        case "Acne":         return "circle.grid.3x3.fill"
        case "Pores":        return "circle.hexagongrid.fill"
        case "Hydration":    return "drop.fill"
        case "Dark Spots":   return "sun.max.fill"
        case "Redness":      return "waveform.path.ecg"
        case "Wrinkles":     return "water.waves"
        case "Oiliness":     return "drop.triangle.fill"
        case "Dark Circles": return "eye.fill"
        default:             return "sparkles"
        }
    }
}

#Preview {
    NavigationStack { ResultsDashboardView() }
        .environmentObject(AppState())
        .modelContainer(for: [ScanRecord.self, DailyRoutineChecklist.self], inMemory: true)
}
