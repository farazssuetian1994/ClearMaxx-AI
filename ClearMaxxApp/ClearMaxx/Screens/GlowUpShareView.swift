//
//  GlowUpShareView.swift
//  ClearMaxx — shareable before/after card "+18 ClearScore", social share buttons.
//

import SwiftUI

struct GlowUpShareView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var slider: CGFloat = 0.5

    var body: some View {
        DewyBackground {
            VStack(spacing: 20) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left").font(.system(size: 18, weight: .semibold)).foregroundStyle(CMColor.ink)
                    }
                    Spacer(); ClearMaxxWordmark(size: 22); Spacer()
                    Image(systemName: "chevron.left").opacity(0)
                }
                .padding(.horizontal, 24).padding(.top, 12)

                // Share card
                VStack(spacing: 0) {
                    BeforeAfterSlider(value: $slider).frame(height: 300)
                        .overlay(alignment: .bottom) {
                            VStack(spacing: 2) {
                                Text("+18 ClearScore").font(CMFont.inter(26, .heavy)).foregroundStyle(.white)
                                Text("in 30 days").font(CMFont.labelMd).foregroundStyle(.white.opacity(0.9))
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(CMGradient.aura.opacity(0.92))
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                    HStack {
                        ClearMaxxWordmark(size: 16)
                        Text("AI Dermatology Analysis").font(CMFont.labelSm).foregroundStyle(CMColor.inkSoft)
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.seal.fill").foregroundStyle(CMColor.violet)
                            Text("Verified Result").font(CMFont.labelSm).foregroundStyle(CMColor.violetDeep)
                        }
                    }
                    .padding(14)
                    .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .padding(.top, 10)
                }
                .padding(.horizontal, 24)

                Text("Flex your glow").font(CMFont.headlineMd).foregroundStyle(CMColor.ink)

                HStack(spacing: 14) {
                    shareButton("TikTok", "music.note", .black)
                    shareButton("Instagram", "camera.fill", nil)
                }
                .padding(.horizontal, 24)

                AuraButton(title: "Save to Photos", systemImage: "square.and.arrow.down")
                    .padding(.horizontal, 24)
                Spacer()
            }
        }
        .presentationDragIndicator(.visible)
    }

    private func shareButton(_ label: String, _ icon: String, _ bg: Color?) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon); Text(label).font(CMFont.labelMd)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity).padding(.vertical, 16)
        .background(bg != nil ? AnyShapeStyle(bg!) : AnyShapeStyle(CMGradient.aura),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#Preview { GlowUpShareView() }
