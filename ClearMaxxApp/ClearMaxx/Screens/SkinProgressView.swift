//
//  SkinProgressView.swift
//  ClearMaxx — Progress tab. Real scan history: before/after, ClearScore trend, per-metric deltas.
//

import SwiftUI
import SwiftData

struct SkinProgressView: View {
    @ObserveInjection var inject
    @EnvironmentObject var state: AppState
    @Query(sort: \ScanRecord.date) private var scanRecords: [ScanRecord]
    @State private var slider: CGFloat = 0.5
    @State private var showShare = false

    private var first: ScanRecord? { scanRecords.first }
    private var latest: ScanRecord? { scanRecords.last }
    private var previous: ScanRecord? { scanRecords.count >= 2 ? scanRecords[scanRecords.count - 2] : nil }

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
                        BeforeAfterSlider(value: $slider,
                                          beforeImage: first.flatMap { ScanPhotoStore.load($0.photoFileName) },
                                          afterImage: latest.flatMap { ScanPhotoStore.load($0.photoFileName) })

                        clearScoreTrendCard

                        if scanRecords.count < 2 {
                            emptyState(title: "Scan again to see your trend",
                                       body: "One more scan will start showing how each metric is changing.")
                        } else {
                            metricDeltaCard
                        }

                        AuraButton(title: "Share My Glow-Up", systemImage: "square.and.arrow.up") { showShare = true }
                            .padding(.bottom, 100)
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
                ForEach(latest?.metrics ?? [], id: \.name) { metric in
                    metricRow(metric)
                }
            }
        }
    }

    private func metricRow(_ metric: PersistedMetric) -> some View {
        let prevMetric = previous?.metrics.first(where: { $0.name == metric.name })
        let justResolved = metric.severity == "Good" && prevMetric?.severity != "Good"
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: justResolved ? "checkmark.seal.fill" : "chart.line.uptrend.xyaxis")
                .foregroundStyle(justResolved ? CMColor.success : CMColor.violet)
                .font(.system(size: 18))
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(metric.name).font(CMFont.labelMd).foregroundStyle(CMColor.ink)
                    if justResolved {
                        Text("Cleared 🎉").font(CMFont.labelSm).foregroundStyle(CMColor.success)
                    }
                }
                if let prevValue = prevMetric?.value {
                    let delta = metric.value - prevValue
                    Text("\(prevValue) → \(metric.value) (\(delta >= 0 ? "+" : "")\(delta)) since last scan")
                        .font(CMFont.bodyMd).foregroundStyle(CMColor.inkSoft)
                } else {
                    Text("Value: \(metric.value)").font(CMFont.bodyMd).foregroundStyle(CMColor.inkSoft)
                }
            }
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
        .modelContainer(for: [ScanRecord.self, DailyRoutineChecklist.self], inMemory: true)
}
