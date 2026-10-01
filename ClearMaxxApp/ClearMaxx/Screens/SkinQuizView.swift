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

    /// Answering the last question doesn't drop the user straight into the app:
    /// it plays a short "building your profile" beat, then shows what we read
    /// back from their answers, and only then hands off to the paywall. The
    /// pause is what makes the plan feel earned rather than generic.
    private enum Phase { case questions, building, result }
    @State private var phase: Phase = .questions
    @State private var buildStep = 0

    private var buildSteps: [String] {
        [L("quiz.building.step1"), L("quiz.building.step2"), L("quiz.building.step3")]
    }

    var body: some View {
        Group {
            switch phase {
            case .questions: questionsView
            case .building:  buildingView
            case .result:    resultView
            }
        }
        .animation(.easeInOut(duration: 0.35), value: phase)
    }

    // MARK: - Questions

    private var questionsView: some View {
        DewyBackground {
            VStack(alignment: .leading, spacing: 0) {
                CMTopBar(showBack: true, onBack: back)

                // Progress
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(L("quiz.progress")).font(CMFont.labelMd).foregroundStyle(CMColor.inkSoft)
                        Spacer()
                        Text(L("quiz.stepOf", step, totalSteps)).font(CMFont.labelMd).foregroundStyle(CMColor.violetDeep)
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
                            QuizOption(text: label(for: opt),
                                       selected: isSelected(opt)) { choose(opt) }
                        }
                    }
                    .padding(24)
                }

                Spacer()
                HStack(spacing: 14) {
                    GlassPillButton(systemImage: "chevron.left", action: back)
                    AuraButton(title: step < totalSteps ? L("common.next") : L("quiz.seeResults"),
                               systemImage: "arrow.right", action: next)
                }
                .padding(.horizontal, 24).padding(.bottom, 30)
            }
        }
    }

    // MARK: content per step
    private var question: String {
        switch step {
        case 1: L("quiz.step1.question")
        case 2: L("quiz.step2.question")
        default: L("quiz.step3.question")
        }
    }
    private var subtitle: String {
        switch step {
        case 1: L("quiz.step1.subtitle")
        case 2: L("quiz.step2.subtitle")
        default: L("quiz.step3.subtitle")
        }
    }

    /// Options are stored and sent to the backend as canonical English values
    /// (they feed the analysis prompt and are persisted in `SkinProfile`);
    /// only the label the user reads is translated.
    private func label(for option: String) -> String {
        switch step {
        case 1: CMTerms.skinType(option)
        case 2: CMTerms.goal(option)
        default: CMTerms.concern(option)
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
        else { runBuilding() }
    }

    /// Persists the answers, then ticks the checklist before revealing the result.
    private func runBuilding() {
        SkinProfileStore.save(SkinProfile(skinType: skinType, goal: goal, concerns: Array(concerns)))
        state.hasCompletedOnboarding = true
        phase = .building
        Task { @MainActor in
            for i in 0..<buildSteps.count {
                try? await Task.sleep(for: .milliseconds(650))
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { buildStep = i + 1 }
            }
            try? await Task.sleep(for: .milliseconds(450))
            phase = .result
        }
    }
    private func back() {
        if step > 1 { withAnimation { step -= 1 } }
        else { state.stage = .onboarding }
    }
}

// MARK: - Building / Result phases

extension SkinQuizView {

    fileprivate var buildingView: some View {
        DewyBackground {
            VStack(spacing: 26) {
                Spacer()
                ZStack {
                    Circle().fill(CMColor.primary.opacity(0.12)).frame(width: 108, height: 108)
                    Circle().fill(CMGradient.auraDiagonal).frame(width: 84, height: 84)
                        .overlay(Image(systemName: "sparkles")
                            .font(.system(size: 34, weight: .semibold)).foregroundStyle(.white))
                        .shadow(color: CMColor.primary.opacity(0.35), radius: 18, y: 8)
                }

                Text(L("quiz.building.title"))
                    .font(CMFont.headlineLg).foregroundStyle(CMColor.ink)
                    .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(buildSteps.enumerated()), id: \.offset) { i, title in
                        let done = buildStep > i
                        HStack(spacing: 12) {
                            ZStack {
                                Circle().fill(done ? CMColor.primary : CMColor.cardSoft)
                                    .frame(width: 26, height: 26)
                                if done {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                                } else {
                                    ProgressView().scaleEffect(0.6)
                                }
                            }
                            Text(title)
                                .font(CMFont.bodyMd)
                                .foregroundStyle(done ? CMColor.ink : CMColor.inkSoft)
                            Spacer(minLength: 0)
                        }
                    }
                }
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .padding(.horizontal, 24)

                Spacer(); Spacer()
            }
            .padding(.horizontal, 24)
        }
    }

    fileprivate var resultView: some View {
        DewyBackground {
            ScrollView {
                VStack(spacing: 18) {
                    ZStack {
                        Circle().fill(CMGradient.auraDiagonal).frame(width: 92, height: 92)
                            .overlay(Image(systemName: "checkmark")
                                .font(.system(size: 40, weight: .bold)).foregroundStyle(.white))
                            .shadow(color: CMColor.primary.opacity(0.35), radius: 20, y: 10)
                    }
                    .padding(.top, 24)

                    TagChip(text: L("quiz.result.badge"), tint: CMColor.violetDeep, filled: true)

                    Text(L("quiz.result.title"))
                        .font(CMFont.headlineLg).foregroundStyle(CMColor.ink)
                        .multilineTextAlignment(.center)

                    Text(L("quiz.result.summary"))
                        .font(CMFont.bodyMd).foregroundStyle(CMColor.inkSoft)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)

                    // Reads their own answers back to them, so the plan feels specific.
                    GlassCard {
                        VStack(alignment: .leading, spacing: 14) {
                            resultRow(icon: "drop.fill",
                                      label: L("quiz.result.rowSkinType"),
                                      value: skinType.map(CMTerms.skinType) ?? "—")
                            Divider().overlay(CMColor.outline.opacity(0.25))
                            resultRow(icon: "target",
                                      label: L("quiz.result.rowGoal"),
                                      value: goal.map(CMTerms.goal) ?? "—")
                            Divider().overlay(CMColor.outline.opacity(0.25))
                            resultRow(icon: "list.bullet",
                                      label: L("quiz.result.rowFocus"),
                                      value: concerns.isEmpty
                                          ? L("quiz.result.focusNone")
                                          : concerns.sorted().map(CMTerms.concern).joined(separator: ", "))
                        }
                    }
                    .padding(.horizontal, 24)

                    AuraButton(title: L("quiz.result.cta"), systemImage: "arrow.right") {
                        // Same debug-only escape hatch as refreshPremiumStatus(): this
                        // is the actual moment the hard gate fires within a single
                        // session, before any relaunch — so the bypass has to be
                        // checked here too, not just at launch.
                        state.stage = state.isPremium ? .main : .paywall
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 4)
                    .padding(.bottom, 34)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func resultRow(icon: String, label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(CMColor.violet.opacity(0.12)).frame(width: 34, height: 34)
                Image(systemName: icon).font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(CMColor.violetDeep)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(CMFont.labelSm).foregroundStyle(CMColor.inkSoft)
                Text(value).font(CMFont.title).foregroundStyle(CMColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
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
