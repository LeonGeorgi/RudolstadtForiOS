import Foundation
import MapKit
import SwiftUI

struct StageDetailView: View {
    fileprivate static let walkingSpeedMetersPerMinute = 80.0
    fileprivate static let walkDistancesByStage = loadWalkDistancesByStage(
        fileName: "stage_walk_distances"
    )
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

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.festivalData) private var festivalData
    @EnvironmentObject private var profile: FestivalProfileStore

    @State private var selectedDay: Int = -1
    @State private var isShowingInteractiveMap = false
    @StateObject private var tipSequencer = TipSequencer(
        DiscoverabilityTipSequences.stageDetailScreen
    )

    private func eventsGroupedByDay(_ entities: FestivalData) -> [Int: [Event]] {
        Dictionary(
            grouping: entities.events.filter { event in
                event.stage.id == stage.id
            }
        ) { event in
            event.festivalDay
        }
    }

    private var nearbyStageDistances: [StageDistance] {
        Array(calculateNearbyStages(festivalData)
            .filter { stageDistance in
                guard let estimatedWalkMinutes = stageDistance.estimatedWalkMinutes else {
                    return false
                }
                return estimatedWalkMinutes < 10
            }
            .prefix(10))
    }

    var body: some View {
        let stageDistances = nearbyStageDistances

        return ScrollView {
            VStack(spacing: 0) {
                topMapHero
                    .padding(.top, 16)

                stageHeader
                    .padding(.horizontal, 16)
                    .padding(.top, 20)

                eventsSection
                    .padding(.top, 18)

                if !stageDistances.isEmpty {
                    nearbyStagesSection(stageDistances)
                        .padding(.top, 20)
                }
            }
            .padding(.bottom, 28)
        }
        .accessibilityIdentifier("stage-detail-\(stage.id)")
        .navigationTitle(stage.localizedName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                EmptyView()
            }
        }
        .onAppear {
            selectedDay = initialSelectedDay()
        }
        .fullScreenCover(isPresented: $isShowingInteractiveMap) {
            StageDetailInteractiveMap(stage: stage)
        }
    }

    private func initialSelectedDay() -> Int {
        let eventsByDay = eventsGroupedByDay(festivalData)
        let days = eventsByDay.keys.sorted()
        let highlightedEventDay = festivalData.events.first { event in
            event.id == highlightedEventId
        }?.festivalDay

        return highlightedEventDay
        ?? FestivalDateUtilities.getCurrentFestivalDay(eventDays: days)
        ?? days.first
        ?? -1
    }

    private var stageHeader: some View {
        VStack(spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                StageNumber(stage: stage, size: 40)

                Text(stage.localizedName)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .lineLimit(3)
                    .minimumScaleFactor(0.78)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            VStack(spacing: 4) {
                if let description = stage.localizedDescription,
                   !description.isEmpty
                {
                    Text(description)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                }

                Text(stage.area.localizedName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var eventsSection: some View {
        let eventsByDay = eventsGroupedByDay(festivalData)
        let days = eventsByDay.keys.sorted()
        let selectedEvents = eventsByDay[selectedDay] ?? []

        return VStack(alignment: .leading, spacing: 10) {
            if !days.isEmpty {
                Picker("Date", selection: $selectedDay) {
                    ForEach(days, id: \.self) { day in
                        Text(FestivalDateUtilities.shortWeekDay(day: day)).tag(day)
                    }
                }
                .pickerStyle(.segmented)

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
            .padding(.horizontal, 56)
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.clear)
                    .padding(.horizontal, 56)
                    .contentShape(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )
                    .onTapGesture {
                        isShowingInteractiveMap = true
                    }
            }
            .appPopoverTip(
                DiscoverabilityTips.stageMapPreview,
                currentTipID: tipSequencer.currentTipID,
                arrowEdge: .bottom
            )
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(Text("stage.map"))
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
        NavigationLink(
            value: AppNavigationRoute.stage(
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
    }

    private func calculateNearbyStages(_ entities: FestivalData) -> [StageDistance] {
        entities.stages
            .filter { stage in
                stage.id != self.stage.id
            }
            .map { stage in
                let walkingDistance = self.walkingDistanceInMeters(to: stage)
                let fallbackAirDistance = calculateAirDistance(
                    first: self.stage,
                    second: stage
                )
                return StageDistance(
                    stage: stage,
                    distance: walkingDistance ?? fallbackAirDistance,
                    walkingDistanceInMeters: walkingDistance,
                    estimatedWalkMinutes: walkingDistance.map(
                        estimateWalkMinutes(distanceInMeters:)
                    )
                )
            }
            .sorted { first, second in
                first.distance < second.distance
            }
    }

    private func eventRow(_ event: Event) -> some View {
        let shouldBeHighlighted = highlightedEventId == event.id
        return NavigationLink(
            value: AppNavigationRoute.artist(
                id: event.artist.id,
                highlightedEventId: event.id,
                transitionSourceID: nil
            )
        ) {
            StageEventCell(
                event: event,
                imageWidth: 64,
                imageHeight: 56,
                isSaved: profile.isEventSaved(event.id),
                artistRating: profile.rating(for: event.artist.id),
                artistIconName: profile.iconName(forArtistID: event.artist.id),
                friendProfilesWhoSavedEvent: profile.friendProfilesSavingEvent(event.id),
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
    }

    private func calculateAirDistance(first: Stage, second: Stage) -> Double {
        let start = CLLocation(
            latitude: first.latitude,
            longitude: first.longitude
        )
        let destination = CLLocation(
            latitude: second.latitude,
            longitude: second.longitude
        )
        return destination.distance(from: start)
    }

    private func walkingDistanceInMeters(to otherStage: Stage) -> Double? {
        let fromId = self.stage.id
        let toId = otherStage.id

        if let directDistance = Self.walkDistancesByStage[fromId]?[toId] {
            return directDistance
        }
        if let inverseDistance = Self.walkDistancesByStage[toId]?[fromId] {
            return inverseDistance
        }
        return nil
    }

    private func estimateWalkMinutes(distanceInMeters: Double) -> Int {
        max(1, Int((distanceInMeters / Self.walkingSpeedMetersPerMinute).rounded()))
    }
}

private struct StageDistance: Identifiable {
    let stage: Stage
    let distance: Double
    let walkingDistanceInMeters: Double?
    let estimatedWalkMinutes: Int?

    var id: Int {
        stage.id
    }

    var distanceAndWalkTimeText: String {
        if let walkingDistanceInMeters, let estimatedWalkMinutes {
            let distanceString = StageDetailView.distanceFormatter.string(
                from: Measurement(value: walkingDistanceInMeters, unit: UnitLength.meters)
            )
            let estimatedSeconds = TimeInterval(estimatedWalkMinutes * 60)
            let timeString =
            StageDetailView.walkTimeFormatter.string(from: estimatedSeconds)
            ?? "\(estimatedWalkMinutes) min"
            return "\(distanceString) • ~\(timeString)"
        }

        let airDistanceRoundedTo10m = Int(distance / 10.0) * 10
        let distanceString = StageDetailView.distanceFormatter.string(
            from: Measurement(
                value: Double(airDistanceRoundedTo10m),
                unit: UnitLength.meters
            )
        )
        return distanceString
    }
}

private func loadWalkDistancesByStage(fileName: String) -> [Int: [Int: Double]] {
    guard let url = Bundle.main.url(forResource: fileName, withExtension: "json") else {
        print("Could not find file \(fileName).json in bundle")
        return [:]
    }

    do {
        let data = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode([String: [String: Double]].self, from: data)
        return decoded.reduce(into: [Int: [Int: Double]]()) { partialResult, entry in
            guard let sourceStageId = Int(entry.key) else {
                return
            }
            let convertedTargets = entry.value.reduce(into: [Int: Double]()) {
                targetResult,
                targetEntry in
                guard let targetStageId = Int(targetEntry.key) else {
                    return
                }
                targetResult[targetStageId] = targetEntry.value
            }
            partialResult[sourceStageId] = convertedTargets
        }
    } catch {
        print("Error decoding \(fileName).json: \(error)")
        return [:]
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
