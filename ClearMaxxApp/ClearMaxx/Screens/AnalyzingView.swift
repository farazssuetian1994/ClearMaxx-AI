//
//  AnalyzingView.swift
//  ClearMaxx — "Analyzing your skin" step: circular photo viewfinder, real
//  upload progress, per-check checklist, and a privacy reassurance card.
//

import SwiftUI

struct AnalyzingView: View {
    @ObserveInjection var inject
    var onDone: () -> Void
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var revealed = false
    /// Crawls 0→~0.98 while we wait on Gemini's response, a phase with no real
    /// progress signal — an asymptotic simulated tick so the pill/ring keep
    /// moving instead of freezing on a spinner, but it never claims 100%
    /// until the scan actually completes.
    @State private var aiPhaseProgress: Double = 0
    @State private var aiPhaseTask: Task<Void, Never>?

    private var checklist: [String] {
        [L("analyzing.check.texture"), L("analyzing.check.pores"),
         L("analyzing.check.spots"), L("analyzing.check.overall")]
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                topBar

                VStack(spacing: 6) {
                    (Text(L("analyzing.titleAccent")).foregroundStyle(CMColor.primary)
                     + Text(L("analyzing.titleRest")).foregroundStyle(CMColor.ink))
                        .font(CMFont.headlineLg)
                    Text(L("analyzing.subtitle"))
                        .font(CMFont.bodyMd).foregroundStyle(CMColor.inkSoft)
                }
                .multilineTextAlignment(.center)
                .padding(.top, 4)

                viewfinder
                    .padding(.top, 28)

                statusPill
                    .padding(.top, 28)

                checklistRow
                    .padding(.top, 22)

                privacyCard
                    .padding(.top, 20)
                    .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(background)
        .navigationBarBackButtonHidden(true)
        .onAppear { state.hideTabBar = true }
        .onDisappear { state.hideTabBar = false; aiPhaseTask?.cancel() }
        .onChange(of: state.uploadProgress) { _, newValue in
            if newValue >= 1.0 { startAIPhaseTicker() }
        }
        .task {
            if let img = state.pendingImage {
                await state.runAnalysis(img, modelContext: modelContext)
                if state.analysisError == nil {
                    aiPhaseTask?.cancel()
                    revealed = true
                    try? await Task.sleep(for: .milliseconds(450))   // let the checkmarks register
                    onDone()
                }
                // on error: the overlay below offers Retry / demo
            } else {
                // No captured image (e.g. demo flow) — show the animation, then mock results.
                startAIPhaseTicker()
                try? await Task.sleep(for: .seconds(2.2))
                aiPhaseTask?.cancel()
                revealed = true
                try? await Task.sleep(for: .milliseconds(450))
                onDone()
            }
        }
        .overlay { if let err = state.analysisError { errorCard(err) } }
    }

    /// Ticks `aiPhaseProgress` toward 0.98 in decaying steps — fast at first,
    /// slowing as it approaches the ceiling — for as long as we're genuinely
    /// still waiting on the server.
    private func startAIPhaseTicker() {
        guard aiPhaseTask == nil else { return }
        aiPhaseTask = Task { @MainActor in
            while !Task.isCancelled && !revealed && aiPhaseProgress < 0.98 {
                try? await Task.sleep(for: .milliseconds(180))
                guard !Task.isCancelled else { return }
                let remaining = 1.0 - aiPhaseProgress
                withAnimation(.easeOut(duration: 0.18)) {
                    aiPhaseProgress = min(0.98, aiPhaseProgress + remaining * 0.06)
                }
            }
        }
    }

    // MARK: Background — the captured photo, softly blurred and lightened

