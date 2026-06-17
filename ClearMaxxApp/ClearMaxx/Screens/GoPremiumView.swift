//
//  GoPremiumView.swift
//  ClearMaxx — paywall. "Elevate Your Glow", feature list, Weekly/Yearly toggle, trial CTA.
//

import SwiftUI

struct GoPremiumView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var plan: Plan = .yearly

    enum Plan { case weekly, yearly }

    private let features: [(String, String, String)] = [
        ("flame.fill", "Deep AI Scans", "Analyze 14 distinct skin metrics with sub-dermal precision."),
        ("leaf.fill", "Unlimited Routines", "Dynamic daily adjustments based on your local climate and stress levels."),
        ("shield.lefthalf.filled", "Derm-Grade Pro Tips", "Weekly ingredient breakdowns tailored to your skin bio-type.")
    ]

    var body: some View {
        DewyBackground {
            ScrollView {
                VStack(spacing: 20) {
                    HStack {
                        Button { dismiss() } label: {
                            Image(systemName: "xmark").font(.system(size: 18, weight: .semibold)).foregroundStyle(CMColor.ink)
                        }
                        Spacer()
                        ClearMaxxWordmark(size: 20)
                        Spacer()
                        Image(systemName: "xmark").opacity(0)
                    }

                    Circle().fill(CMGradient.auraDiagonal).frame(width: 110, height: 110)
                        .overlay(Image(systemName: "sparkles").font(.system(size: 46)).foregroundStyle(.white))
                        .overlay(Text("PLUS").font(CMFont.inter(10, .bold)).foregroundStyle(.white)
                            .padding(.horizontal, 12).padding(.vertical, 4)
                            .background(CMColor.violet, in: Capsule()).offset(y: 56))
                        .shadow(color: CMColor.violet.opacity(0.4), radius: 20, y: 10)

                    VStack(spacing: 8) {
                        Text("Elevate Your Glow").font(CMFont.displayLg).foregroundStyle(CMColor.ink)
                            .multilineTextAlignment(.center).minimumScaleFactor(0.6)
                        Text("Unlock clinical-grade AI insights and personalized skincare rituals.")
                            .font(CMFont.bodyMd).foregroundStyle(CMColor.inkSoft).multilineTextAlignment(.center)
                    }

                    GlassCard {
                        VStack(spacing: 18) {
                            ForEach(Array(features.enumerated()), id: \.offset) { _, f in
                                HStack(alignment: .top, spacing: 14) {
                                    Image(systemName: f.0).foregroundStyle(CMColor.violet)
                                        .frame(width: 40, height: 40)
                                        .background(CMColor.violet.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(f.1).font(CMFont.title).foregroundStyle(CMColor.ink)
                                        Text(f.2).font(CMFont.bodyMd).foregroundStyle(CMColor.inkSoft)
                                    }
                                    Spacer()
                                }
                            }
                        }
                    }

                    // Plan toggle
                    HStack(spacing: 12) {
                        planCard(.weekly, title: "Weekly", price: "$5.99", note: nil)
                        planCard(.yearly, title: "Yearly", price: "$39.99", note: "SAVE 87%")
                    }

                    Text("Try 3 days for free, then $39.99/year.")
                        .font(CMFont.labelMd).foregroundStyle(CMColor.ink)
                    Text("Cancel anytime. No commitment.")
                        .font(CMFont.labelSm).foregroundStyle(CMColor.inkSoft)

                    AuraButton(title: "Start Free Trial") {
                        state.isPremium = true; dismiss()
                    }

                    HStack(spacing: 24) {
                        Text("Terms of Service"); Text("Privacy Policy"); Text("Restore Purchases").fontWeight(.bold)
                    }
                    .font(CMFont.labelSm).foregroundStyle(CMColor.inkSoft).padding(.bottom, 20)
                }
                .padding(.horizontal, 24).padding(.top, 12)
            }
        }
    }

    private func planCard(_ p: Plan, title: String, price: String, note: String?) -> some View {
        let selected = plan == p
        return Button { plan = p } label: {
            VStack(spacing: 6) {
                Text(title).font(CMFont.title).foregroundStyle(selected ? CMColor.coralDeep : CMColor.ink)
                Text(price).font(CMFont.headlineMd).foregroundStyle(selected ? CMColor.coralDeep : CMColor.inkSoft)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 22)
            .background(selected ? .white : CMColor.cardSoft.opacity(0.6),
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(selected ? AnyShapeStyle(CMGradient.aura) : AnyShapeStyle(Color.clear), lineWidth: 2))
            .overlay(alignment: .topTrailing) {
                if let note {
                    Text(note).font(CMFont.inter(9, .bold)).foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(CMColor.error, in: Capsule()).offset(x: -8, y: 8)
                }
            }
        }.buttonStyle(.plain)
    }
}

#Preview { GoPremiumView().environmentObject(AppState()) }
