//
//  SkinProgressView.swift
//  ClearMaxx — Progress tab. Before/after slider, ClearScore trend, AI analysis, share.
//

import SwiftUI

struct SkinProgressView: View {
    @EnvironmentObject var state: AppState
    @State private var slider: CGFloat = 0.5
    @State private var showShare = false

    var body: some View {
        DewyBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Your Journey").font(CMFont.labelMd).foregroundStyle(CMColor.inkSoft)
                            Text("Skin Evolution").font(CMFont.headlineLg).foregroundStyle(CMColor.ink)
                        }
                        Spacer()
                        HStack(spacing: 6) {
                            Image(systemName: "flame.fill")
                            Text("\(state.scanStreak) Day Streak!").font(CMFont.labelMd)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(CMGradient.aura, in: Capsule())
                    }

                    BeforeAfterSlider(value: $slider)

                    // ClearScore trend card
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading) {
                                    Text("ClearScore").font(CMFont.title).foregroundStyle(CMColor.ink)
                                    Text("+12% from last month").font(CMFont.labelSm).foregroundStyle(CMColor.success)
                                }
                                Spacer()
                                Text("\(state.clearScore)").font(CMFont.inter(40, .heavy)).foregroundStyle(CMColor.coralDeep)
                            }
                            // Gradient trend bars
                            HStack(alignment: .bottom, spacing: 6) {
                                ForEach(0..<8, id: \.self) { i in
                                    RoundedRectangle(cornerRadius: 5)
                                        .fill(i >= 6 ? AnyShapeStyle(CMGradient.aura) : AnyShapeStyle(CMColor.outline.opacity(0.35)))
                                        .frame(height: CGFloat(30 + i * 8))
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            HStack {
                                Text("30 DAYS AGO").font(CMFont.inter(9, .semibold)).foregroundStyle(CMColor.inkSoft)
                                Spacer()
                                Text("TODAY").font(CMFont.inter(9, .semibold)).foregroundStyle(CMColor.inkSoft)
                            }
                        }
                    }

                    // Two stat cards
                    HStack(spacing: 14) {
                        statCard(icon: "drop.fill", tint: CMColor.violet, title: "Hydration", value: "92%")
                        statCard(icon: "wand.and.stars", tint: CMColor.coral, title: "Texture", value: "Smooth")
                    }

                    // AI analysis
                    GlassCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("AI Analysis").font(CMFont.headlineMd).foregroundStyle(CMColor.ink)
                            aiRow(icon: "checkmark.seal.fill", tint: CMColor.success, title: "Redness Reduced",
                                  body: "Your skin barrier is healing effectively. Continue using the Vitamin C serum daily.")
                            aiRow(icon: "moon.stars.fill", tint: CMColor.violet, title: "Night Routine Hack",
                                  body: "Apply moisturizer on slightly damp skin to boost your hydration score to 95%+.")
                        }
                    }

                    AuraButton(title: "Share My Glow-Up", systemImage: "square.and.arrow.up") { showShare = true }
                        .padding(.bottom, 100)
                }
                .padding(.horizontal, 24).padding(.top, 8)
            }
        }
        .sheet(isPresented: $showShare) { GlowUpShareView() }
    }

    private func statCard(icon: String, tint: Color, title: String, value: String) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon).foregroundStyle(tint).font(.system(size: 22))
                Text(title).font(CMFont.labelMd).foregroundStyle(CMColor.inkSoft)
                Text(value).font(CMFont.headlineMd).foregroundStyle(CMColor.ink)
            }
        }
    }

    private func aiRow(icon: String, tint: Color, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).foregroundStyle(tint).font(.system(size: 18))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(CMFont.labelMd).foregroundStyle(CMColor.ink)
                Text(body).font(CMFont.bodyMd).foregroundStyle(CMColor.inkSoft)
            }
        }
    }
}

// Draggable before/after comparison
struct BeforeAfterSlider: View {
    @Binding var value: CGFloat
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .leading) {
                LinearGradient(colors: [Color(hex: "C98F6A"), Color(hex: "9A6A4A")], startPoint: .top, endPoint: .bottom)
                    .overlay(Text("BEFORE").font(CMFont.inter(10, .bold)).foregroundStyle(.white)
                        .padding(6).background(.black.opacity(0.4), in: Capsule()).padding(10),
                             alignment: .topLeading)
                CMGradient.auraDiagonal
                    .overlay(Text("AFTER").font(CMFont.inter(10, .bold)).foregroundStyle(.white)
                        .padding(6).background(.black.opacity(0.3), in: Capsule()).padding(10),
                             alignment: .topTrailing)
                    .mask(HStack { Spacer().frame(width: w * value); Rectangle() })
                // handle — only this narrow strip is draggable, so vertical
                // scrolling on the rest of the image passes through to the ScrollView.
                ZStack {
                    Color.clear
                        .frame(width: 60)
                        .frame(maxHeight: .infinity)
                        .contentShape(Rectangle())
                    Circle().fill(.white).frame(width: 36, height: 36)
                        .overlay(Image(systemName: "arrow.left.and.right").foregroundStyle(CMColor.ink))
                        .bloomShadow()
                }
                .offset(x: w * value - 30)
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .named("beforeAfter"))
                        .onChanged { value = max(0, min(1, $0.location.x / w)) }
                )
            }
            .coordinateSpace(name: "beforeAfter")
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .frame(height: 260)
    }
}

#Preview { SkinProgressView().environmentObject(AppState()) }
