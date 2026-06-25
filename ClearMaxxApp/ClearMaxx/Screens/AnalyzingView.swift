//
//  AnalyzingView.swift
//  ClearMaxx — animated "Analyzing your skin…" step with progress + checklist.
//

import SwiftUI

struct AnalyzingView: View {
    @ObserveInjection var inject
    var onDone: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var progress = 0
    @State private var sweep = false
    @State private var finished = false
    private let steps = ["Texture mapping complete",
                         "Detecting hydration levels…",
                         "Cross-referencing 50,000+ data points"]

    private let timer = Timer.publish(every: 0.03, on: .main, in: .common).autoconnect()

    var body: some View {
        DewyBackground {
            VStack(spacing: 24) {
                CMTopBar(showBack: true, onBack: { dismiss() })

                ZStack {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(CMGradient.auraDiagonal)
                        .frame(height: 320)
                        .overlay(
                            Image(systemName: "face.smiling")
                                .font(.system(size: 120, weight: .ultraLight))
                                .foregroundStyle(.white.opacity(0.85)))
                        .overlay(scanline)
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            CategoryLabel(text: "AI Analysis", color: .white)
                            Spacer()
                            ScoreRing(score: progress, size: 52, lineWidth: 5, caption: "")
                        }
                        Text("Processing… \(progress)%")
                            .font(CMFont.headlineMd).foregroundStyle(.white)
                    }
                    .padding(18)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .padding(20)
                }
                .padding(.horizontal, 24)

                VStack(spacing: 8) {
                    Text("Analyzing your skin…").font(CMFont.headlineLg).foregroundStyle(CMColor.ink)
                    Text("Please stay still. Our AI is cross-referencing your profile with 50,000+ clinical dermatological data points.")
                        .font(CMFont.bodyMd).foregroundStyle(CMColor.inkSoft)
                        .multilineTextAlignment(.center).padding(.horizontal, 30)
                }

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { i, s in
                        let reached = progress > i * 33
                        HStack(spacing: 10) {
                            Image(systemName: reached ? "checkmark.circle.fill" : "circle.dotted")
                                .foregroundStyle(reached ? CMColor.success : CMColor.outline)
                            Text(s).font(CMFont.bodyMd)
                                .foregroundStyle(reached ? CMColor.ink : CMColor.inkSoft.opacity(0.6))
                        }
                    }
                }
                .padding(.horizontal, 40)
                Spacer()
            }
        }
        .navigationBarBackButtonHidden(true)
        .onReceive(timer) { _ in
            guard !finished else { return }
            if progress < 100 { progress += 1 }
            else {
                finished = true
                timer.upstream.connect().cancel()
                onDone()
            }
        }
        .onAppear { withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: true)) { sweep = true } }
    }

    private var scanline: some View {
        Rectangle()
            .fill(LinearGradient(colors: [.clear, .white.opacity(0.7), .clear], startPoint: .top, endPoint: .bottom))
            .frame(height: 60)
            .offset(y: sweep ? 120 : -120)
            .blendMode(.screen)
    }
}

#Preview { NavigationStack { AnalyzingView(onDone: {}) } }
