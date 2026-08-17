//
//  SkinProgressView.swift
//  ClearMaxx — Progress tab. Real scan history: before/after, ClearScore trend, per-metric deltas.
//

import SwiftUI
import SwiftData
import Charts

struct SkinProgressView: View {
    @ObserveInjection var inject
    @EnvironmentObject var state: AppState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ScanRecord.date) private var scanRecords: [ScanRecord]
    @Query private var progressCaches: [ProgressReportCache]
    @Query private var todayChecklist: [DailyRoutineChecklist]
    @State private var slider: CGFloat = 0.5
    @State private var showShare = false
    @State private var isAnalyzingProgress = false
    @State private var progressReport: ProgressReport?
    @State private var showProgressReport = false
    @State private var progressAnalysisError: String?
    @State private var showClearScoreInfo = false
    @State private var selectedMetricName: String?

    // `todayChecklist` needs a predicate, so every other @Query on this view
    // must also be assigned explicitly here (SwiftData requires all @Query
    // properties to be set together once any one of them gets a custom init) —
    // same pattern DailyRoutineView already uses for its own filtered query.
    init() {
        _scanRecords = Query(sort: \ScanRecord.date)
        _progressCaches = Query()
        let startOfDay = Calendar.current.startOfDay(for: Date())
        _todayChecklist = Query(filter: #Predicate<DailyRoutineChecklist> { $0.day == startOfDay })
    }

    private var first: ScanRecord? { scanRecords.first }
    private var latest: ScanRecord? { scanRecords.last }
    private var previous: ScanRecord? { scanRecords.count >= 2 ? scanRecords[scanRecords.count - 2] : nil }
    private var eligibility: ProgressEligibility { ProgressTrendCalculator.eligibility(for: scanRecords) }

    /// The routine actually on the user's checklist today (persists across
    /// launches), not `state.analysis` — which is only populated in-memory
    /// right after a scan and is `nil` again the next time the app opens.
    private var currentRoutineForAnalysis: [APIRoutineStep] {
        (todayChecklist.first?.steps ?? []).map {
            APIRoutineStep(time: $0.time, category: $0.category, title: $0.title,
                           detail: $0.detail, tags: $0.tags)
        }
    }

    var body: some View {
        DewyBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Your Journey").font(CMFont.labelMd).foregroundStyle(CMColor.inkSoft)
                            Text("Skin Evolution").font(CMFont.headlineLg).foregroundStyle(CMColor.ink)
                        }
                        Spacer()
                        HStack(spacing: 6) {
                            Image(systemName: "flame.fill")
                            Text("\(state.scanStreak) Day Streak!").font(CMFont.labelMd)
                        }
                        .foregroundStyle(CMColor.coralDeep)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(CMColor.primary.opacity(0.12), in: Capsule())
                    }

                    if scanRecords.isEmpty {
                        emptyState(title: "No scans yet",
                                   body: "Scan your face to start tracking your skin's progress.")
                    } else {
                        beforeAfterCard

                        clearScoreTrendCard

                        TipCard(title: "Keep going!", message: "Consistency is the key to glowing skin.")

                        if scanRecords.count < 2 {
                            emptyState(title: "Scan again to see your trend",
                                       body: "One more scan will start showing how each metric is changing.")
                        } else {
                            metricDeltaCard
                        }

                        progressAnalysisSection

                        actionRow(icon: "square.and.arrow.up", title: "Share My Glow-Up",
                                  subtitle: "Share your progress with friends") { showShare = true }
                            .padding(.bottom, 24)
                    }
                }
                .padding(.horizontal, 24).padding(.top, 8)
            }
        }
        .sheet(isPresented: $showShare) {
            GlowUpShareView(
                beforeImage: first.flatMap { ScanPhotoStore.load($0.photoFileName) },
                afterImage: latest.flatMap { ScanPhotoStore.load($0.photoFileName) },
                scoreDelta: (latest?.clearScore ?? 0) - (first?.clearScore ?? 0))
        }
    }

    private var beforeAfterCard: some View {
        VStack(spacing: 0) {
            BeforeAfterSlider(value: $slider,
                              beforeImage: first.flatMap { ScanPhotoStore.load($0.photoFileName) },
                              afterImage: latest.flatMap { ScanPhotoStore.load($0.photoFileName) })

            if let first, let latest {
                let delta = latest.clearScore - first.clearScore
                VStack(spacing: 2) {
                    Text(delta >= 0 ? "+\(delta) ClearScore" : "\(delta) ClearScore")
                        .font(CMFont.inter(22, .heavy)).foregroundStyle(CMColor.coralDeep)
                    Text("since your first scan")
                        .font(CMFont.labelSm).foregroundStyle(CMColor.inkSoft)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(CMColor.primary.opacity(0.1))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .bloomShadow()
    }

    private var clearScoreTrendCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading) {
                        HStack(spacing: 4) {
                            Text("ClearScore").font(CMFont.title).foregroundStyle(CMColor.ink)
                            Button { showClearScoreInfo = true } label: {
                                Image(systemName: "info.circle").font(.system(size: 13)).foregroundStyle(CMColor.inkSoft)
                            }
                            .buttonStyle(.plain)
                        }
                        if let first, let latest {
                            let delta = latest.clearScore - first.clearScore
                            Text(delta >= 0 ? "+\(delta) since your first scan" : "\(delta) since your first scan")
                                .font(CMFont.labelSm).foregroundStyle(delta >= 0 ? CMColor.success : CMColor.error)
                        }
                    }
                    Spacer()
                    Text("\(latest?.clearScore ?? state.clearScore)")
                        .font(CMFont.inter(40, .heavy)).foregroundStyle(CMColor.coralDeep)
                }
                HStack(alignment: .bottom, spacing: 6) {
                    let recent = Array(scanRecords.suffix(8))
                    ForEach(Array(recent.enumerated()), id: \.offset) { i, record in
                        RoundedRectangle(cornerRadius: 5)
                            .fill(i == recent.count - 1
                                  ? AnyShapeStyle(CMGradient.aura) : AnyShapeStyle(CMColor.primary.opacity(0.15)))
                            .frame(height: max(8, CGFloat(record.clearScore) * 0.9))
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 100, alignment: .bottom)
                HStack {
                    Text(first?.date.formatted(date: .abbreviated, time: .omitted) ?? "")
                        .font(CMFont.inter(9, .semibold)).foregroundStyle(CMColor.inkSoft)
                    Spacer()
                    Text("TODAY").font(CMFont.inter(9, .semibold)).foregroundStyle(CMColor.inkSoft)
                }
            }
        }
        .alert("What's ClearScore?", isPresented: $showClearScoreInfo) {
            Button("Got it", role: .cancel) {}
        } message: {
            Text("A 0–100 summary of your overall skin health, calculated by the AI from all 8 metrics on your most recent scan.")
        }
    }

    private var metricDeltaCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 4) {
                Text("Metric Progress").font(CMFont.headlineMd).foregroundStyle(CMColor.ink)
                Text("Track how your skin is evolving").font(CMFont.bodyMd).foregroundStyle(CMColor.inkSoft)
                    .padding(.bottom, 10)
                let rows = latest?.metrics ?? []
                ForEach(Array(rows.enumerated()), id: \.element.name) { index, metric in
                    Button { selectedMetricName = metric.name } label: { metricRow(metric) }
                        .buttonStyle(.plain)
                    if index < rows.count - 1 {
                        Divider().overlay(CMColor.outline.opacity(0.25))
                    }
                }
            }
        }
        .sheet(isPresented: Binding(get: { selectedMetricName != nil }, set: { if !$0 { selectedMetricName = nil } })) {
            if let name = selectedMetricName {
                NavigationStack { MetricHistoryDetailView(metricName: name, scanRecords: scanRecords) }
            }
        }
    }

    /// Real per-metric value history across every scan — feeds the sparkline.
    private func series(for metricName: String) -> [(date: Date, value: Int)] {
        scanRecords.compactMap { record in
            guard let m = record.metrics.first(where: { $0.name == metricName }) else { return nil }
            return (record.date, m.value)
        }
    }

    private func metricRow(_ metric: PersistedMetric) -> some View {
        let prevMetric = previous?.metrics.first(where: { $0.name == metric.name })
        let justResolved = metric.severity == "Good" && prevMetric?.severity != "Good"
        let curRank = SeverityRank.rank(metric.severity)
        let prevRank = prevMetric.map { SeverityRank.rank($0.severity) }
        // Icon badge always shows this metric's own identity color/glyph (matching
        // the Results Dashboard and Scan History), independent of trend direction.
        let metricTint = AppState.tint(for: metric.name)
        let metricIcon = ResultsDashboardView.icon(for: metric.name)
        // The delta pill is colored separately, by whether this scan is better/worse.
        let trendTint: Color
        switch (justResolved, prevRank) {
        case (true, _):                                     trendTint = CMColor.success
        case (false, .some(let p)) where curRank < p:        trendTint = CMColor.success
        case (false, .some(let p)) where curRank > p:        trendTint = CMColor.error
        case (false, .some):                                 trendTint = CMColor.inkSoft
        case (false, .none):                                 trendTint = CMColor.inkSoft
        }

        return HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle().fill(metricTint.opacity(0.15)).frame(width: 34, height: 34)
                Image(systemName: metricIcon).foregroundStyle(metricTint).font(.system(size: 15, weight: .semibold))
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(metric.name).font(CMFont.labelMd).foregroundStyle(CMColor.ink)
                    if justResolved {
                        Text("Cleared 🎉").font(CMFont.inter(11, .bold)).foregroundStyle(.white)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(CMColor.success, in: Capsule())
                    }
                }
                if let prevValue = prevMetric?.value {
                    let delta = metric.value - prevValue
                    HStack(spacing: 4) {
                        Text("\(prevValue) → \(metric.value)").font(CMFont.bodyMd).foregroundStyle(CMColor.inkSoft)
                        Text("\(delta > 0 ? "↑" : (delta < 0 ? "↓" : "—")) \(abs(delta))")
                            .font(CMFont.inter(11, .bold)).foregroundStyle(trendTint)
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(trendTint.opacity(0.15), in: Capsule())
                    }
                } else {
                    Text("Value: \(metric.value)").font(CMFont.bodyMd).foregroundStyle(CMColor.inkSoft)
                }
            }
            Spacer(minLength: 8)
            let points = series(for: metric.name)
            if points.count >= 2 {
                sparkline(points, tint: metricTint)
            }
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(CMColor.outline)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    /// - Catmull-Rom needs neighboring points to compute its curve tangents;
    ///   with exactly 2 points it has none, and Charts' boundary handling
    ///   produces a sharp curl right at the last point (reproducibly, even
    ///   for a perfectly flat 2-point series). Below 4 points, linear
    ///   interpolation is the only one that can't misrender — it degrades to
    ///   a plain straight segment, which is also the mathematically honest
    ///   representation of "we only have 2 data points."
    /// - `chartYScale(domain: 0...100)` is likewise load-bearing: without it
    ///   Charts auto-scales per-chart from just the 2-3 local points, which
    ///   can degenerate visually when values are close or identical.
    private func sparkline(_ points: [(date: Date, value: Int)], tint: Color) -> some View {
        Chart(Array(points.enumerated()), id: \.offset) { _, point in
            AreaMark(x: .value("Scan", point.date), y: .value("Value", point.value))
                .foregroundStyle(LinearGradient(colors: [tint.opacity(0.25), tint.opacity(0)],
                                                 startPoint: .top, endPoint: .bottom))
                .interpolationMethod(points.count >= 4 ? .catmullRom : .linear)
            LineMark(x: .value("Scan", point.date), y: .value("Value", point.value))
                .foregroundStyle(tint)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .interpolationMethod(points.count >= 4 ? .catmullRom : .linear)
        }
        .chartYScale(domain: 0...100)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .frame(width: 64, height: 32)
    }

    private func actionRow(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        GlassCard {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(CMColor.primary.opacity(0.12)).frame(width: 44, height: 44)
                    Image(systemName: icon).foregroundStyle(CMColor.coralDeep).font(.system(size: 18, weight: .semibold))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(CMFont.labelMd).foregroundStyle(CMColor.ink)
                    Text(subtitle).font(CMFont.labelSm).foregroundStyle(CMColor.inkSoft)
                }
                Spacer(minLength: 8)
                Button(action: action) {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                        .frame(width: 40, height: 34)
                        .background(CMGradient.aura, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var progressAnalysisSection: some View {
        switch eligibility {
        case .notEnoughScans:
            GlassCard {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Analyze My Progress").font(CMFont.title).foregroundStyle(CMColor.ink)
                    Text("Scan at least twice to see whether it's working.")
                        .font(CMFont.bodyMd).foregroundStyle(CMColor.inkSoft)
                }
            }
        case .tooRecentSpan(let daysRemaining):
            GlassCard {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Analyze My Progress").font(CMFont.title).foregroundStyle(CMColor.ink)
                    Text("Your scans span less than a week — give your skin \(daysRemaining) more day\(daysRemaining == 1 ? "" : "s") before checking progress.")
                        .font(CMFont.bodyMd).foregroundStyle(CMColor.inkSoft)
                }
            }
        case .eligible:
            VStack(alignment: .leading, spacing: 8) {
                actionRow(icon: "sparkles",
                          title: isAnalyzingProgress ? "Analyzing…" : "Analyze My Progress",
                          subtitle: "Get AI insights and personalized tips") {
                    Task { await requestProgressAnalysis() }
                }
                .disabled(isAnalyzingProgress)
                if let progressAnalysisError {
                    Text(progressAnalysisError).font(CMFont.bodyMd).foregroundStyle(CMColor.error)
                }
            }
            .sheet(isPresented: $showProgressReport) {
                if let progressReport { ProgressReportView(report: progressReport) }
            }
        }
    }

    @MainActor
    private func requestProgressAnalysis() async {
        guard case .eligible(let trend) = eligibility else { return }
        guard let latest else { return }

        if let cached = progressCaches.first(where: { $0.latestScanDate == latest.date }) {
            progressReport = cached.report
            showProgressReport = true
            return
        }

        progressAnalysisError = nil
        isAnalyzingProgress = true
        defer { isAnalyzingProgress = false }

        do {
            let firstImage = first.flatMap { ScanPhotoStore.downscaled($0.photoFileName, maxEdge: 768) }
            let latestImage = ScanPhotoStore.downscaled(latest.photoFileName, maxEdge: 768)
            let report = try await ProgressAnalysisService.analyze(
                trend: trend, firstImage: firstImage, latestImage: latestImage,
                currentRoutine: currentRoutineForAnalysis)

            // A structurally-valid-but-empty report (blank headline/narrative) can
            // result from a degenerate model response — never cache or show that;
            // treat it the same as a thrown error so the user gets a retry path.
            guard !report.headline.isEmpty, !report.narrative.isEmpty else {
                throw ProgressAnalysisError.unknown
            }

            for existing in progressCaches {
                modelContext.delete(existing)
            }
            let cache = ProgressReportCache(latestScanDate: latest.date, report: report)
            modelContext.insert(cache)
            try? modelContext.save()

            progressReport = report
            showProgressReport = true
        } catch {
            progressAnalysisError = error.localizedDescription
        }
    }

    private func emptyState(title: String, body: String) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(CMFont.title).foregroundStyle(CMColor.ink)
                Text(body).font(CMFont.bodyMd).foregroundStyle(CMColor.inkSoft)
            }
        }
    }
}

