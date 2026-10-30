//
//  ScheduleListView.swift
//  RudolstadtForiOS
//
//  Created by Leon on 22.02.20.
//  Copyright © 2020 Leon Georgi. All rights reserved.
//

import RudolstadtCore
import SwiftUI

struct ScheduleListView: View {
    let events: [Event]
    var planFacts: PlanFacts? = nil

    @Environment(\.festivalData) private var festivalData
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @EnvironmentObject var profile: FestivalProfileStore
    @EnvironmentObject private var friends: FriendProfilesStore
    @EnvironmentObject private var settings: UserSettings

    var body: some View {
        Group {
            if events.isEmpty {
                Text("schedule.empty.description")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    let dated = events.filter { $0.knownDate != nil }
                    let undated = events.filter { $0.knownDate == nil }
                    if !dated.isEmpty {
                        Section {
                            ForEach(dated) { event in
                                planTransition(before: event)
                                eventRow(event)
                            }
                        } header: {
                            if dated.allSatisfy({ $0.startDate == nil }) {
                                Text("event.time.unknown")
                                if let day = dated.first?.knownDate {
                                    Text(FestivalDateUtilities.format(day, pattern: "EEEE, dd.MM."))
                                }
                            }
                        } footer: {
                            if planFacts != nil { Text("schedule.plan.estimates") }
                        }
                    }
                    if !undated.isEmpty {
                        Section("event.date.unknown") {
                            ForEach(undated) { event in eventRow(event) }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
        }
    }

    @ViewBuilder
    private func planTransition(before event: Event) -> some View {
        if let planFacts {
            let transition = planFacts.transitions.first {
                $0.secondEventID == Int64(event.id)
            }?.native
            let overlap = planFacts.overlaps.filter {
                $0.secondEventID == Int64(event.id)
            }.map { Int($0.overlapMinutes) }.max() ?? 0
            if overlap > 0 || transition?.status == .impossible || transition?.status == .tight
                || transition?.status == .unknown || (transition?.transfer?.walkingMinutes ?? 0) > 0
            {
                SchedulePlanTransitionView(assessment: transition, overlapMinutes: overlap)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
        }
    }

    private func eventRow(_ event: Event) -> some View {
        NavigationLink(
            value: festivalData.eventDestination(event, alwaysShowDetails: settings.alwaysShowEventDetails)
        ) {
            ScheduleEventCell(
                event: event,
                contextPreviewState: EventContextPreviewState(
                    event: event,
                    profile: profile,
                    friends: friends,
                    settings: settings
                ),
                onToggleSaved: { profile.toggleSavedEvent(event) }
            )
        }
        .listRowInsets(
            .init(
                top: dynamicTypeSize.isAccessibilitySize ? 12 : 6,
                leading: 16,
                bottom: dynamicTypeSize.isAccessibilitySize ? 12 : 6,
                trailing: 16
            )
        )
        .listRowBackground(
            profile.isEventSaved(event.id)
                ? savedEventBackground
                : Color.clear
        )
    }

    private var savedEventBackground: Color {
        Color.accentColor.opacity(colorScheme == .dark ? 0.24 : 0.12)
    }
}

private struct SchedulePlanTransitionView: View {
    @Environment(\.locale) private var locale
    let assessment: ScheduleTransitionAssessment?
    let overlapMinutes: Int

    private var isWarning: Bool {
        overlapMinutes > 0 || assessment?.status == .impossible || assessment?.status == .tight
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if overlapMinutes > 0 {
                Label(
                    formatted("schedule.plan.overlap", overlapMinutes),
                    systemImage: "exclamationmark.triangle"
                )
                .foregroundStyle(.red)
            } else if isWarning {
                Label(
                    assessment?.status == .impossible
                        ? LocalizedStringKey("schedule.plan.impossible")
                        : LocalizedStringKey("schedule.plan.tight"),
                    systemImage: "exclamationmark.triangle"
                )
                .foregroundStyle(.red)
            }

            if let transfer = assessment?.transfer, transfer.walkingMinutes > 0 {
                Label(
                    formatted(
                        "schedule.plan.walking", transfer.walkingMinutes,
                        Int(transfer.distanceInMeters.rounded())
                    ),
                    systemImage: "figure.walk"
                )
            } else if assessment?.status == .unknown {
                Label("schedule.plan.walking.unknown", systemImage: "questionmark.circle")
            }

            if let lateness = assessment?.projectedLatenessMinutes, lateness > 0 {
                Text(formatted("schedule.plan.late", lateness))
            } else if let available = assessment?.availableTransferMinutes,
                let transfer = assessment?.transfer, transfer.walkingMinutes > 0
            {
                Text(formatted("schedule.plan.buffer", max(available - transfer.walkingMinutes, 0)))
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
    }

    private func formatted(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: NSLocalizedString(key, comment: ""), locale: locale, arguments: arguments)
    }
}

struct ScheduleListView_Previews: PreviewProvider {
    static var previews: some View {
        ScheduleListView(events: [Event.example])
            .previewMockEnvironment(suiteName: "ScheduleListViewPreview")
    }
}
