//
//  ScanHistoryDetailView.swift
//  ClearMaxx — read-only replay of one saved scan (same visual language as
//  ResultsDashboardView, but sourced entirely from a persisted ScanRecord).
//

import SwiftUI

struct ScanHistoryDetailView: View {
    @ObserveInjection var inject
    let record: ScanRecord
    @Environment(\.dismiss) private var dismiss

    private let cols = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        DewyBackground {
            ScrollView {
                VStack(spacing: 20) {
                    if let photo = ScanPhotoStore.load(record.photoFileName) {
                        Image(uiImage: photo).resizable().scaledToFill()
                            .frame(height: 220).frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }

                    ScanHeroCard(score: record.clearScore, headline: CMTerms.skinType(record.skinType),
                                 summary: record.summary, confidence: record.confidence)

                    HStack {
                        Text(L("results.metricBreakdown")).font(CMFont.headlineMd).foregroundStyle(CMColor.ink)
                        Spacer()
                        Text(record.date.cmFormatted(date: .abbreviated, time: .shortened))
                            .font(CMFont.labelSm).foregroundStyle(CMColor.inkSoft)
                    }

                    LazyVGrid(columns: cols, spacing: 14) {
                        ForEach(record.metrics, id: \.name) { metric in
                            GlassCard { metricCard(metric) }
                        }
                    }
                }
                .padding(.horizontal, 24).padding(.top, 8).padding(.bottom, 100)
            }
            .safeAreaInset(edge: .top) {
                CMTopBar(showBack: true, onBack: { dismiss() }).background(.ultraThinMaterial)
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    private func metricCard(_ metric: PersistedMetric) -> some View {
        let tint = AppState.tint(for: metric.name)
        return VStack(alignment: .leading, spacing: 10) {
            ZStack {
                Circle().fill(tint.opacity(0.15)).frame(width: 34, height: 34)
                Image(systemName: ResultsDashboardView.icon(for: metric.name))
                    .foregroundStyle(tint).font(.system(size: 15, weight: .semibold))
            }
            MetricBar(label: CMTerms.metric(metric.name), value: metric.value, tint: tint)
        }
    }
}

#Preview {
    NavigationStack {
        ScanHistoryDetailView(record: ScanRecord(
            date: Date(), clearScore: 72, confidence: 91, skinType: "Combination",
            summary: "Your skin shows good potential.",
            metrics: [PersistedMetric(name: "Acne", value: 40, severity: "Mild")],
            photoFileName: ""))
    }
}
