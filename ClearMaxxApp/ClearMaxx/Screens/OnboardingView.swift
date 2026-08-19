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
    @ObserveInjection var inject
    @EnvironmentObject var state: AppState
    @State private var page = 0

    private var slides: [OnboardSlide] {
        [
            .init(icon: "camera.viewfinder", title: L("onboarding.slide1.title"),
                  body: L("onboarding.slide1.body")),
            .init(icon: "list.bullet.clipboard", title: L("onboarding.slide2.title"),
                  body: L("onboarding.slide2.body")),
            .init(icon: "chart.line.uptrend.xyaxis", title: L("onboarding.slide3.title"),
                  body: L("onboarding.slide3.body"))
        ]
    }

    var body: some View {
        DewyBackground {
            VStack {
                HStack {
                    ClearMaxxWordmark(size: 22)
                    Spacer()
                    Button(L("common.skip")) { state.stage = .quiz }
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

                AuraButton(title: page < slides.count - 1 ? L("common.next") : L("common.getStarted")) {
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
