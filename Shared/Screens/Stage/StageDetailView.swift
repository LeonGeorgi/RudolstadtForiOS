import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct StageDetailView: View {
    private enum Layout {
        static let compactHorizontalMargin: CGFloat = 16
        static let mapParallaxFactor = 0.25
    }

    fileprivate static let distanceFormatter: MeasurementFormatter = {
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .providedUnit
        formatter.unitStyle = .short
        return formatter
    }()
    fileprivate static let walkTimeFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute]
        formatter.maximumUnitCount = 1
        formatter.unitsStyle = .short
        return formatter
    }()

    let stage: Stage
    let highlightedEventId: Int?
    var showsMap = true
    var navigate: ((AppNavigationRoute) -> Void)? = nil
    var programDaySelection: Binding<String>? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.festivalData) private var festivalData
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.isPresentedInMapSheet) private var isPresentedInMapSheet
    @EnvironmentObject private var profile: FestivalProfileStore
    @EnvironmentObject private var friends: FriendProfilesStore
    @EnvironmentObject private var settings: UserSettings

    @State private var isStageTitleVisible = true
    @State private var localSelectedDay = ""
    @State private var isShowingInteractiveMap = false
    @State private var showsLocationInfo = false
    @StateObject private var tipSequencer = TipSequencer(
        DiscoverabilityTipSequences.stageDetailScreen
    )

    private func eventsGroupedByDay(_ entities: FestivalData) -> [String: [Event]] {
        Dictionary(
            grouping: entities.events.filter { event in
                event.stage.id == stage.id
            }
        ) { event in
            event.programDay?.id ?? event.festivalDate.map { FestivalCalendarDate($0, calendar: event.calendar).stableID } ?? ""
        }
    }

    private var hasEvents: Bool { festivalData.events.contains { $0.stage.id == stage.id } }

    private var nearbyStageDistances: [StageDistance] {
        Array(calculateNearbyStages(festivalData)
            .filter { stageDistance in
                stageDistance.transfer.walkingMinutes <= 10
            }
            .prefix(10))
    }

    private var usesEdgeToEdgeHero: Bool {
        showsMap && stage.hasLocation && isPhone
            && horizontalSizeClass == .compact
            && verticalSizeClass == .regular
            && !dynamicTypeSize.isAccessibilitySize
    }

    private var isPhone: Bool {
        #if canImport(UIKit)
        UIDevice.current.userInterfaceIdiom == .phone
        #else
        false
        #endif
    }

    private var navigationBarBackgroundVisibility: Visibility {
        usesEdgeToEdgeHero && isStageTitleVisible ? .hidden : .automatic
    }

    private var selectedDay: Binding<String> { programDaySelection ?? $localSelectedDay }

    private var usesCompactHeader: Bool {
        isPresentedInMapSheet && !dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        let stageDistances = nearbyStageDistances

        return ScrollView {
            VStack(spacing: 0) {
                if showsMap && stage.hasLocation {
                    topMapHero.padding(.top, usesEdgeToEdgeHero ? 0 : 16)
                } else if !stage.hasLocation {
                    Label("stage.location.unknown", systemImage: "mappin.slash")
                        .foregroundStyle(.secondary).padding()
                }

                if isPresentedInMapSheet {
                    sheetHeader
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                } else {
                    stageHeader(showsInlineIdentity: !usesEdgeToEdgeHero)
                        .padding(.horizontal, 16)
                        .padding(.top, usesEdgeToEdgeHero ? 16 : 20)
                }

                if hasEvents {
                    eventsSection.padding(.top, isPresentedInMapSheet ? 12 : 18)
                }

                if !stageDistances.isEmpty {
                    nearbyStagesSection(stageDistances)
                        .padding(.top, 20)
                }
            }
            .padding(.bottom, 28)
        }
        .ignoresSafeArea(
            .container,
            edges: usesEdgeToEdgeHero ? .top : []
        )
        .modifier(
            StageDetailTopScrollEdgeEffectModifier(
                isHidden: usesEdgeToEdgeHero && isStageTitleVisible
            )
        )
        .accessibilityIdentifier("stage-detail-\(stage.id)")
        .modifier(MapSheetNavigationBackground())
        .navigationTitle(usesCompactHeader || !isStageTitleVisible ? stage.localizedName : "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackgroundVisibility(
            navigationBarBackgroundVisibility,
            for: .navigationBar
        )
        .toolbar {
            if usesCompactHeader {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        StageNumber(stage: stage, size: 28)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(stage.localizedName)
                                .font(.headline)
                                .lineLimit(stage.area == nil ? 2 : 1)
                            if let area = stage.area {
                                Text(area.localizedName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isHeader)
                }
            }
            if stage.hasLocation {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { StageMapView.openInMaps(stage: stage) } label: {
                        Label("site_plan.show_geographic_location", systemImage: "map")
                    }
                    .labelStyle(.iconOnly)
                    .accessibilityIdentifier("stage-open-in-maps")
                }
            }
        }
        .onAppear {
            if eventsGroupedByDay(festivalData)[selectedDay.wrappedValue] == nil {
                selectedDay.wrappedValue = initialSelectedDay()
            }
        }
        .fullScreenCover(isPresented: $isShowingInteractiveMap) {
            StageDetailInteractiveMap(stage: stage)
        }
    }

    private func initialSelectedDay() -> String {
        if let event = festivalData.events.first(where: { $0.id == highlightedEventId }), let day = event.programDay { return day.id }
        let now = Date.now
        let available = Set(eventsGroupedByDay(festivalData).keys)
        return festivalData.days.first { available.contains($0.id) && now >= $0.interval.start && now < $0.interval.end }?.id
            ?? available.sorted().first ?? ""
    }

    private func stageHeader(showsInlineIdentity: Bool) -> some View {
        VStack(spacing: 10) {
            if showsInlineIdentity {
                HStack(alignment: .center, spacing: 12) {
                    StageNumber(stage: stage, size: 40)

                    Text(stage.localizedName)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .lineLimit(3)
                        .minimumScaleFactor(0.78)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .onScrollVisibilityChange(threshold: 0.1) { isVisible in
                    isStageTitleVisible = isVisible
                }
            }

            VStack(spacing: 4) {
                if let description = stage.localizedDescription,
                   !description.isEmpty
                {
                    Text(description)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                }

                if let area = stage.area {
                    Text(area.localizedName).font(.subheadline).foregroundStyle(.secondary)
                }
                if let category = stage.admissionCategory {
                    Text(category.title.resolved()).font(.subheadline).foregroundStyle(.secondary)
                }

                if stage.locationIsApproximate {
                    Text("site_plan.coordinates_approximate")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                ForEach(festivalData.features.placeDetails.value?.details(for: stage.id)?.links ?? []) { link in
                    Link(link.title.resolved(), destination: link.destination).font(.subheadline)
                }
            }
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var hasLocationInfo: Bool {
        stage.localizedDescription?.isEmpty == false
            || festivalData.features.placeDetails.value?.details(for: stage.id)?.links.isEmpty == false
    }

    private var sheetHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !usesCompactHeader {
                HStack(spacing: 10) {
                    StageNumber(stage: stage, size: 40)
                    Text(stage.localizedName)
                        .font(.title2.bold())
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
                .onScrollVisibilityChange(threshold: 0.1) { isVisible in
                    isStageTitleVisible = isVisible
                }
            }

            let metadata = [usesCompactHeader ? nil : stage.area?.localizedName,
                            stage.admissionCategory?.title.resolved()]
                .compactMap { $0 }.joined(separator: " · ")
            if !metadata.isEmpty {
                Text(metadata)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if stage.locationIsApproximate {
                Text("stage.location.approximate")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if hasLocationInfo {
                if hasEvents {
                    DisclosureGroup("stage.location_info", isExpanded: $showsLocationInfo) {
                        locationInfo.padding(.top, 4)
                    }
                    .font(.subheadline)
                    .accessibilityIdentifier("stage-location-info")
                } else {
                    locationInfo
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var locationInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let description = stage.localizedDescription, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(festivalData.features.placeDetails.value?.details(for: stage.id)?.links ?? []) { link in
                Link(link.title.resolved(), destination: link.destination).font(.subheadline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func dayLabel(_ day: String) -> String {
        festivalData.days.first { $0.id == day }?
            .label(calendar: festivalData.metadata?.calendar ?? .current) ?? day
    }

    private var eventsSection: some View {
        let eventsByDay = eventsGroupedByDay(festivalData)
        let days = eventsByDay.keys.sorted()
        let selectedEvents = eventsByDay[selectedDay.wrappedValue] ?? []

        return VStack(alignment: .leading, spacing: 10) {
            if days.count > 1 {
                Picker("Date", selection: selectedDay) {
                    ForEach(days, id: \.self) { day in
                        Text(dayLabel(day)).tag(day)
                    }
                }
                .pickerStyle(.segmented)
            } else if let day = days.first, !day.isEmpty {
                Text(dayLabel(day))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !days.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(selectedEvents.enumerated()), id: \.element.id) { index, event in
                        eventRow(event)

                        if index < selectedEvents.count - 1 {
                            Divider()
                                .padding(.leading, 90)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private var topMapHero: some View {
        Group {
            if let plan = festivalData.features.sitePlan.value {
                NavigationLink {
                    FestivalOriginalPlanView(document: plan.document, position: plan.position(for: stage.id))
                } label: {
                    mapPreview
                }
            } else if festivalData.features.map.value != nil {
                NavigationLink {
                    MapOverview(initialPlaceID: stage.id, navigate: navigate)
                } label: {
                    mapPreview
                }
            } else {
                Button {
                    isShowingInteractiveMap = true
                } label: {
                    mapPreview
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("stage.map"))
        .accessibilityIdentifier("stage-map-preview")
        .appPopoverTip(
            DiscoverabilityTips.stageMapPreview,
            currentTipID: tipSequencer.currentTipID,
            arrowEdge: .bottom
        )
    }

    @ViewBuilder
    private var mapPreview: some View {
        if usesEdgeToEdgeHero {
            edgeToEdgeMapHero
        } else {
            insetMapPreview
        }
    }

    private var edgeToEdgeMapHero: some View {
        GeometryReader { proxy in
            let minY = proxy.frame(in: .scrollView(axis: .vertical)).minY
            let mapContentOffset = reduceMotion
                ? 0
                : max(-minY, 0) * Layout.mapParallaxFactor

            StageMapView(
                stage: stage,
                verticalContentOffset: mapContentOffset
            )
            .allowsHitTesting(false)
            .frame(width: proxy.size.width, height: proxy.size.width)
            .overlay {
                LinearGradient(
                    colors: [.clear, .black.opacity(0.68)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .accessibilityHidden(true)
                .allowsHitTesting(false)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .overlay(alignment: .bottomLeading) {
            HStack(alignment: .center, spacing: 12) {
                StageNumber(stage: stage, size: 44)

                Text(stage.localizedName)
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(1)
                    .accessibilityHeading(.h1)
                    .onScrollVisibilityChange(threshold: 0.1) { isVisible in
                        isStageTitleVisible = isVisible
                    }
                    .allowsHitTesting(false)
            }
            .padding(.horizontal, Layout.compactHorizontalMargin)
            .padding(.bottom, 20)
        }
        .contentShape(Rectangle())
    }

    private var insetMapPreview: some View {
        StageMapView(stage: stage)
            .allowsHitTesting(false)
            .aspectRatio(4.0 / 3.0, contentMode: .fill)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(mapPreviewStrokeColor, lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .padding(.horizontal, 56)
    }

    private var mapPreviewStrokeColor: Color {
        colorScheme == .dark ? .white.opacity(0.22) : .black.opacity(0.15)
    }

    private func nearbyStagesSection(_ nearbyStageDistances: [StageDistance]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("stage.nearby")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                ForEach(Array(nearbyStageDistances.enumerated()), id: \.element.id) { index, stageDistance in
                    nearbyStageRow(stageDistance)

                    if index < nearbyStageDistances.count - 1 {
                        Divider()
                            .padding(.leading, 40)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
    }

    private func nearbyStageRow(_ stageDistance: StageDistance) -> some View {
        navigationLink(
            route: AppNavigationRoute.stage(
                id: stageDistance.stage.id,
                highlightedEventId: nil
            )
        ) {
            HStack(spacing: 12) {
                StageNumber(stage: stageDistance.stage, size: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(stageDistance.stage.localizedName)
                        .lineLimit(1)
                    Text(stageDistance.distanceAndWalkTimeText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("stage-nearby-\(stageDistance.stage.id)")
    }

    @ViewBuilder
    private func navigationLink<Label: View>(route: AppNavigationRoute, @ViewBuilder label: () -> Label) -> some View {
        if let navigate {
            Button { navigate(route) } label: { label() }
        } else {
            NavigationLink(value: route, label: label)
        }
    }

    private func calculateNearbyStages(_ entities: FestivalData) -> [StageDistance] {
        let estimator = StageTransferEstimator(
            stages: entities.stages,
            matrix: entities.walkingDistanceMatrix
        )
        return entities.stages
            .filter { stage in
                stage.id != self.stage.id
            }
            .compactMap { stage in
                let resolved = entities.features.distances.value
                let transfer = entities.metadata == nil ? estimator.estimate(from: self.stage, to: stage)
                    : resolved?.walkingTransfer(from: self.stage.id, to: stage.id).map(StageTransferEstimate.init)
                guard let transfer else {
                    return nil
                }
                return StageDistance(
                    stage: stage,
                    transfer: transfer
                )
            }
            .sorted { first, second in
                first.transfer.distanceInMeters < second.transfer.distanceInMeters
            }
    }

    private func eventRow(_ event: Event) -> some View {
        let shouldBeHighlighted = highlightedEventId == event.id
        return navigationLink(
            route: AppNavigationRoute.artist(
                id: event.artist.id,
                highlightedEventId: event.id,
                transitionSourceID: nil
            )
        ) {
            StageEventCell(
                event: event,
                imageWidth: 64,
                imageHeight: 56,
                contextPreviewState: EventContextPreviewState(
                    event: event,
                    profile: profile,
                    friends: friends,
                    settings: settings
                ),
                onToggleSaved: { profile.toggleSavedEvent(event) }
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                shouldBeHighlighted
                ? Color.rudolstadt.opacity(0.12)
                : Color.clear
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, -16)
        .accessibilityIdentifier("stage-event-\(event.id)")
    }

}

private struct StageDistance: Identifiable {
    let stage: Stage
    let transfer: StageTransferEstimate

    var id: FestivalPlaceID {
        stage.id
    }

    var distanceAndWalkTimeText: String {
        let distanceString = StageDetailView.distanceFormatter.string(
            from: Measurement(
                value: transfer.distanceInMeters,
                unit: UnitLength.meters
            )
        )
        let estimatedSeconds = TimeInterval(transfer.walkingMinutes * 60)
        let timeString = StageDetailView.walkTimeFormatter.string(from: estimatedSeconds)
            ?? "\(transfer.walkingMinutes) min"
        let distancePrefix = transfer.source.isEstimated ? "≈" : ""
        let timePrefix = transfer.source.isEstimated ? "≈" : "~"
        return "\(distancePrefix)\(distanceString) • \(timePrefix)\(timeString)"
    }
}

private struct StageDetailTopScrollEdgeEffectModifier: ViewModifier {
    let isHidden: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.scrollEdgeEffectHidden(isHidden, for: .top)
        } else {
            content
        }
    }
}

#if DEBUG
struct StageDetailView_Previews: PreviewProvider {
    @MainActor
    static var previews: some View {
        NavigationStack {
            StageDetailView(
                stage: previewStage,
                highlightedEventId: 350
            )
            .navigationDestination(for: AppNavigationRoute.self) { _ in
                EmptyView()
            }
        }
        .previewMockEnvironment(suiteName: "StageDetailViewPreview")
    }

    @MainActor
    private static var previewStage: Stage {
        PreviewMockData.festivalData.stages.first { $0.id == 44 }
        ?? PreviewMockData.mainStage
    }
}
#endif
