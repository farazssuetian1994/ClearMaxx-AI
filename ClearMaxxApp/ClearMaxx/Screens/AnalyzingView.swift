//
//  AnalyzingView.swift
//  ClearMaxx — animated "Analyzing your skin…" step with progress + checklist.
//

import SwiftUI

struct AnalyzingView: View {
    @ObserveInjection var inject
    var onDone: () -> Void
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var progress = 0
    @State private var sweep = false
    @State private var revealed = false

    private let timer = Timer.publish(every: 0.03, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // Captured face (or a dark gradient if none)
            Group {
                if let img = state.pendingImage {
                    Image(uiImage: img).resizable().scaledToFill()
                } else {
                    LinearGradient(colors: [Color(hex: "2A2330"), Color(hex: "14101A")],
                                   startPoint: .top, endPoint: .bottom)
                }
            }
            .ignoresSafeArea()
            .overlay(Color.black.opacity(0.45).ignoresSafeArea())

            // Face-mesh dots
            meshOverlay.frame(width: 260, height: 340)

            // Sweeping scan laser
            Rectangle()
                .fill(LinearGradient(colors: [.clear, CMColor.violet, CMColor.coral, .clear],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(width: 300, height: 4)
                .shadow(color: CMColor.violet, radius: 16)
                .offset(y: sweep ? 175 : -175)

            VStack(spacing: 0) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white).frame(width: 40, height: 40)
                            .background(.white.opacity(0.18), in: Circle())
                    }.buttonStyle(.plain)
                    Spacer()
                }
                Text("Analyzing your skin…")
                    .font(CMFont.headlineMd).foregroundStyle(.white).padding(.top, 6)

                Spacer()

                Text("\(progress)%")
                    .font(CMFont.inter(64, .heavy)).foregroundStyle(.white)
                    .shadow(color: CMColor.violet.opacity(0.7), radius: 18)
                    .contentTransition(.numericText())
                Text("Please hold still")
                    .font(CMFont.bodyMd).foregroundStyle(.white.opacity(0.85))
                    .padding(.bottom, 90)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
        }
        .navigationBarBackButtonHidden(true)
        .onReceive(timer) { _ in
            // Climb to 92% while the network call is in flight, then finish to 100%.
            let cap = revealed ? 100 : 92
            if progress < cap { progress += 1 }
        }
        .onAppear { withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: true)) { sweep = true } }
        .task {
            if let img = state.pendingImage {
                await state.runAnalysis(img)
                if state.analysisError == nil {
                    revealed = true
                    try? await Task.sleep(for: .milliseconds(450))   // let the bar reach 100
                    onDone()
                }
                // on error: the overlay below offers Retry / demo
            } else {
                // No captured image (e.g. demo flow) — show the animation, then mock results.
                try? await Task.sleep(for: .seconds(2.2))
                revealed = true
                try? await Task.sleep(for: .milliseconds(450))
                onDone()
            }
        }
        .overlay { if let err = state.analysisError { errorCard(err) } }
    }

    private func errorCard(_ message: String) -> some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 14) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40)).foregroundStyle(CMColor.coral)
                Text("Scan failed").font(CMFont.headlineMd).foregroundStyle(CMColor.ink)
                Text(message).font(CMFont.bodyMd).foregroundStyle(CMColor.inkSoft)
                    .multilineTextAlignment(.center)
                AuraButton(title: "Try Again") { state.analysisError = nil; dismiss() }
                Button("Use demo results") { state.analysisError = nil; onDone() }
                    .font(CMFont.labelMd).foregroundStyle(CMColor.violetDeep)
            }
            .padding(24)
            .background(.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(32)
        }
    }

    /// A grid of dots clipped to a face-shaped ellipse — the "mesh" overlay.
    private var meshOverlay: some View {
        Canvas { ctx, size in
            let cols = 9, rows = 12
            let cx = size.width / 2, cy = size.height / 2
            let rx = size.width / 2, ry = size.height / 2
            for r in 0...rows {
                for c in 0...cols {
                    let x = size.width * CGFloat(c) / CGFloat(cols)
                    let y = size.height * CGFloat(r) / CGFloat(rows)
                    let nx = (x - cx) / rx, ny = (y - cy) / ry
                    if nx * nx + ny * ny <= 1 {   // inside the ellipse
                        let dot = CGRect(x: x - 1.2, y: y - 1.2, width: 2.4, height: 2.4)
                        ctx.fill(Path(ellipseIn: dot), with: .color(.white.opacity(0.55)))
                    }
                }
            }
        }
    }
}

#Preview { NavigationStack { AnalyzingView(onDone: {}) }.environmentObject(AppState()) }