    private var background: some View {
        Group {
            if let img = state.pendingImage {
                Image(uiImage: img).resizable().scaledToFill()
                    .blur(radius: 34)
                    .overlay(Color.white.opacity(0.62))
            } else {
                CMGradient.dewy
            }
        }
        .ignoresSafeArea()
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(CMColor.ink).frame(width: 36, height: 36)
                    .background(.white.opacity(0.85), in: Circle())
            }.buttonStyle(.plain)
            Spacer()
        }
        .padding(.top, 4)
    }

    // MARK: Circular photo viewfinder with corner brackets + progress ring

    /// Real upload fraction mapped to the first 70% of the ring/pill; the
    /// remaining 30% is the simulated AI-processing crawl. Snaps to 1.0 on
    /// completion.
    private var combinedProgress: Double {
        if revealed { return 1.0 }
        if state.uploadProgress < 1.0 { return state.uploadProgress * 0.7 }
        return 0.7 + aiPhaseProgress * 0.3
    }
    private var ringProgress: Double { combinedProgress }

    private var viewfinder: some View {
        ZStack {
            cornerBrackets(size: 290)

            Circle()
                .strokeBorder(style: StrokeStyle(lineWidth: 1.4, dash: [1.5, 7]))
                .foregroundStyle(CMColor.primary.opacity(0.4))
                .frame(width: 266, height: 266)

            Group {
                if let img = state.pendingImage {
                    Image(uiImage: img).resizable().scaledToFill()
                } else {
                    CMGradient.auraDiagonal
                }
            }
            .frame(width: 238, height: 238)
            .clipShape(Circle())
            .overlay(Circle().stroke(.white, lineWidth: 3))
            .shadow(color: .black.opacity(0.12), radius: 16, y: 6)

            Circle()
                .trim(from: 0, to: ringProgress)
                .stroke(CMGradient.aura, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .frame(width: 238, height: 238)
                .rotationEffect(.degrees(-90))
                .shadow(color: CMColor.primary.opacity(0.4), radius: 6)
                .animation(.easeOut(duration: 0.25), value: ringProgress)
        }
        .frame(width: 300, height: 300)
    }

    private func cornerBrackets(size: CGFloat) -> some View {
        let len: CGFloat = 26
        let half = size / 2
        func bracket(rotation: Double, x: CGFloat, y: CGFloat) -> some View {
            Path { p in
                p.move(to: CGPoint(x: 0, y: len))
                p.addLine(to: CGPoint(x: 0, y: 0))
                p.addLine(to: CGPoint(x: len, y: 0))
            }
            .stroke(CMColor.ink.opacity(0.5), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            .frame(width: len, height: len)
            .rotationEffect(.degrees(rotation))
            .offset(x: x, y: y)
        }
        return ZStack {
            bracket(rotation: 0,   x: -half + len / 2, y: -half + len / 2)
            bracket(rotation: 90,  x:  half - len / 2, y: -half + len / 2)
            bracket(rotation: 180, x:  half - len / 2, y:  half - len / 2)
            bracket(rotation: 270, x: -half + len / 2, y:  half - len / 2)
        }
    }

    // MARK: Status pill — sparkle · label · live percentage/spinner/checkmark

    private var statusText: String {
        if revealed { return L("analyzing.statusComplete") }
        if state.uploadProgress < 1.0 { return L("analyzing.statusScanning") }
        return L("analyzing.statusAI")
    }

    private var statusPill: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(CMColor.primary.opacity(0.15)).frame(width: 30, height: 30)
                Image(systemName: "sparkle").font(.system(size: 13, weight: .semibold)).foregroundStyle(CMColor.primary)
            }
            Text(statusText).font(CMFont.labelMd).foregroundStyle(CMColor.ink)
                .lineLimit(1).minimumScaleFactor(0.8)
            Spacer(minLength: 8)
            Group {
                if revealed {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 18)).foregroundStyle(CMColor.success)
                } else {
                    Text("\(Int(combinedProgress * 100))%")
                        .font(CMFont.inter(16, .bold)).foregroundStyle(CMColor.primary)
                        .contentTransition(.numericText())
                        .fixedSize()
                }
            }
            .animation(.easeOut(duration: 0.2), value: combinedProgress)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(.white.opacity(0.85), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.7), lineWidth: 1))
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: Per-check checklist — fills in as the real upload progresses

    private func isChecked(_ index: Int) -> Bool {
        if revealed { return true }
        let thresholds: [Double] = [0.25, 0.5, 0.75]
        guard index < thresholds.count else { return false }
        return state.uploadProgress >= thresholds[index]
    }

    private var checklistRow: some View {
        HStack(spacing: 0) {
            ForEach(Array(checklist.enumerated()), id: \.offset) { i, name in
                let checked = isChecked(i)
                VStack(spacing: 8) {
                    ZStack {
                        Circle().fill(checked ? CMColor.primary.opacity(0.12) : .clear).frame(width: 38, height: 38)
                        Circle().stroke(checked ? CMColor.primary : CMColor.outline.opacity(0.6), lineWidth: 1.5)
                            .frame(width: 38, height: 38)
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(checked ? CMColor.primary : CMColor.outline.opacity(0.7))
                    }
                    Text(name).font(CMFont.labelSm).foregroundStyle(CMColor.inkSoft)
                        .lineLimit(1).minimumScaleFactor(0.75)
                }
                .frame(maxWidth: .infinity)
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: checked)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Privacy reassurance

    private var privacyCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(CMColor.primary.opacity(0.12)).frame(width: 44, height: 44)
                Image(systemName: "lock.shield.fill").foregroundStyle(CMColor.primary).font(.system(size: 18, weight: .semibold))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(L("analyzing.privacyTitle")).font(CMFont.labelMd).foregroundStyle(CMColor.ink)
                Text(L("analyzing.privacyBody")).font(CMFont.labelSm).foregroundStyle(CMColor.inkSoft)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: Error state

    private func errorCard(_ message: String) -> some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 14) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 36)).foregroundStyle(CMColor.coral)
                Text(L("analyzing.errorTitle")).font(CMFont.headlineMd).foregroundStyle(CMColor.ink)
                Text(message).font(CMFont.bodyMd).foregroundStyle(CMColor.inkSoft)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                AuraButton(title: L("common.tryAgain")) { state.analysisError = nil; dismiss() }
                Button(L("analyzing.useDemo")) { state.analysisError = nil; onDone() }
                    .font(CMFont.labelMd).foregroundStyle(CMColor.violetDeep)
            }
            .padding(24)
            .frame(maxWidth: 320)
            .background(.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.25), radius: 24, y: 12)
        }
    }
}

#Preview { NavigationStack { AnalyzingView(onDone: {}) }.environmentObject(AppState()) }
