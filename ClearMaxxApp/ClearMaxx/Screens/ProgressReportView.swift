//
//  ProgressReportView.swift
//  ClearMaxx — shows the AI's read on scan-history progress and lets the user adopt the adapted routine.
//

import SwiftUI
import SwiftData

struct ProgressReportView: View {
    @ObserveInjection var inject
    @EnvironmentObject var state: AppState
    @Environment(\.modelContext) private var modelContext
    let report: ProgressReport
    @State private var didUpdateRoutine = false

    var body: some View {
        DewyBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        verdictBadge
                        Text(report.headline).font(CMFont.headlineLg).foregroundStyle(CMColor.ink)
                        Text(report.narrative).font(CMFont.bodyMd).foregroundStyle(CMColor.inkSoft)
                    }

                    if !report.working.isEmpty {
                        trendSection(title: "Working", names: report.working, color: CMColor.success)
                    }
                    if !report.stalled.isEmpty {
                        trendSection(title: "Stalled", names: report.stalled, color: CMColor.inkSoft)
                    }
                    if !report.watch.isEmpty {
                        trendSection(title: "Watch", names: report.watch, color: CMColor.error)
                    }

                    if !report.updatedRoutine.isEmpty {
                        AuraButton(title: didUpdateRoutine ? "Routine Updated" : "Update My Routine",
                                  systemImage: didUpdateRoutine ? "checkmark" : "arrow.triangle.2.circlepath") {
                            state.applyUpdatedRoutine(report.updatedRoutine, modelContext: modelContext)
                            didUpdateRoutine = true
                        }
                        .disabled(didUpdateRoutine)
                    }
                }
                .padding(.horizontal, 24).padding(.top, 8).padding(.bottom, 24)
            }
        }
    }

    private var verdictBadge: some View {
        let (label, color): (String, Color) = {
            switch report.verdict {
            case "improving": return ("Improving", CMColor.success)
            case "worsening": return ("Needs Attention", CMColor.error)
            default:          return ("Steady", CMColor.inkSoft)
            }
        }()
        return TagChip(text: label, tint: color, filled: true)
    }

    private func trendSection(title: String, names: [String], color: Color) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(title).font(CMFont.title).foregroundStyle(CMColor.ink)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack { ForEach(names, id: \.self) { TagChip(text: $0, tint: color) } }
                }
            }
        }
    }
}

#Preview {
    ProgressReportView(report: ProgressReport(
        verdict: "improving", headline: "You're making real progress",
        narrative: "Your acne and redness have both improved since your first scan.",
        working: ["Acne", "Redness"], stalled: ["Dark Spots"], watch: [],
        updatedRoutine: []))
    .environmentObject(AppState())
    .modelContainer(for: [ScanRecord.self, DailyRoutineChecklist.self, ProgressReportCache.self], inMemory: true)
}
