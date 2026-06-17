//
//  OnboardingView.swift
//  ClearMaxx — 3-slide intro carousel.
//

import SwiftUI

private struct OnboardSlide: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let body: String
}

struct OnboardingView: View {
    @EnvironmentObject var state: AppState
    @State private var page = 0

    private let slides: [OnboardSlide] = [
        .init(icon: "camera.viewfinder", title: "Illustrate Scan",
              body: "Our AI-powered lens analyzes over 100 skin biomarkers to understand your unique glow."),
        .init(icon: "list.bullet.clipboard", title: "Get Your Routine",
              body: "Receive a personalized AM/PM ritual with the exact ingredients your skin needs."),
        .init(icon: "chart.line.uptrend.xyaxis", title: "Track Progress",
              body: "Snap a daily photo and watch your ClearScore climb with before/after proof.")
    ]

    var body: some View {
        DewyBackground {
            VStack {
                HStack {
                    ClearMaxxWordmark(size: 22)
                    Spacer()
                    Button("Skip") { state.stage = .quiz }
                        .font(CMFont.labelMd)
                        .foregroundStyle(CMColor.ink)
                }
                .padding(.horizontal, 24).padding(.top, 8)

                TabView(selection: $page) {
                    ForEach(Array(slides.enumerated()), id: \.element.id) { i, slide in
                        VStack(spacing: 26) {
                            Spacer()
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .fill(CMGradient.auraDiagonal)
                                .frame(width: 230, height: 230)
                                .overlay(
                                    Image(systemName: slide.icon)
                                        .font(.system(size: 84, weight: .light))
                                        .foregroundStyle(.white))
                                .shadow(color: CMColor.violet.opacity(0.25), radius: 30, y: 14)
                            VStack(spacing: 12) {
                                Text(slide.title).font(CMFont.headlineLg).foregroundStyle(CMColor.ink)
                                Text(slide.body)
                                    .font(CMFont.bodyMd)
                                    .foregroundStyle(CMColor.inkSoft)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 30)
                            }
                            Spacer()
                        }
                        .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Custom dots
                HStack(spacing: 8) {
                    ForEach(0..<slides.count, id: \.self) { i in
                        Capsule()
                            .fill(i == page ? AnyShapeStyle(CMGradient.aura) : AnyShapeStyle(CMColor.outline.opacity(0.4)))
                            .frame(width: i == page ? 26 : 8, height: 8)
                            .animation(.spring, value: page)
                    }
                }
                .padding(.bottom, 20)

                AuraButton(title: page < slides.count - 1 ? "Next" : "Get Started") {
                    if page < slides.count - 1 {
                        withAnimation { page += 1 }
                    } else {
                        state.stage = .quiz
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 30)
            }
        }
    }
}

#Preview { OnboardingView().environmentObject(AppState()) }
