import MapKit
import RudolstadtCore
import SwiftUI

private enum PlanTimelineLayout {
    static let contentInset: CGFloat = 8
    static let imageSize: CGFloat = 48
    static let imageRadius: CGFloat = 8
    static let cardRadius = imageRadius + contentInset
    static let concertHeight: CGFloat = 56
    static let recommendationHeight = imageSize + contentInset * 2
    static let sectionSpacing: CGFloat = 8
    static let timelineGutter: CGFloat = 32
    static let pauseHeight: CGFloat = 24
    static let rowInset: CGFloat = 4
    static let trailingControlSize: CGFloat = 44
    static let trailingControlOffset: CGFloat = 2
}

private enum PlanConcertAlignment: AlignmentID {
    static let value = VerticalAlignment(Self.self)

    static func defaultValue(in context: ViewDimensions) -> CGFloat {
        context[VerticalAlignment.center]
    }
}

struct PersonalPlanTimelineView: View {
    let events: [Event]
    let unknownTime: [Event]
    let unknownDate: [Event]

    @Environment(\.festivalData) private var festivalData
    @Environment(\.locale) private var locale
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var profile: FestivalProfileStore
    @ScaledMetric(relativeTo: .callout) private var timeWidth = 48.0

    private var entries: [PlanTimelineEntry] {
        PlanDayTimeline.shared.entries(events: events, transfer: festivalData.coreWalkingTransfers)
    }

    var body: some View {
        Group {
            let entries = entries
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if entries.isEmpty && unknownTime.isEmpty && unknownDate.isEmpty {
                        Text("schedule.plan.empty")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                    }

                    ForEach(entries, id: \.id) { entry in
                        VStack(alignment: .leading, spacing: 0) {
                            if entry.id != entries.first?.id {
                                if entry.hasDashedConnectorBefore {
                                    timelineRow(isPause: true) {
                                        Text("schedule.plan.free_time")
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                            .padding(.leading, PlanTimelineLayout.rowInset)
                                            .frame(minHeight: PlanTimelineLayout.pauseHeight)
                                    }
                                } else {
                                    timelineRow {
                                        Color.clear.frame(height: PlanTimelineLayout.sectionSpacing)
                                    }
                                    .accessibilityHidden(true)
                                }
                            }
                            if !entry.incomingWalks.isEmpty {
                                timelineRow(
                                    time: entry.departureTimestamp.map {
                                        timeLabel(Date(timeIntervalSince1970: $0.doubleValue))
                                    }, marker: .walk
                                ) {
                                    PlanWalkingContent(entry: entry)
                                }
                                timelineRow { Color.clear.frame(height: PlanTimelineLayout.sectionSpacing) }
                                    .accessibilityHidden(true)
                            }

                            VStack(spacing: 0) {
                                timelineRow(
                                    time: entry.event.timeAsString,
                                    marker: .concert(
                                        conflict: entry.hasConflict,
                                        recommended: !profile.isEventSaved(entry.event.id)),
                                    isConcert: true
                                ) {
                                    PlanConcertLink(event: entry.event)
                                }
                                if entry.hasConflict {
                                    timelineRow {
                                        Label {
                                            Text(conflictDescription(entry))
                                        } icon: {
                                            Image(systemName: "bolt")
                                                .frame(width: 18)
                                        }
                                            .font(.caption)
                                            .foregroundStyle(.red)
                                            .fixedSize(horizontal: false, vertical: true)
                                            .padding(.leading, PlanTimelineLayout.rowInset)
                                            .padding(.top, 4)
                                            .padding(.bottom, 8)
                                    }
                                }
                            }
                            .padding(.top, entry.hasConflict ? 4 : 0)
                            .background(alignment: .leading) {
                                if entry.hasConflict {
                                    HStack(spacing: 0) {
                                        Color.clear.frame(width: timeWidth + PlanTimelineLayout.timelineGutter)
                                        RoundedRectangle(
                                            cornerRadius: PlanTimelineLayout.cardRadius, style: .continuous)
                                            .fill(Color.red.opacity(colorScheme == .dark ? 0.16 : 0.055))
                                            .padding(.leading, -4)
                                    }
                                    .accessibilityHidden(true)
                                }
                            }
                        }
                    }
                    unplacedSection(unknownTime, title: "event.time.unknown")
                    unplacedSection(unknownDate, title: "event.date.unknown")
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .animation(
                    reduceMotion ? nil : .default,
                    value: [events.map(\.id), unknownTime.map(\.id), unknownDate.map(\.id)])
                .animation(reduceMotion ? nil : .default, value: profile.savedEvents)
            }
            .accessibilityIdentifier("personal-plan-timeline")
        }
    }

    private func conflictDescription(_ entry: PlanTimelineEntry) -> String {
        let formatter = ListFormatter()
        formatter.locale = locale
        let artists = entry.previousConflicts.map { $0.artist.formattedName }
        let names = formatter.string(from: artists) ?? artists.joined(separator: ", ")
        return String(
            format: NSLocalizedString("schedule.plan.conflict_with", comment: ""),
            locale: locale, names)
    }

    private func timelineRow<Content: View>(
        time: String? = nil, marker: PlanTimelineMarker = .none,
        isConcert: Bool = false, isPause: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        PlanTimelineRow(
            time: time, marker: marker, timeWidth: timeWidth,
            isConcert: isConcert, isPause: isPause, content: content)
    }

    @ViewBuilder
    private func unplacedSection(_ events: [Event], title: LocalizedStringKey) -> some View {
        if !events.isEmpty {
            Text(title)
                .font(.headline)
                .padding(.horizontal, PlanTimelineLayout.contentInset)
                .padding(.top, 24)
                .padding(.bottom, PlanTimelineLayout.sectionSpacing)
                .accessibilityAddTraits(.isHeader)
            ForEach(events) { event in
                PlanConcertLink(event: event)
                    .padding(.bottom, PlanTimelineLayout.sectionSpacing)
            }
        }
    }

    private var calendar: Calendar {
        festivalData.metadata?.calendar ?? FestivalDateUtilities.festivalCalendar
    }

    private func timeLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

