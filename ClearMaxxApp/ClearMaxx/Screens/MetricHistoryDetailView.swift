//
//  MetricHistoryDetailView.swift
//  ClearMaxx — full history for one metric: a real chart + every past value,
//  sourced entirely from persisted ScanRecords (opened from the Progress tab).
//

import SwiftUI
import Charts

struct MetricHistoryDetailView: View {
    @ObserveInjection var inject
    let metricName: String
    let scanRecords: [ScanRecord]
    @Environment(\.dismiss) private var dismiss

    private var tint: Color { AppState.tint(for: metricName) }
    private var icon: String { ResultsDashboardView.icon(for: metricName) }

    private var series: [(date: Date, value: Int, severity: String)] {
        scanRecords.compactMap { record in
            guard let m = record.metrics.first(where: { $0.name == metricName }) else { return nil }
            return (record.date, m.value, m.severity)
        }
    }

    var body: some View {
        DewyBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle().fill(tint.opacity(0.15)).frame(width: 48, height: 48)
                            Image(systemName: icon).foregroundStyle(tint).font(.system(size: 20, weight: .semibold))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(metricName).font(CMFont.headlineLg).foregroundStyle(CMColor.ink)
                            if let latest = series.last {
                                Text("\(latest.value) · \(latest.severity)").font(CMFont.labelMd).foregroundStyle(CMColor.inkSoft)
                            }
                        }
                    }
                    .padding(.top, 8)

                    if series.count >= 2 {
                        GlassCard {
                            Chart(Array(series.enumerated()), id: \.offset) { _, point in
                                LineMark(x: .value("Scan", point.date), y: .value("Value", point.value))
                                    .foregroundStyle(tint)
                                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                                PointMark(x: .value("Scan", point.date), y: .value("Value", point.value))
                                    .foregroundStyle(tint)
                            }
                            .chartYScale(domain: 0...100)
                            .frame(height: 160)
                        }
                    }

                    GlassCard {
                        VStack(spacing: 0) {
                            ForEach(Array(series.reversed().enumerated()), id: \.offset) { index, point in
                                HStack {
                                    Text(point.date.formatted(date: .abbreviated, time: .shortened))
                                        .font(CMFont.bodyMd).foregroundStyle(CMColor.ink)
                                    Spacer()
                                    Text(point.severity).font(CMFont.labelSm).foregroundStyle(CMColor.inkSoft)
                                    Text("\(point.value)").font(CMFont.labelMd).foregroundStyle(tint)
                                        .frame(width: 36, alignment: .trailing)
                                }
                                .padding(.vertical, 10)
                                if index < series.count - 1 { Divider().overlay(CMColor.outline.opacity(0.25)) }
                            }
                        }
                    }
                }
                .padding(.horizontal, 24).padding(.bottom, 40)
            }
            .safeAreaInset(edge: .top) {
                CMTopBar(showBack: true, onBack: { dismiss() }).background(.ultraThinMaterial)
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}

#Preview {
    NavigationStack {
        MetricHistoryDetailView(metricName: "Acne", scanRecords: [])
    }
}
