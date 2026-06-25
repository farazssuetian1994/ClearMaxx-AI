//
//  SkinDiaryView.swift
//  ClearMaxx — Diary tab. Log sleep/water/diet/stress/cycle + recent glow-ups.
//

import SwiftUI

struct SkinDiaryView: View {
    @ObserveInjection var inject
    @EnvironmentObject var state: AppState
    @State private var sleep = "8h"
    @State private var water = "2L"
    @State private var diet = "Clean"
    @State private var stress: Double = 0.8

    var body: some View {
        DewyBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Text("Daily Log").font(CMFont.headlineLg).foregroundStyle(CMColor.ink)
                        Spacer()
                        Text("Today, Oct 24").font(CMFont.labelMd).foregroundStyle(CMColor.inkSoft)
                    }

                    HStack(spacing: 14) {
                        pickerCard(icon: "moon.fill", tint: CMColor.violet, title: "Sleep",
                                   options: ["6h","8h","9h+"], selection: $sleep)
                        pickerCard(icon: "drop.fill", tint: CMColor.coral, title: "Water",
                                   options: ["1.5L","2L","3L"], selection: $water)
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Diet Quality", systemImage: "fork.knife").font(CMFont.title).foregroundStyle(CMColor.ink)
                            HStack(spacing: 10) {
                                dietOption("Greasy", "🍔"); dietOption("Clean", "🥗"); dietOption("Sugary", "🍩")
                            }
                        }
                    }

                    HStack(spacing: 14) {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Label("Stress", systemImage: "bolt.fill").font(CMFont.labelMd).foregroundStyle(CMColor.ink)
                                Slider(value: $stress).tint(CMColor.error)
                                Text(stress > 0.6 ? "High" : stress > 0.3 ? "Medium" : "Low")
                                    .font(CMFont.labelSm).foregroundStyle(CMColor.error)
                            }
                        }
                        GlassCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Cycle Day", systemImage: "calendar").font(CMFont.labelMd).foregroundStyle(CMColor.ink)
                                Text("14").font(CMFont.headlineLg).foregroundStyle(CMColor.violetDeep)
                            }
                        }
                    }

                    AuraButton(title: "Log Daily Ritual", systemImage: "checkmark")

                    HStack {
                        Text("Recent Glow-ups").font(CMFont.headlineMd).foregroundStyle(CMColor.ink)
                        Spacer()
                        Text("View All").font(CMFont.labelMd).foregroundStyle(CMColor.coralDeep)
                    }

                    ForEach(state.recentDiary) { entry in
                        GlassCard {
                            HStack(spacing: 14) {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(CMGradient.auraDiagonal).frame(width: 48, height: 48)
                                    .overlay(Text(entry.emoji).font(.system(size: 22)))
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(entry.day).font(CMFont.labelMd).foregroundStyle(CMColor.ink)
                                    HStack { ForEach(entry.notes, id: \.self) { TagChip(text: $0) } }
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(CMColor.outline)
                            }
                        }
                    }
                    .padding(.bottom, 100)
                }
                .padding(.horizontal, 24).padding(.top, 8)
            }
        }
    }

    private func pickerCard(icon: String, tint: Color, title: String,
                            options: [String], selection: Binding<String>) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Label(title, systemImage: icon).font(CMFont.title).foregroundStyle(CMColor.ink)
                    .labelStyle(.titleAndIcon).tint(tint)
                HStack(spacing: 6) {
                    ForEach(options, id: \.self) { opt in
                        Button { selection.wrappedValue = opt } label: {
                            Text(opt).font(CMFont.labelSm)
                                .foregroundStyle(selection.wrappedValue == opt ? .white : CMColor.inkSoft)
                                .padding(.horizontal, 10).padding(.vertical, 8)
                                .background(selection.wrappedValue == opt ? AnyShapeStyle(tint) : AnyShapeStyle(tint.opacity(0.1)),
                                            in: Capsule())
                        }.buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func dietOption(_ label: String, _ emoji: String) -> some View {
        let selected = diet == label
        return Button { diet = label } label: {
            VStack(spacing: 6) {
                Text(emoji).font(.system(size: 26))
                Text(label).font(CMFont.labelSm).foregroundStyle(CMColor.inkSoft)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 12)
            .background(selected ? CMColor.cardSoft : .clear, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(selected ? CMColor.violet : .clear, lineWidth: 1.5))
        }.buttonStyle(.plain)
    }
}

#Preview { SkinDiaryView().environmentObject(AppState()) }
