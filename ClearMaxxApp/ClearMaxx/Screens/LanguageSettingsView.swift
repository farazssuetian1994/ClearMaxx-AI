//
//  LanguageSettingsView.swift
//  ClearMaxx — Profile → Language. Lists every shipped language by its own
//  name (endonym) plus its name in the language currently in use.
//

import SwiftUI

struct LanguageSettingsView: View {
    @ObserveInjection var inject
    @EnvironmentObject private var locale: CMLocale
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        DewyBackground {
            VStack(spacing: 0) {
                header

                Text(L("language.subtitle"))
                    .font(CMFont.bodyMd).foregroundStyle(CMColor.inkSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24).padding(.bottom, 14)

                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(CMLanguages.all) { language in
                            row(language)
                        }

                        Text(L("language.note"))
                            .font(CMFont.labelSm).foregroundStyle(CMColor.inkSoft)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
        }
    }

    private var header: some View {
        ZStack {
            Text(L("language.title")).font(CMFont.headlineMd).foregroundStyle(CMColor.ink)
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold)).foregroundStyle(CMColor.ink)
                        .frame(width: 44, height: 44)
                        .background(CMColor.cardSoft, in: Circle())
                }
                .buttonStyle(.plain)
                Spacer()
            }
        }
        .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 18)
    }

    private func row(_ language: CMLanguage) -> some View {
        let selected = locale.language == language.code
        return Button {
            guard !selected else { return }
            // Switching re-keys the whole view tree (see ClearMaxxApp), which
            // tears down this sheet's presenter. Dismiss first so that reads as
            // a normal sheet dismissal rather than the sheet vanishing mid-tap.
            let code = language.code
            dismiss()
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(280))
                CMLocale.shared.setLanguage(code)
            }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    // The endonym is always shown in its own script, so it never
                    // flips direction with the rest of the layout.
                    Text(language.nativeName)
                        .font(CMFont.title).foregroundStyle(CMColor.ink)
                        .environment(\.layoutDirection, language.isRTL ? .rightToLeft : .leftToRight)
                    Text(L(language.nameKey))
                        .font(CMFont.bodyMd).foregroundStyle(CMColor.inkSoft)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(CMColor.violet)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(selected ? CMColor.violet.opacity(0.10) : Color.white.opacity(0.85)))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(selected ? AnyShapeStyle(CMGradient.aura) : AnyShapeStyle(Color.white.opacity(0.6)),
                            lineWidth: selected ? 2 : 1))
            .bloomShadow()
        }
        .buttonStyle(.plain)
    }
}

#Preview { LanguageSettingsView().environmentObject(CMLocale.shared) }
