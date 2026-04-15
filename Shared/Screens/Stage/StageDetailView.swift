//
// Created by Leon on 27.02.20.
// Copyright (c) 2020 Leon Georgi. All rights reserved.
//

import Foundation
import MapKit
import SwiftUI

struct StageDetailView: View {
    let stage: Stage
    let highlightedEventId: Int?

    @EnvironmentObject var dataStore: DataStore

    @State var nearbyStages: [StageDistance] = []
    @State var selectedDay: Int = -1
    @State private var nearbyBackgroundStartY = CGFloat.infinity
    @State private var isShowingInteractiveMap = false
    @State private var interactiveMapRecenterTrigger = 0
    @State private var selectedEventForNavigation: Event?

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

    private var isEventNavigationPresented: Binding<Bool> {
        Binding(
            get: { selectedEventForNavigation != nil },
            set: { isPresented in
                if !isPresented {
                    selectedEventForNavigation = nil
                }
            }
        )
    }

    var body: some View {
        ZStack {
            ArtistDetailSplitBackground(
                artistBackgroundColor: Color(.systemBackground),
                descriptionBackgroundColor: nearbySectionTint,
                descriptionBackgroundStartY: nearbyBackgroundStartY
            )

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
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .tabBar)
        .onPreferenceChange(DescriptionBackgroundStartPreferenceKey.self) { startY in
            nearbyBackgroundStartY = startY
        }
        .onAppear {
            if case .success(let entities) = dataStore.data {
                self.calculateNearbyStages(entities)
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
        .navigationDestination(isPresented: isEventNavigationPresented) {
            if let event = selectedEventForNavigation {
                ArtistDetailView(
                    artist: event.artist,
                    highlightedEventId: event.id
                )
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

        return VStack(alignment: .leading, spacing: 12) {
            sectionHeader("stage.nearby")

            VStack(spacing: 0) {
                ForEach(Array(sortedNearbyStages.enumerated()), id: \.element.id) { index, stageDistance in
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
                                Text("\(Int(stageDistance.distance / 10) * 10) METER")
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

                    if index < sortedNearbyStages.count - 1 {
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
        .background(
            nearbySectionTint
                .overlay {
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: DescriptionBackgroundStartPreferenceKey.self,
                            value: proxy.frame(in: .global).minY
                        )
                    }
                }
        )
    }

    private func sectionHeader(_ titleKey: LocalizedStringKey) -> some View {
        Text(titleKey)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    func calculateNearbyStages(_ entities: FestivalData) {
        self.nearbyStages = entities.stages.filter { stage in
            stage.area.id == self.stage.area.id && stage.id != self.stage.id
        }.map { stage in
            StageDistance(
                stage: stage,
                distance: calculateAirDistance(first: self.stage, second: stage)
            )
        }
        /*for stage in allStages {
            if stage == self.stage {
                continue
            }
            calculateWalkingDistance(first: self.stage, second: stage) { distance in
                if distance <= 500 {
                    self.nearbyStages.append(StageDistance(stage: stage, distance: distance))
                }
            }
        }*/
    }

    func renderEvent(_ event: Event) -> some View {
        let shouldBeHighlighted = highlightedEventId == event.id
        return StageEventCell(event: event, imageWidth: 64, imageHeight: 56)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                shouldBeHighlighted ? Color.yellow.opacity(0.22) : Color.clear
            )
            .contentShape(Rectangle())
            .onTapGesture {
                selectedEventForNavigation = event
            }
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

    func calculateWalkingDistance(
        first: Stage,
        second: Stage,
        completion: @escaping (Double) -> Void
    ) {

        let start = CLLocation(
            latitude: first.latitude,
            longitude: first.longitude
        )
        let destination = CLLocation(
            latitude: second.latitude,
            longitude: second.longitude
        )

        let request: MKDirections.Request = MKDirections.Request()

        let sourcePM = MKPlacemark(coordinate: start.coordinate)
        let destinationPM = MKPlacemark(coordinate: destination.coordinate)
        request.source = MKMapItem(placemark: sourcePM)
        request.destination = MKMapItem(placemark: destinationPM)

        // Walking distance
        request.transportType = MKDirectionsTransportType.walking

        // If you're open to getting more than one route,
        // requestsAlternateRoutes = true; else requestsAlternateRoutes = false;
        request.requestsAlternateRoutes = false

        let directions = MKDirections(request: request)

        directions.calculate { (response, error) in
            print((response, error))
            if let response = response, let route = response.routes.first {
                completion(route.expectedTravelTime)
            }
        }
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

    var id: Int {
        stage.id
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
