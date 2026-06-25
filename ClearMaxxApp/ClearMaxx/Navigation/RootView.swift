//
//  RootView.swift
//  ClearMaxx — top-level flow: splash -> onboarding -> quiz -> main tabs
//

import SwiftUI

struct RootView: View {
    @ObserveInjection var inject
    @EnvironmentObject var state: AppState

    var body: some View {
        ZStack {
            switch state.stage {
            case .splash:
                SplashView()
                    .transition(.opacity)
            case .onboarding:
                OnboardingView()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            case .quiz:
                SkinQuizView()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            case .main:
                MainTabView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: state.stage)
    }
}

#Preview {
    RootView().environmentObject(AppState())
}
