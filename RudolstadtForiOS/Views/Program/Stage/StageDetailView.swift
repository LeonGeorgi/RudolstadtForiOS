//
// Created by Leon on 27.02.20.
// Copyright (c) 2020 Leon Georgi. All rights reserved.
//

import Foundation
import SwiftUI
import MapKit

struct StageDetailView: View {
    let stage: Stage
    @EnvironmentObject var dataStore: DataStore

    @State var nearbyStages: [StageDistance] = []
    @State var selectedDay: Int = -1

    var events: Dictionary<Int, [Event]> {
        Dictionary(grouping: dataStore.events.filter { event in
            event.stage.id == stage.id
        }) { (event: Event) in
            event.festivalDay
        }
    }

    var eventDays: [Int] {
        events.keys.sorted()
    }


    var body: some View {
        List {
            HStack(spacing: 12) {
                if stage.stageNumber != nil {
                    Text(String(stage.stageNumber!))
                            .frame(width: 40, height: 40)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(.infinity)

                }
                VStack(alignment: .leading) {
                    if stage.localizedDescription != nil {
                        Text(stage.localizedDescription!)
                                .font(.headline)
                    }
                    Text(stage.area.localizedName)
                            .font(.subheadline)
                }

            }
            if !eventDays.isEmpty {
                Section(header: Text("stage.events")) {
                    Picker("Date", selection: $selectedDay) {
                        ForEach(eventDays) { day in
                            Text(Util.shortWeekDay(day: day)).tag(day)
                        }
                    }
                            .pickerStyle(SegmentedPickerStyle())
                    ForEach(events[selectedDay] ?? []) { (event: Event) in
                        NavigationLink(destination: ArtistDetailView(artist: event.artist)) {
                            StageEventCell(event: event)
                        }.buttonStyle(PlainButtonStyle())

                    }


                }
            }

            Section(header: Text("stage.map")) {
                Button(action: {
                    StageMapView.openInMaps(stage: self.stage)
                }) {
                    StageMapView(stage: stage)
                            .frame(minHeight: 300)
                }.listRowInsets(EdgeInsets())
                        .buttonStyle(PlainButtonStyle())
            }
            if !nearbyStages.isEmpty {
                Section(header: Text("stage.nearby")) {
                    ForEach(nearbyStages.sorted { first, second in
                        first.distance < second.distance
                    }) { (stageDistance: StageDistance) in
                        NavigationLink(destination: StageDetailView(
                                stage: stageDistance.stage
                        )) {
                            VStack(alignment: .leading) {
                                Text(stageDistance.stage.localizedName).lineLimit(1)
                                Text("\(Int(stageDistance.distance / 10) * 10) METER")
                                        .font(.caption)
                            }
                        }
                    }
                }
            }

        }.listStyle(GroupedListStyle())
                .navigationBarTitle(stage.localizedName)
                .onAppear {
                    self.calculateNearbyStages()
                    self.selectedDay = self.eventDays.first ?? -1
                }
    }

    func calculateNearbyStages() {
        self.nearbyStages = dataStore.stages.filter { stage in
            stage.area.id == self.stage.area.id && stage.id != self.stage.id
        }.map { stage in
            StageDistance(stage: stage, distance: calculateAirDistance(first: self.stage, second: stage))
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

    func calculateAirDistance(first: Stage, second: Stage) -> Double {
        let start = CLLocation(latitude: first.latitude, longitude: first.longitude)
        let destination = CLLocation(latitude: second.latitude, longitude: second.longitude)
        return destination.distance(from: start)
    }

    func calculateWalkingDistance(first: Stage, second: Stage, completion: @escaping (Double) -> Void) {

        let start = CLLocation(latitude: first.latitude, longitude: first.longitude)
        let destination = CLLocation(latitude: second.latitude, longitude: second.longitude)

        let request: MKDirections.Request = MKDirections.Request()

        let sourcePM = MKPlacemark(coordinate: start.coordinate)
        let destinationPM = MKPlacemark(coordinate: destination.coordinate)
        request.source = MKMapItem(placemark: sourcePM)
        request.destination = MKMapItem(placemark: destinationPM)

        // Walking distance
        request.transportType = MKDirectionsTransportType.walking;

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
        StageDetailView(stage: .example)
            .environmentObject(DataStore())
            .environmentObject(UserSettings())
    }
}
