//
// Created by Leon on 27.02.20.
// Copyright (c) 2020 Leon Georgi. All rights reserved.
//

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

    @EnvironmentObject var dataStore: DataStore

    @State var selectedDay: Int = -1
    @State private var isShowingInteractiveMap = false
    @State private var interactiveMapRecenterTrigger = 0
    @State private var onlyStagesWithConcerts = true

    func events(_ entities: FestivalData) -> [Int: [Event]] {
        Dictionary(
            grouping: entities.events.filter { event in
                event.stage.id == stage.id
            }
        ) { (event: Event) in
            event.festivalDay
        }
    }

    func eventDays(_ entities: FestivalData) -> [Int] {
        events(entities).keys.sorted().filter { day in
            if DataStore.year == 2023 && day < 6 {
                return false
            } else {
                return true
            }
        }
    }

    private var nearbySectionTint: Color {
        Color(.secondarySystemBackground)
    }

    private var nearbyStages: [StageDistance] {
        guard case .success(let entities) = dataStore.data else {
            return []
        }
        return calculateNearbyStages(entities)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                    topMapHero
                        .padding(.top, 16)

                    stageHeader
                        .padding(.horizontal, 16)
                        .padding(.top, 20)

                    eventsSection
                        .padding(.top, 18)

                    if !nearbyStages.isEmpty {
                        nearbyStagesSection
                            .padding(.top, 20)
                    }
            }
            .padding(.bottom, 28)
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .tabBar)
        .onAppear {
            if case .success(let entities) = dataStore.data {
                let days = self.eventDays(entities)
                let highlightedEventDay = entities.events.first { event in
                    event.id == highlightedEventId
                }?.festivalDay
                self.selectedDay =
                    highlightedEventDay ?? Util.getCurrentFestivalDay(
                        eventDays: days
                    ) ?? days.first ?? -1
            }
        }
        .fullScreenCover(isPresented: $isShowingInteractiveMap) {
            NavigationStack {
                ZStack(alignment: .bottomTrailing) {
                    StageMapView(
                        stage: stage,
                        isInteractive: true,
                        recenterTrigger: interactiveMapRecenterTrigger
                    )
                    .ignoresSafeArea()

                    Button {
                        interactiveMapRecenterTrigger += 1
                    } label: {
                        Image(systemName: "location")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .modifier(MapLocateButtonStyle())
                    .padding(.trailing, 16)
                    .padding(.bottom, 24)
                    .accessibilityLabel(Text("Show my location"))
                }
                .navigationTitle(stage.localizedName)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Close") {
                                isShowingInteractiveMap = false
                            }
                        }

                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                StageMapView.openInMaps(stage: stage)
                            } label: {
                                Label("Open in Maps", systemImage: "map")
                            }
                        }
                    }
            }
        }
    }

    private var stageHeader: some View {
        VStack(spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                StageNumber(stage: stage, size: 34)

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

    @ViewBuilder
    private var eventsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("stage.events")

            switch dataStore.data {
            case .loading:
                Text("stage.events.loading")
                    .foregroundStyle(.secondary)
            case .failure(let reason):
                Text("Failed to load: " + reason.rawValue)
                    .foregroundStyle(.secondary)
            case .success(let entities):
                let days = eventDays(entities)
                if !days.isEmpty {
                    Picker("Date", selection: $selectedDay) {
                        ForEach(days) { day in
                            Text(Util.shortWeekDay(day: day)).tag(day)
                        }
                    }
                    .pickerStyle(.segmented)

                    VStack(spacing: 0) {
                        ForEach(Array((events(entities)[selectedDay] ?? []).enumerated()), id: \.element.id) { index, event in
                            renderEvent(event)

                            if index < (events(entities)[selectedDay] ?? []).count - 1 {
                                Divider()
                                    .padding(.leading, 90)
                            }
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
            .frame(height: 188)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(0.22), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.28), radius: 18, x: 0, y: 10)
            .padding(.horizontal, 34)
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.clear)
                    .padding(.horizontal, 34)
                    .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .onTapGesture {
                        isShowingInteractiveMap = true
                    }
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(Text("stage.map"))
    }

    private var nearbyStagesSection: some View {
        let sortedNearbyStages = nearbyStages.sorted { first, second in
            first.distance < second.distance
        }
        let filteredNearbyStages: [StageDistance]
        if onlyStagesWithConcerts, case .success(let entities) = dataStore.data {
            let stageIdsWithEvents = Set(entities.events.map { $0.stage.id })
            filteredNearbyStages = sortedNearbyStages.filter { stageDistance in
                stageIdsWithEvents.contains(stageDistance.stage.id)
            }
        } else {
            filteredNearbyStages = sortedNearbyStages
        }

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                sectionHeader("stage.nearby")
                Spacer()
                Button {
                    onlyStagesWithConcerts.toggle()
                } label: {
                    HStack(spacing: 6) {
                        Image(
                            systemName: onlyStagesWithConcerts
                                ? "checkmark.square.fill" : "square"
                        )
                        Text("Only stages")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 0) {
                ForEach(Array(filteredNearbyStages.enumerated()), id: \.element.id) { index, stageDistance in
                    NavigationLink(
                        value: AppNavigationRoute.stage(
                            id: stageDistance.stage.id,
                            highlightedEventId: nil
                        )
                    ) {
                        HStack(spacing: 12) {
                            StageNumber(stage: stageDistance.stage, size: 26)

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

                    if index < filteredNearbyStages.count - 1 {
                        Divider()
                            .padding(.leading, 40)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 18)
        .padding(.bottom, 30)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(nearbySectionTint)
    }

    private func sectionHeader(_ titleKey: LocalizedStringKey) -> some View {
        Text(titleKey)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    func calculateNearbyStages(_ entities: FestivalData) -> [StageDistance] {
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

    func renderEvent(_ event: Event) -> some View {
        let shouldBeHighlighted = highlightedEventId == event.id
        return NavigationLink(
            value: AppNavigationRoute.artist(
                id: event.artist.id,
                highlightedEventId: event.id
            )
        ) {
            StageEventCell(event: event, imageWidth: 64, imageHeight: 56)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    shouldBeHighlighted ? Color.yellow.opacity(0.22) : Color.clear
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, -16)
    }

    func calculateAirDistance(first: Stage, second: Stage) -> Double {
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

private struct MapLocateButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .controlSize(.large)
        } else {
            content
                .frame(width: 36, height: 36)
                .background(.ultraThinMaterial, in: Circle())
                .clipShape(Circle())
        }
    }
}

struct StageDistance: Identifiable {
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

extension Int: Identifiable {
    public var id: Int {
        self
    }
}

struct StageDetailView_Previews: PreviewProvider {
    static var previews: some View {
        StageDetailView(stage: .example, highlightedEventId: nil)
            .environmentObject(DataStore())
            .environmentObject(UserSettings())
    }
}
