//
//  ScanHistoryView.swift
//  ClearMaxx — full list of every saved scan; tap one to revisit its full results.
//

import SwiftUI
import SwiftData

struct ScanHistoryView: View {
    @ObserveInjection var inject
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ScanRecord.date, order: .reverse) private var scanRecords: [ScanRecord]

    var body: some View {
        DewyBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if scanRecords.isEmpty {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("No scans yet").font(CMFont.title).foregroundStyle(CMColor.ink)
                                Text("Every scan you take will be saved here so you can revisit it anytime.")
                                    .font(CMFont.bodyMd).foregroundStyle(CMColor.inkSoft)
                            }
                        }
                    } else {
                        ForEach(scanRecords) { record in
                            NavigationLink(value: record) {
                                ScanHistoryRow(record: record)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 24).padding(.top, 8).padding(.bottom, 40)
            }
            .safeAreaInset(edge: .top) {
                CMTopBar(showBack: true, onBack: { dismiss() }).background(.ultraThinMaterial)
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationDestination(for: ScanRecord.self) { record in
            ScanHistoryDetailView(record: record)
        }
    }
}

private struct ScanHistoryRow: View {
    let record: ScanRecord

    var body: some View {
        GlassCard {
            HStack(spacing: 14) {
                Group {
                    if let img = ScanPhotoStore.load(record.photoFileName) {
                        Image(uiImage: img).resizable().scaledToFill()
                    } else {
                        CMGradient.auraDiagonal
                    }
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(record.date.formatted(date: .abbreviated, time: .shortened))
                        .font(CMFont.labelMd).foregroundStyle(CMColor.ink)
                    Text(record.skinType).font(CMFont.labelSm).foregroundStyle(CMColor.inkSoft)
                }

                Spacer()

                VStack(spacing: 0) {
                    Text("\(record.clearScore)").font(CMFont.inter(20, .heavy)).foregroundStyle(CMColor.coralDeep)
                    Text("SCORE").font(CMFont.inter(8, .bold)).tracking(0.5).foregroundStyle(CMColor.inkSoft)
                }

                Image(systemName: "chevron.right").foregroundStyle(CMColor.outline)
            }
        }
    }
}

#Preview {
    NavigationStack { ScanHistoryView() }
        .modelContainer(for: [ScanRecord.self, DailyRoutineChecklist.self], inMemory: true)
}