// Draggable before/after comparison
struct BeforeAfterSlider: View {
    @Binding var value: CGFloat
    var beforeImage: UIImage? = nil
    var afterImage: UIImage? = nil

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .leading) {
                beforeLayer
                    .overlay(Text("BEFORE").font(CMFont.inter(10, .bold)).foregroundStyle(.white)
                        .padding(6).background(.black.opacity(0.4), in: Capsule()).padding(10),
                             alignment: .topLeading)
                afterLayer
                    .overlay(Text("AFTER").font(CMFont.inter(10, .bold)).foregroundStyle(.white)
                        .padding(6).background(.black.opacity(0.3), in: Capsule()).padding(10),
                             alignment: .topTrailing)
                    .mask(HStack { Spacer().frame(width: w * value); Rectangle() })
                // handle — only this narrow strip is draggable, so vertical
                // scrolling on the rest of the image passes through to the ScrollView.
                ZStack {
                    Color.clear
                        .frame(width: 60)
                        .frame(maxHeight: .infinity)
                        .contentShape(Rectangle())
                    Circle().fill(.white).frame(width: 36, height: 36)
                        .overlay(Image(systemName: "arrow.left.and.right").foregroundStyle(CMColor.ink))
                        .bloomShadow()
                }
                .offset(x: w * value - 30)
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .named("beforeAfter"))
                        .onChanged { value = max(0, min(1, $0.location.x / w)) }
                )
            }
            .coordinateSpace(name: "beforeAfter")
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .frame(height: 260)
    }

    @ViewBuilder private var beforeLayer: some View {
        if let beforeImage {
            Image(uiImage: beforeImage).resizable().scaledToFill()
        } else {
            LinearGradient(colors: [Color(hex: "C98F6A"), Color(hex: "9A6A4A")], startPoint: .top, endPoint: .bottom)
        }
    }

    @ViewBuilder private var afterLayer: some View {
        if let afterImage {
            Image(uiImage: afterImage).resizable().scaledToFill()
        } else {
            CMGradient.auraDiagonal
        }
    }
}

#Preview {
    SkinProgressView()
        .environmentObject(AppState())
        .modelContainer(for: [ScanRecord.self, DailyRoutineChecklist.self, ProgressReportCache.self], inMemory: true)
}
