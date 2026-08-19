//
//  ScanHistoryView.swift
//  ClearMaxx — full list of every saved scan; tap one to revisit its full results.
//

import SwiftUI
import SwiftData

struct ScanHistoryView: View {
    @ObserveInjection var inject
    @Query(sort: \ScanRecord.date, order: .reverse) private var scanRecords: [ScanRecord]
    @State private var newestFirst = true

    private var sortedRecords: [ScanRecord] { newestFirst ? scanRecords : scanRecords.reversed() }

    var body: some View {
        DewyBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L("history.title")).font(CMFont.headlineLg).foregroundStyle(CMColor.ink)
                            Text(L(scanRecords.count == 1 ? "history.savedScansOne" : "history.savedScansOther", scanRecords.count))
                                .font(CMFont.labelMd).foregroundStyle(CMColor.inkSoft)
                        }
                        Spacer()
                        if scanRecords.count > 1 {
                            Button { newestFirst.toggle() } label: {
                                Image(systemName: "line.3.horizontal.decrease.circle.fill")
                                    .font(.system(size: 18)).foregroundStyle(CMColor.coralDeep)
                                    .frame(width: 40, height: 40)
                                    .background(CMColor.primary.opacity(0.12), in: Circle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(newestFirst ? L("history.sortedNewest") : L("history.sortedOldest"))
                        }
                    }
                    .padding(.top, 8).padding(.bottom, 4)

                    if scanRecords.isEmpty {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(L("history.emptyTitle")).font(CMFont.title).foregroundStyle(CMColor.ink)
                                Text(L("history.emptyBody"))
                                    .font(CMFont.bodyMd).foregroundStyle(CMColor.inkSoft)
                            }
                        }
                    } else {
                        ForEach(Array(sortedRecords.enumerated()), id: \.element.id) { i, record in
                            HStack(alignment: .top, spacing: 14) {
                                VStack(spacing: 0) {
                                    Circle().fill(CMColor.primary).frame(width: 12, height: 12)
                                        .overlay(Circle().stroke(.white, lineWidth: 2))
                                    if i < sortedRecords.count - 1 {
                                        Rectangle().fill(CMColor.primary.opacity(0.2)).frame(width: 1.5)
                                            .frame(maxHeight: .infinity)
                                    }
                                }
                                .frame(width: 12)
                                .padding(.top, 40)

                                NavigationLink(value: record) {
                                    ScanHistoryRow(record: record)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24).padding(.bottom, 100)
            }
        }
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
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar").font(.system(size: 10)).foregroundStyle(CMColor.coralDeep)
                        Text(record.date.cmFormatted(date: .abbreviated, time: .omitted))
                            .font(CMFont.labelMd).foregroundStyle(CMColor.ink)
                            .lineLimit(1).minimumScaleFactor(0.8)
                    }
                    Text(record.date.cmFormatted(date: .omitted, time: .shortened))
                        .font(CMFont.labelSm).foregroundStyle(CMColor.inkSoft)
                        .lineLimit(1)
                    TagChip(text: CMTerms.skinType(record.skinType), tint: CMColor.violetDeep, icon: "drop.fill")
                        .fixedSize()
                }
                .layoutPriority(1)

                Spacer(minLength: 4)

                VStack(spacing: 0) {
                    Text("\(record.clearScore)").font(CMFont.inter(20, .heavy)).foregroundStyle(CMColor.coralDeep)
                    Text(L("history.score")).font(CMFont.inter(8, .bold)).tracking(0.5).foregroundStyle(CMColor.inkSoft)
                }
                .fixedSize()
                .padding(.horizontal, 10).padding(.vertical, 8)
                .background(CMColor.primary.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                Image(systemName: "chevron.right").foregroundStyle(CMColor.outline)
            }
        }
    }
}

#Preview {
    NavigationStack { ScanHistoryView() }
        .modelContainer(for: [ScanRecord.self, DailyRoutineChecklist.self], inMemory: true)
}