private enum PlanTimelineMarker {
    case none, walk, concert(conflict: Bool, recommended: Bool)

    var isWalking: Bool {
        if case .walk = self { return true }
        return false
    }

    var isConflict: Bool {
        if case .concert(conflict: true, recommended: _) = self { return true }
        return false
    }

    var isRecommendation: Bool {
        if case .concert(conflict: _, recommended: true) = self { return true }
        return false
    }
}

private struct PlanTimelineRow<Content: View>: View {
    let time: String?
    let marker: PlanTimelineMarker
    let timeWidth: CGFloat
    let isConcert: Bool
    let isPause: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(alignment: rowAlignment, spacing: 0) {
            Group {
                if let time {
                    Text(time)
                        .font(.callout)
                        .monospacedDigit()
                        .foregroundStyle(
                            marker.isConflict ? .red
                                : isConcert && !marker.isRecommendation ? .primary : .secondary)
                } else {
                    Color.clear.frame(height: 0)
                }
            }
            .frame(width: timeWidth, alignment: .trailing)
            .alignmentGuide(PlanConcertAlignment.value) { $0[VerticalAlignment.center] }
            .overlay(alignment: .trailing) {
                timelineMarker
                    .frame(width: PlanTimelineLayout.timelineGutter, height: 20)
                    .offset(x: PlanTimelineLayout.timelineGutter)
                    .accessibilityHidden(true)
            }
            .accessibilityHidden(isConcert)
            Color.clear.frame(width: PlanTimelineLayout.timelineGutter, height: 0)
            content().frame(maxWidth: .infinity, alignment: .leading)
        }
        .background {
            GeometryReader { proxy in
                Path { path in
                    let x = timeWidth + PlanTimelineLayout.timelineGutter / 2
                    if isPause {
                        let center = proxy.size.height / 2
                        for offset in [CGFloat(-3.5), CGFloat(3.5)] {
                            path.move(to: CGPoint(x: x - 5, y: center + offset + 2))
                            path.addLine(to: CGPoint(x: x + 5, y: center + offset - 2))
                        }
                    } else {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: proxy.size.height))
                    }
                }
                .stroke(
                    Color.gray.opacity(0.5),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                )
            }
            .accessibilityHidden(true)
        }
    }

    private var rowAlignment: VerticalAlignment {
        if isConcert { return PlanConcertAlignment.value }
        return marker.isWalking ? .center : .top
    }

    @ViewBuilder
    private var timelineMarker: some View {
        switch marker {
        case .none:
            EmptyView()
        case .walk:
            Image(systemName: "figure.walk")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 18, height: 20)
                .background(Color(.systemBackground), in: Circle())
        case .concert:
            Circle().fill(.secondary).frame(width: 6, height: 6)
        }
    }
}

