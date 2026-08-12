//
//  SkinProgressView.swift
//  ClearMaxx — Progress tab. Real scan history: before/after, ClearScore trend, per-metric deltas.
//

import SwiftUI
import SwiftData

struct SkinProgressView: View {
    @ObserveInjection var inject
    @EnvironmentObject var state: AppState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ScanRecord.date) private var scanRecords: [ScanRecord]
    @Query private var progressCaches: [ProgressReportCache]
    @Query private var todayChecklist: [DailyRoutineChecklist]
    @State private var slider: CGFloat = 0.5
    @State private var showShare = false
    @State private var showPaywall = false
    @State private var isAnalyzingProgress = false
    @State private var progressReport: ProgressReport?
    @State private var showProgressReport = false
    @State private var progressAnalysisError: String?

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
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(CMGradient.aura, in: Capsule())
                    }

                    if scanRecords.isEmpty {
                        emptyState(title: "No scans yet",
                                   body: "Scan your face to start tracking your skin's progress.")
                    } else {
                        beforeAfterCard

                        clearScoreTrendCard

                        if scanRecords.count < 2 {
                            emptyState(title: "Scan again to see your trend",
                                       body: "One more scan will start showing how each metric is changing.")
                        } else {
                            metricDeltaCard
                        }

                        progressAnalysisSection

                        AuraButton(title: "Share My Glow-Up", systemImage: "square.and.arrow.up") { showShare = true }
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
        BeforeAfterSlider(value: $slider,
                          beforeImage: first.flatMap { ScanPhotoStore.load($0.photoFileName) },
                          afterImage: latest.flatMap { ScanPhotoStore.load($0.photoFileName) })
            .overlay(alignment: .bottom) {
                if let first, let latest {
                    let delta = latest.clearScore - first.clearScore
                    VStack(spacing: 2) {
                        Text(delta >= 0 ? "+\(delta) ClearScore" : "\(delta) ClearScore")
                            .font(CMFont.inter(24, .heavy)).foregroundStyle(.white)
                        Text("since your first scan")
                            .font(CMFont.labelSm).foregroundStyle(.white.opacity(0.9))
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(CMGradient.aura.opacity(0.92))
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
                        Text("ClearScore").font(CMFont.title).foregroundStyle(CMColor.ink)
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
                                  ? AnyShapeStyle(CMGradient.aura) : AnyShapeStyle(CMColor.outline.opacity(0.35)))
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
    }

    private var metricDeltaCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Metric Progress").font(CMFont.headlineMd).foregroundStyle(CMColor.ink)
                let rows = latest?.metrics ?? []
                ForEach(Array(rows.enumerated()), id: \.element.name) { index, metric in
                    metricRow(metric)
                    if index < rows.count - 1 {
                        Divider().overlay(CMColor.outline.opacity(0.25))
                    }
                }
            }
        }
    }

    private func metricRow(_ metric: PersistedMetric) -> some View {
        let prevMetric = previous?.metrics.first(where: { $0.name == metric.name })
        let justResolved = metric.severity == "Good" && prevMetric?.severity != "Good"
        let curRank = SeverityRank.rank(metric.severity)
        let prevRank = prevMetric.map { SeverityRank.rank($0.severity) }
        let icon: String
        let tint: Color
        switch (justResolved, prevRank) {
        case (true, _):
            icon = "checkmark.seal.fill"; tint = CMColor.success
        case (false, .some(let p)) where curRank < p:
            icon = "arrow.down.circle.fill"; tint = CMColor.success
        case (false, .some(let p)) where curRank > p:
            icon = "arrow.up.circle.fill"; tint = CMColor.error
        case (false, .some):
            icon = "minus.circle.fill"; tint = CMColor.inkSoft
        case (false, .none):
            icon = "chart.line.uptrend.xyaxis"; tint = CMColor.violet
        }

        return HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(tint.opacity(0.15)).frame(width: 34, height: 34)
                Image(systemName: icon).foregroundStyle(tint).font(.system(size: 15, weight: .semibold))
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
                    Text("\(prevValue) → \(metric.value) (\(delta >= 0 ? "+" : "")\(delta)) since last scan")
                        .font(CMFont.bodyMd).foregroundStyle(tint)
                } else {
                    Text("Value: \(metric.value)").font(CMFont.bodyMd).foregroundStyle(CMColor.inkSoft)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var progressAnalysisSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Analyze My Progress").font(CMFont.title).foregroundStyle(CMColor.ink)

                switch eligibility {
                case .notEnoughScans:
                    Text("Scan at least twice to see whether it's working.")
                        .font(CMFont.bodyMd).foregroundStyle(CMColor.inkSoft)
                case .tooRecentSpan(let daysRemaining):
                    Text("Your scans span less than a week — give your skin \(daysRemaining) more day\(daysRemaining == 1 ? "" : "s") before checking progress.")
                        .font(CMFont.bodyMd).foregroundStyle(CMColor.inkSoft)
                case .eligible:
                    if let progressAnalysisError {
                        Text(progressAnalysisError).font(CMFont.bodyMd).foregroundStyle(CMColor.error)
                    }
                    AuraButton(title: isAnalyzingProgress ? "Analyzing…" : "Analyze My Progress",
                              systemImage: "sparkles") {
                        Task { await requestProgressAnalysis() }
                    }
                    .disabled(isAnalyzingProgress)
                }
            }
        }
        .sheet(isPresented: $showPaywall) { GoPremiumView() }
        .sheet(isPresented: $showProgressReport) {
            if let progressReport { ProgressReportView(report: progressReport) }
        }
    }

    @MainActor
    private func requestProgressAnalysis() async {
        guard case .eligible(let trend) = eligibility else { return }
        guard state.isPremium else {
            showPaywall = true
            return
        }
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
