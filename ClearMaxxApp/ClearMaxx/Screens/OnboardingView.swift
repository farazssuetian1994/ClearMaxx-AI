//
//  OnboardingView.swift
//  ClearMaxx — 3-slide intro carousel.
//

import SwiftUI

private struct OnboardSlide: Identifiable {
    let hero: OnboardingHeroKind
    let title: String
    let body: String
    /// Stable across `body` passes, so each slide's hero keeps its clock.
    var id: OnboardingHeroKind { hero }
}

struct OnboardingView: View {
    @ObserveInjection var inject
    @EnvironmentObject var state: AppState
    @State private var page: Int = {
        #if DEBUG
        // Open straight onto a slide for screenshots:
        //   xcrun simctl launch booted com.clearmaxx.app -cmOnboardingPage 2
        return min(max(UserDefaults.standard.integer(forKey: "cmOnboardingPage"), 0), 2)
        #else
        return 0
        #endif
    }()

    private var slides: [OnboardSlide] {
        [
            .init(hero: .scan, title: L("onboarding.slide1.title"),
                  body: L("onboarding.slide1.body")),
            .init(hero: .routine, title: L("onboarding.slide2.title"),
                  body: L("onboarding.slide2.body")),
            .init(hero: .progress, title: L("onboarding.slide3.title"),
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
                            OnboardingHero(kind: slide.hero, isActive: page == i)
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