private struct PlanConcertLink: View {
    let event: Event
    @Environment(\.festivalData) private var festivalData
    @Environment(\.dynamicTypeSize) private var dynamicType
    @EnvironmentObject private var profile: FestivalProfileStore
    @EnvironmentObject private var friends: FriendProfilesStore
    @EnvironmentObject private var settings: UserSettings
    @Environment(\.festivalAccentColor) private var accent
    @ScaledMetric(relativeTo: .callout) private var statusSymbolSize = 15.0

    private var isSaved: Bool { profile.isEventSaved(event.id) }

    private var textLeading: Font.Leading {
        isSaved || dynamicType.isAccessibilitySize ? .standard : .tight
    }

    var body: some View {
        NavigationLink(
            value: festivalData.eventDestination(event, alwaysShowDetails: settings.alwaysShowEventDetails)
        ) {
            HStack(spacing: 12) {
                if !dynamicType.isAccessibilitySize {
                    ArtistImageView(artist: event.artist, fullImage: false, loadingStyle: .quiet)
                        .frame(width: PlanTimelineLayout.imageSize, height: PlanTimelineLayout.imageSize)
                        .clipShape(RoundedRectangle(
                            cornerRadius: PlanTimelineLayout.imageRadius, style: .circular))
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: isSaved || dynamicType.isAccessibilitySize ? 4 : 0.5) {
                    if !isSaved {
                        Text("schedule.plan.suggestion")
                            .font(.caption2.weight(.medium).leading(textLeading))
                            .foregroundStyle(accent)
                    }
                    Text(event.artist.formattedName)
                        .font(.callout.weight(.medium).leading(textLeading))
                        .foregroundStyle(.primary)
                        .alignmentGuide(PlanConcertAlignment.value) { $0[VerticalAlignment.center] }
                    Text(event.stage.localizedName)
                        .font(.footnote.leading(textLeading))
                        .foregroundStyle(.secondary)
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.leading, PlanTimelineLayout.rowInset)
            .padding(.vertical, isSaved ? PlanTimelineLayout.rowInset : PlanTimelineLayout.contentInset)
            .frame(minHeight: isSaved
                ? PlanTimelineLayout.concertHeight : PlanTimelineLayout.recommendationHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(event.timeAsString), \(event.artist.formattedName), \(event.stage.localizedName)")
        .accessibilityValue(isSaved
            ? Text("event.saved.value.saved") : Text("schedule.plan.recommended"))
        .accessibilityIdentifier("personal-plan-event-\(event.id)")
        .eventContextMenu(
            event: event,
            state: EventContextPreviewState(event: event, profile: profile, friends: friends, settings: settings),
            onToggleSaved: { profile.toggleSavedEvent(event) }
        )
        .padding(.trailing, PlanTimelineLayout.trailingControlSize - PlanTimelineLayout.trailingControlOffset)
        .overlay(alignment: .trailing) {
            trailingStatus
                .offset(x: PlanTimelineLayout.trailingControlOffset)
        }
        .overlay {
            if !isSaved {
                RoundedRectangle(cornerRadius: PlanTimelineLayout.cardRadius, style: .circular)
                    .strokeBorder(accent.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .padding(.leading, -PlanTimelineLayout.rowInset)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }

    private var trailingStatus: some View {
        EventSavedIcon(event: event, isSaved: isSaved, foregroundColor: .primary) {
            profile.toggleSavedEvent(event)
        }
        .font(.system(size: statusSymbolSize))
        .accessibilityIdentifier("personal-plan-save-\(event.id)")
    }
}

private struct PlanWalkingContent: View {
    let entry: PlanTimelineEntry
    @Environment(\.locale) private var locale
    @Environment(\.festivalAccentColor) private var accent

    var body: some View {
        Text(walkingTime)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Color.primary.opacity(0.72))
            .padding(.leading, PlanTimelineLayout.rowInset)
            .padding(.trailing, PlanTimelineLayout.trailingControlSize)
            .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
            .overlay(alignment: .trailing) {
                routeAction
                    .offset(x: PlanTimelineLayout.trailingControlOffset)
            }
        .buttonStyle(.plain)
    }

    private var routeLabel: some View {
        Image(systemName: routeSymbol)
            .font(.callout)
            .foregroundStyle(accent)
            .frame(width: 32, height: 32)
            .background(Color(.tertiarySystemFill), in: Circle())
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
    }

    @ViewBuilder
    private var routeAction: some View {
        Group {
            if entry.incomingWalks.count == 1, let walk = entry.incomingWalks.first {
                Button { openRoute(walk) } label: { routeLabel }
                    .disabled(!canOpenRoute(walk))
                    .accessibilityLabel(routeTitle(walk))
            } else {
                Menu {
                    ForEach(Array(entry.incomingWalks.enumerated()), id: \.offset) { _, walk in
                        Button(routeTitle(walk)) { openRoute(walk) }
                            .disabled(!canOpenRoute(walk))
                    }
                } label: { routeLabel }
                .accessibilityLabel(Text("schedule.plan.routes"))
            }
        }
        .labelStyle(.iconOnly)
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityIdentifier("personal-plan-routes-\(entry.id)")
    }

    private var routeSymbol: String {
        if #available(iOS 18.0, macOS 15.0, *) {
            "point.topright.arrow.triangle.backward.to.point.bottomleft.scurvepath"
        } else {
            "arrow.triangle.turn.up.right.diamond"
        }
    }

    private var walkingTime: String {
        guard !entry.hasUnknownWalkingTime,
            let minimum = entry.minimumWalkingMinutes?.intValue,
            let maximum = entry.maximumWalkingMinutes?.intValue
        else { return String(localized: "schedule.plan.walking.unknown") }
        let key = minimum == maximum ? "schedule.plan.walk_minutes" : "schedule.plan.walk_minutes_range"
        return String(format: NSLocalizedString(key, comment: ""), locale: locale, minimum, maximum)
    }

    private func routeTitle(_ walk: PlanTimelineWalk) -> String {
        String(
            format: NSLocalizedString("schedule.plan.route_from_to", comment: ""),
            locale: locale, walk.from.localizedName, walk.to.localizedName)
    }

    private func canOpenRoute(_ walk: PlanTimelineWalk) -> Bool {
        walk.from.hasLocation && walk.to.hasLocation
    }

    private func openRoute(_ walk: PlanTimelineWalk) {
        guard canOpenRoute(walk) else { return }
        let items = [walk.from, walk.to].map { stage in
            let item = MKMapItem(placemark: MKPlacemark(coordinate:
                CLLocationCoordinate2D(latitude: stage.latitude, longitude: stage.longitude)))
            item.name = stage.localizedName
            return item
        }
        MKMapItem.openMaps(with: items, launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking
        ])
    }
}
