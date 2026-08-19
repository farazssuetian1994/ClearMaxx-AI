//
//  SplashView.swift
//  ClearMaxx — logo, tagline "Scan. Track. Glow.", auto-advances to onboarding.
//

import SwiftUI

struct SplashView: View {
    @ObserveInjection var inject
    @EnvironmentObject var state: AppState
    @State private var appear = false
    @State private var loadProgress: CGFloat = 0
    @State private var bounce = false

    var body: some View {
        DewyBackground {
            VStack(spacing: 18) {
                Spacer()
                // App icon tile, radiating out of a dotted radar ring
                ZStack {
                    radarRings
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(CMGradient.auraDiagonal)
                        .frame(width: 96, height: 96)
                        .overlay(
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 44, weight: .semibold))
                                .foregroundStyle(.white))
                        .shadow(color: CMColor.primary.opacity(0.35), radius: 22, y: 10)
                }
                .scaleEffect(appear ? 1 : 0.7)
                .opacity(appear ? 1 : 0)

                ClearMaxxWordmark(size: 38)
                    .opacity(appear ? 1 : 0)

                Text(L("splash.tagline"))
                    .font(CMFont.headlineMd)
                    .foregroundStyle(CMColor.text)
                    .opacity(appear ? 1 : 0)

                Spacer()

                equalizer

                Text(L("splash.initializing"))
                    .font(CMFont.inter(11, .semibold))
                    .tracking(2)
                    .foregroundStyle(CMColor.primary.opacity(0.8))
                    .padding(.top, 4)

                Capsule().fill(CMColor.border)
                    .frame(width: 120, height: 4)
                    .overlay(alignment: .leading) {
                        Capsule().fill(CMColor.text)
                            .frame(width: 120 * loadProgress)
                    }
                    .padding(.bottom, 50)
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.7)) { appear = true }
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) { bounce = true }
            withAnimation(.linear(duration: 2.0)) { loadProgress = 1 }
            Task {
                try? await Task.sleep(for: .seconds(2.2))
                state.stage = state.hasCompletedOnboarding ? .main : .onboarding
            }
        }
    }

    /// Concentric dotted rings emanating from behind the icon tile.
    private var radarRings: some View {
        ZStack {
            ForEach(0..<3) { i in
                Circle()
                    .stroke(CMColor.primary.opacity(0.16 - Double(i) * 0.04),
                            style: StrokeStyle(lineWidth: 1, dash: [1, 7]))
                    .frame(width: 160 + CGFloat(i) * 60, height: 160 + CGFloat(i) * 60)
            }
        }
    }

    /// A small audio-equalizer flourish next to "INITIALIZING AI ANALYSIS".
    private var equalizer: some View {
        HStack(spacing: 4) {
            ForEach(0..<5) { i in
                Capsule().fill(CMColor.primary)
                    .frame(width: 3, height: bounce ? [10, 18, 8, 22, 12][i] : [16, 8, 20, 10, 18][i])
            }
        }
        .frame(height: 22)
    }
}

#Preview { SplashView().environmentObject(AppState()) }
