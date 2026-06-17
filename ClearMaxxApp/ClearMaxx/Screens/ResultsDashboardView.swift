//
//  ResultsDashboardView.swift
//  ClearMaxx — ClearScore ring + per-issue metric grid + "See Detailed Analysis".
//

import SwiftUI

struct ResultsDashboardView: View {
    @EnvironmentObject var state: AppState
    var onIssue: (SkinMetric) -> Void = { _ in }
    var onRescan: () -> Void = {}
    @Environment(\.dismiss) private var dismiss

    private let cols = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        DewyBackground {
            ScrollView {
                VStack(spacing: 20) {
                    // Score ring + delta
                    VStack(spacing: 8) {
                        ScoreRing(score: state.clearScore, size: 150, lineWidth: 14)
                        TagChip(text: "▲ Improving (+4.2%)", tint: CMColor.success)
                    }
                    .padding(.top, 8)

                    HStack {
                        Text("Visual Analysis").font(CMFont.headlineMd).foregroundStyle(CMColor.ink)
                        Spacer()
                    }

                    // Face + heatmap placeholder
                    GlassCard(padding: 0) {
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(CMGradient.auraDiagonal).frame(height: 200)
                                .overlay(Image(systemName: "face.dashed")
                                    .font(.system(size: 90, weight: .ultraLight)).foregroundStyle(.white.opacity(0.8)))
                            HStack {
                                Image(systemName: "checkmark.seal.fill").foregroundStyle(CMColor.success)
                                Text("AI scan complete (98% confidence)").font(CMFont.labelMd).foregroundStyle(CMColor.ink)
                            }
                            .padding(10).frame(maxWidth: .infinity)
                            .background(.ultraThinMaterial)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }

                    // Metric grid
                    LazyVGrid(columns: cols, spacing: 14) {
                        ForEach(state.metrics) { m in
                            Button { onIssue(m) } label: {
                                GlassCard {
                                    MetricBar(label: m.name, value: m.value, tint: m.tint)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    AuraButton(title: "See Detailed Analysis", systemImage: "sparkles") {
                        if let first = state.metrics.first { onIssue(first) }
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
}

#Preview { NavigationStack { ResultsDashboardView() }.environmentObject(AppState()) }
