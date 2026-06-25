//
//  SplashView.swift
//  ClearMaxx — logo, tagline "Scan. Track. Glow.", auto-advances to onboarding.
//

import SwiftUI

struct SplashView: View {
    @ObserveInjection var inject
    @EnvironmentObject var state: AppState
    @State private var appear = false

    var body: some View {
        DewyBackground {
            VStack(spacing: 18) {
                Spacer()
                // App icon tile
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(CMGradient.auraDiagonal)
                    .frame(width: 96, height: 96)
                    .overlay(
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 44, weight: .semibold))
                            .foregroundStyle(.white))
                    .shadow(color: CMColor.violet.opacity(0.35), radius: 22, y: 10)
                    .scaleEffect(appear ? 1 : 0.7)
                    .opacity(appear ? 1 : 0)

                ClearMaxxWordmark(size: 38)
                    .opacity(appear ? 1 : 0)

                Text("Scan. Track. Glow.")
                    .font(CMFont.headlineMd)
                    .foregroundStyle(CMColor.ink)
                    .opacity(appear ? 1 : 0)

                Spacer()
                ProgressView()
                    .tint(CMColor.violet)
                Text("INITIALIZING AI ANALYSIS")
                    .font(CMFont.inter(11, .semibold))
                    .tracking(2)
                    .foregroundStyle(CMColor.inkSoft.opacity(0.7))
                    .padding(.bottom, 50)
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.7)) { appear = true }
            Task {
                try? await Task.sleep(for: .seconds(2.2))
                state.stage = state.hasCompletedOnboarding ? .main : .onboarding
            }
        }
    }
}

#Preview { SplashView().environmentObject(AppState()) }
