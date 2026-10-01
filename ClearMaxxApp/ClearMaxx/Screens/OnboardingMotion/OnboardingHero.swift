//
//  OnboardingHero.swift
//  ClearMaxx — the animated card at the top of each onboarding slide.
//
//  Owns the clock. The visible slide's loop restarts each time it comes into
//  view, so every slide plays its story from the beginning, and slides off
//  screen are paused. Under Reduce Motion there is no loop at all, just the
//  one frame that tells the slide's story.
//

import SwiftUI

enum OnboardingHeroKind: Hashable {
    case scan, routine, progress

    /// The single frame shown under Reduce Motion.
    var restingT: Double {
        switch self {
        case .scan: ScanFrame.restingT
        case .routine: RoutineFrame.restingT
        case .progress: ProgressFrame.restingT
        }
    }
}

struct OnboardingHero: View {
    let kind: OnboardingHeroKind
    let isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var loopStart = Date.now

    var body: some View {
        content
            .aspectRatio(HeroPaint.designSize.width / HeroPaint.designSize.height, contentMode: .fit)
            .frame(maxWidth: 230)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(CMColor.surface))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(CMColor.outline, lineWidth: 1))
            .shadow(color: CMColor.violet.opacity(0.12), radius: 24, y: 10)
            // An illustration: its geometry must not mirror in right-to-left languages.
            .environment(\.layoutDirection, .leftToRight)
            // Decorative. The slide's title and body already say what it shows.
            .accessibilityHidden(true)
            .onChange(of: isActive) { _, active in
                if active { loopStart = .now }
            }
    }

    @ViewBuilder private var content: some View {
        if reduceMotion {
            hero(t: kind.restingT, animated: false)
        } else {
            TimelineView(.animation(paused: !isActive)) { timeline in
                hero(t: MotionTimeline.progress(elapsed: timeline.date.timeIntervalSince(loopStart)),
                     animated: true)
            }
        }
    }

    @ViewBuilder private func hero(t: Double, animated: Bool) -> some View {
        switch kind {
        case .scan: ScanHero(t: t, pulses: animated)
        case .routine: RoutineHero(t: t)
        case .progress: ProgressHero(t: t)
        }
    }
}
