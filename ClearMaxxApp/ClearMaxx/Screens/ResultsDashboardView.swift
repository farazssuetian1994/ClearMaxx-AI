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
        if delta > 0 { return ("▲ Improving (+\(pctText)%)", CMColor.success) }
        if delta < 0 { return ("▼ Down (\(pctText)%)", CMColor.error) }
        return ("● Steady", .white)
    }

    private var headline: String {
        guard let delta = scoreDelta else { return "Nice first scan!" }
        if delta > 0 { return "Good progress!" }
        if delta < 0 { return "Stay consistent" }
        return "Holding steady"
    }

    var body: some View {
        DewyBackground {
            ScrollView {
                VStack(spacing: 20) {
                    heroCard.padding(.top, 8)

                    HStack {
                        Text("Metric Breakdown").font(CMFont.headlineMd).foregroundStyle(CMColor.ink)
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

                    AuraButton(title: "See Detailed Analysis", systemImage: "sparkles") {
                        if let first = state.displayMetrics.first { onIssue(first) }
                    }

                    Button(action: onRescan) {
                        Text("Re-scan").font(CMFont.labelMd).foregroundStyle(CMColor.violetDeep)
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

    // MARK: - Hero card: coral gradient, white ring, real trend badge

    private var heroCard: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(CMGradient.auraDiagonal)

            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 18) {
                    whiteScoreRing

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.seal.fill")
                            Text("AI scan complete").font(CMFont.labelSm).fontWeight(.semibold)
                        }
                        .foregroundStyle(CMColor.primaryDark)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(.white, in: Capsule())

                        if let badge = deltaBadge {
                            Text(badge.text).font(CMFont.inter(11, .bold)).foregroundStyle(badge.tint)
                                .padding(.horizontal, 10).padding(.vertical, 4)
                                .background(.white.opacity(0.25), in: Capsule())
                        }
                    }
                }

                Text(headline).font(CMFont.headlineMd).foregroundStyle(.white)

                if let summary = state.analysis?.summary, !summary.isEmpty {
                    Text(summary)
                        .font(CMFont.bodyMd).foregroundStyle(.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(22)
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: CMColor.primary.opacity(0.35), radius: 20, y: 10)
    }

    private var whiteScoreRing: some View {
        let progress = Double(max(0, min(100, score))) / 100
        return ZStack {
            Circle().stroke(.white.opacity(0.3), lineWidth: 12)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(.white, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(score)").font(CMFont.inter(34, .heavy)).foregroundStyle(.white)
                Text("CLEARSCORE").font(CMFont.inter(9, .bold)).tracking(1).foregroundStyle(.white.opacity(0.85))
            }
        }
        .frame(width: 108, height: 108)
    }

    // MARK: - Metric card with icon badge

    private func metricCard(_ m: SkinMetric) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                Circle().fill(m.tint.opacity(0.15)).frame(width: 34, height: 34)
                Image(systemName: Self.icon(for: m.name)).foregroundStyle(m.tint).font(.system(size: 15, weight: .semibold))
            }
            MetricBar(label: m.name, value: m.value, tint: m.tint)
        }
    }

    private static func icon(for name: String) -> String {
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
