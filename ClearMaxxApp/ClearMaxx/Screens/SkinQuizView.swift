//
//  SkinQuizView.swift
//  ClearMaxx — multi-step onboarding quiz (skin type, goal, concerns).
//

import SwiftUI

struct SkinQuizView: View {
    @ObserveInjection var inject
    @EnvironmentObject var state: AppState
    @State private var step = 1
    private let totalSteps = 3

    @State private var skinType: String?
    @State private var goal: String?
    @State private var concerns: Set<String> = []

    var body: some View {
        DewyBackground {
            VStack(alignment: .leading, spacing: 0) {
                CMTopBar(showBack: true, onBack: back)

                // Progress
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Quiz Progress").font(CMFont.labelMd).foregroundStyle(CMColor.inkSoft)
                        Spacer()
                        Text("\(step) of \(totalSteps)").font(CMFont.labelMd).foregroundStyle(CMColor.violetDeep)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(CMColor.cardSoft).frame(height: 8)
                            Capsule().fill(CMGradient.aura)
                                .frame(width: geo.size.width * CGFloat(step) / CGFloat(totalSteps), height: 8)
                                .animation(.spring, value: step)
                        }
                    }.frame(height: 8)
                }
                .padding(.horizontal, 24).padding(.top, 4)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(question).font(CMFont.headlineLg).foregroundStyle(CMColor.ink)
                        Text(subtitle).font(CMFont.bodyMd).foregroundStyle(CMColor.inkSoft)

                        ForEach(options, id: \.self) { opt in
                            QuizOption(text: opt,
                                       selected: isSelected(opt)) { choose(opt) }
                        }
                    }
                    .padding(24)
                }

                Spacer()
                HStack(spacing: 14) {
                    GlassPillButton(systemImage: "chevron.left", action: back)
                    AuraButton(title: step < totalSteps ? "Next" : "See My Results",
                               systemImage: "arrow.right", action: next)
                }
                .padding(.horizontal, 24).padding(.bottom, 30)
            }
        }
    }

    // MARK: content per step
    private var question: String {
        switch step {
        case 1: "What's your skin type?"
        case 2: "What's the main goal?"
        default: "Any specific concerns?"
        }
    }
    private var subtitle: String {
        switch step {
        case 1: "This calibrates your AI baseline."
        case 2: "We'll prioritize this in your daily AI ritual."
        default: "Select all that apply."
        }
    }
    private var options: [String] {
        switch step {
        case 1: ["Oily", "Dry", "Combination", "Normal", "Sensitive"]
        case 2: ["Clear Acne", "Anti-Aging", "Ultimate Glow"]
        default: ["Acne", "Dark Spots", "Redness", "Large Pores", "Dryness", "Wrinkles"]
        }
    }
    private func isSelected(_ opt: String) -> Bool {
        switch step {
        case 1: skinType == opt
        case 2: goal == opt
        default: concerns.contains(opt)
        }
    }
    private func choose(_ opt: String) {
        switch step {
        case 1: skinType = opt
        case 2: goal = opt
        default:
            if concerns.contains(opt) { concerns.remove(opt) } else { concerns.insert(opt) }
        }
    }
    private func next() {
        if step < totalSteps { withAnimation { step += 1 } }
        else { state.stage = .main }   // first scan happens on the Scan tab
    }
    private func back() {
        if step > 1 { withAnimation { step -= 1 } }
        else { state.stage = .onboarding }
    }
}

private struct QuizOption: View {
    let text: String
    let selected: Bool
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack {
                Text(text).font(CMFont.title).foregroundStyle(CMColor.ink)
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(selected ? CMColor.violet : CMColor.outline.opacity(0.5))
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.white.opacity(0.8)))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(selected ? AnyShapeStyle(CMGradient.aura) : AnyShapeStyle(Color.white.opacity(0.6)),
                            lineWidth: selected ? 2 : 1))
            .bloomShadow()
        }
        .buttonStyle(.plain)
    }
}

#Preview { SkinQuizView().environmentObject(AppState()) }
