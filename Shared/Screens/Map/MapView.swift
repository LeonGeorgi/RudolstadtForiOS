//
//  ActualMapView.swift
//  RudolstadtForiOS (iOS)
//
//  Created by Leon Georgi on 14.06.22.
//

import MapKit
import SwiftUI

struct MapView: View, Equatable {
    static func == (lhs: MapView, rhs: MapView) -> Bool {
        lhs.locations.map { location in
            location.stage.id
        }
            == rhs.locations.map { location in
                location.stage.id
            }
    }

    var locations: [MapLocation]

    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(
            latitude: 50.719877,
            longitude: 11.338449
        ),
        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
    )

    @StateObject private var manager = LocationManager()
    @State private var enabledStageFilters = Set(MapLegendFilter.allCases)

    private var filteredLocations: [MapLocation] {
        locations.filter { location in
            enabledStageFilters.contains(MapLegendFilter(stageType: location.stage.stageType))
        }
    }

    var body: some View {
        Map(
            coordinateRegion: $mapRegion,
            showsUserLocation: true,
            annotationItems: filteredLocations
        ) { annotation in
            MapAnnotation(coordinate: annotation.coordinate) {
                NavigationLink(
                    value: AppNavigationRoute.stage(
                        id: annotation.stage.id,
                        highlightedEventId: nil
                    )
                ) {
                    VStack {
                        StageNumber(
                            stage: annotation.stage,
                            size: 25,
                            font: .system(size: 15)
                        )
                    }
                }
            }
        }
        .mapStyle(
            .standard(
                elevation: .realistic,
                pointsOfInterest: .including([.atm]),
            )
        )
        .accentColor(.blue)
        .onAppear {
            manager.startLocationTracking()
        }
        .ignoresSafeArea()
        .overlay(alignment: .top) {
            VStack(spacing: 8) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        legendToggleChip(
                            filter: .festivalTicket,
                            color: StageNumber.baseColor(for: .festivalTicket),
                            title: "ticket.type.festival"
                        )
                        legendToggleChip(
                            filter: .festivalAndDayTicket,
                            color: StageNumber.baseColor(for: .festivalAndDayTicket),
                            title: "ticket.type.day-and-festival"
                        )
                        legendToggleChip(
                            filter: .other,
                            color: StageNumber.baseColor(for: .other),
                            title: "ticket.type.other"
                        )
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
                .scrollClipDisabled()
            }
            .padding(.top, 8)
            .padding(.horizontal, 10)
        }
    }

    private func legendToggleChip(
        filter: MapLegendFilter,
        color: Color,
        title: LocalizedStringKey
    ) -> some View {
        let isEnabled = enabledStageFilters.contains(filter)

        return Button {
            toggle(filter)
        } label: {
            HStack(spacing: 6) {
                renderCircle(color)
                    .saturation(isEnabled ? 1 : 0)
                    .opacity(isEnabled ? 1 : 0.35)
                Text(title)
                    .lineLimit(1)
                    .opacity(isEnabled ? 1 : 0.6)
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, 3)
            .padding(.vertical, 3)
        }
        .modifier(
            MapLegendChipButtonStyle(
                isEnabled: isEnabled,
                tintColor: color
            )
        )
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(isEnabled ? "On" : "Off"))
    }

    private func toggle(_ filter: MapLegendFilter) {
        if enabledStageFilters.contains(filter) {
            // Keep at least one filter active so users don't accidentally hide all locations.
            if enabledStageFilters.count > 1 {
                enabledStageFilters.remove(filter)
            }
        } else {
            enabledStageFilters.insert(filter)
        }
    }

    private func renderCircle(_ color: Color) -> some View {
        let size: CGFloat = 15
        let ringWidth = max(1, size * 0.06)

        return Circle()
            .frame(width: size, height: size)
            .foregroundStyle(
                LinearGradient(
                    colors: [color.opacity(0.82), color.opacity(1.0)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Circle()
                    .stroke(.white.opacity(0.65), lineWidth: ringWidth)
                    .blur(radius: ringWidth * 0.25)
            )
            .overlay(
                Circle()
                    .stroke(.black.opacity(0.15), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.16), radius: 2, y: 1)
    }
}

private enum MapLegendFilter: CaseIterable, Hashable {
    case festivalTicket
    case festivalAndDayTicket
    case other

    init(stageType: StageType) {
        switch stageType {
        case .festivalTicket:
            self = .festivalTicket
        case .festivalAndDayTicket:
            self = .festivalAndDayTicket
        case .other, .unknown:
            self = .other
        }
    }
}

private struct MapLegendChipButtonStyle: ViewModifier {
    let isEnabled: Bool
    let tintColor: Color

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)
                .controlSize(.mini)
                .tint(isEnabled ? tintColor : .gray.opacity(0.55))
        } else {
            content
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .tint(isEnabled ? tintColor : .gray)
        }
    }
}

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    override init() {
        super.init()
    }

    func startLocationTracking() {
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }
}

struct MapView_Previews: PreviewProvider {
    static var previews: some View {
        MapView(locations: [])
    }
}
