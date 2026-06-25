//
//  IssueDetailView.swift
//  ClearMaxx — single concern: severity, "what this means", rescue ingredients, pro rituals.
//

import SwiftUI

struct IssueDetailView: View {
    @ObserveInjection var inject
    let metric: SkinMetric
    @Environment(\.dismiss) private var dismiss

    private var severityLabel: String {
        switch metric.value {
        case ..<25: return "Low"
        case 25..<55: return "Moderate"
        default: return "High"
        }
    }

    private let rituals = [
        "Cool your products in the fridge before applying to instantly constrict blood vessels.",
        "Avoid hot water while cleansing; lukewarm is the golden rule for reactive skin.",
        "Pat dry with a fresh micro-fiber towel instead of rubbing to minimize friction."
    ]

    var body: some View {
        DewyBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Hero
                    ZStack(alignment: .bottomLeading) {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(CMGradient.auraDiagonal).frame(height: 160)
                        VStack(alignment: .leading, spacing: 6) {
                            TagChip(text: "Analysis Result", tint: .white, filled: false)
                                .background(.white.opacity(0.2), in: Capsule())
                            Text(issueTitle).font(CMFont.headlineLg).foregroundStyle(.white)
                        }.padding(18)
                    }

                    // Severity
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Severity Level").font(CMFont.title).foregroundStyle(CMColor.ink)
                                Spacer()
                                Text(severityLabel).font(CMFont.labelMd).foregroundStyle(CMColor.violetDeep)
                            }
                            ZStack(alignment: .leading) {
                                Capsule().fill(CMColor.cardSoft).frame(height: 8)
                                GeometryReader { geo in
                                    Capsule().fill(CMGradient.aura)
                                        .frame(width: geo.size.width * CGFloat(metric.value) / 100, height: 8)
                                }.frame(height: 8)
                            }
                            HStack {
                                Text("Low").font(CMFont.labelSm).foregroundStyle(CMColor.inkSoft)
                                Spacer()
                                Text("High").font(CMFont.labelSm).foregroundStyle(CMColor.inkSoft)
                            }
                        }
                    }

                    // What this means
                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("What this means", systemImage: "info.circle.fill")
                                .font(CMFont.title).foregroundStyle(CMColor.ink)
                            Text(metric.blurb).font(CMFont.bodyMd).foregroundStyle(CMColor.inkSoft)
                        }
                    }

                    // Recommended rescue
                    Text("Recommended Rescue").font(CMFont.headlineMd).foregroundStyle(CMColor.ink)
                    ForEach(metric.ingredients, id: \.self) { ing in
                        GlassCard {
                            HStack(spacing: 14) {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(CMColor.violet.opacity(0.12)).frame(width: 44, height: 44)
                                    .overlay(Image(systemName: "drop.fill").foregroundStyle(CMColor.violet))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(ing).font(CMFont.title).foregroundStyle(CMColor.ink)
                                    Text("Targets \(metric.name.lowercased()) and supports the skin barrier.")
                                        .font(CMFont.labelSm).foregroundStyle(CMColor.inkSoft)
                                }
                                Spacer()
                            }
                        }
                    }

                    // Pro rituals
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Pro Rituals", systemImage: "sparkles")
                                .font(CMFont.title).foregroundStyle(CMColor.violetDeep)
                            ForEach(Array(rituals.enumerated()), id: \.offset) { i, r in
                                HStack(alignment: .top, spacing: 10) {
                                    Text(String(format: "%02d", i + 1))
                                        .font(CMFont.labelMd).foregroundStyle(CMColor.coral)
                                    Text(r).font(CMFont.bodyMd).foregroundStyle(CMColor.inkSoft)
                                }
                            }
                        }
                    }

                    AuraButton(title: "Update My Routine", systemImage: "arrow.triangle.2.circlepath")
                        .padding(.bottom, 90)
                }
                .padding(.horizontal, 24)
            }
            .safeAreaInset(edge: .top) {
                CMTopBar(showBack: true, onBack: { dismiss() }).background(.ultraThinMaterial)
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    private var issueTitle: String {
        switch metric.name {
        case "Redness": "Persistent Redness"
        case "Acne": "Active Breakouts"
        case "Dark Spots": "Post-Acne Marks"
        default: metric.name
        }
    }
}

#Preview {
    NavigationStack {
        IssueDetailView(metric: AppState().metrics[4])
    }
}
