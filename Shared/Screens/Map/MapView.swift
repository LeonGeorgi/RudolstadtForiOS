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
    let currentTipID: String?

    @State private var cameraPosition: MapCameraPosition = .region(
        Self.initialFestivalRegion
    )
    @State private var isAdjustingRegion = false

    @StateObject private var manager = LocationManager()
    @State private var enabledStageFilters = Set(MapLegendFilter.allCases)

    private static let initialFestivalRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(
            latitude: 50.719877,
            longitude: 11.338449
        ),
        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
    )

    private static let recenterFestivalRegion = MKCoordinateRegion(
        center: initialFestivalRegion.center,
        span: MKCoordinateSpan(latitudeDelta: 0.024, longitudeDelta: 0.024)
    )

    private static let maximumZoomOutSpan = MKCoordinateSpan(
        latitudeDelta: 0.06,
        longitudeDelta: 0.06
    )

    private var filteredLocations: [MapLocation] {
        locations.filter { location in
            enabledStageFilters.contains(MapLegendFilter(stageType: location.stage.stageType))
        }
    }

    var body: some View {
        Map(
            position: $cameraPosition,
            interactionModes: [.pan, .zoom]
        ) {
            UserAnnotation()

            ForEach(filteredLocations) { annotation in
                Annotation(
                    "",
                    coordinate: annotation.coordinate,
                    anchor: .bottom
                ) {
                    NavigationLink(
                        value: AppNavigationRoute.stage(
                            id: annotation.stage.id,
                            highlightedEventId: nil
                        )
                    ) {
                        VStack {
                            StageNumber(
                                stage: annotation.stage,
                                size: 28,
                                font: .system(size: 15)
                            )
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("festival-map")
        .mapStyle(
            .standard(
                elevation: .realistic,
                pointsOfInterest: .including([.atm]),
            )
        )
        .accentColor(.rudolstadt)
        .onMapCameraChange(frequency: .continuous) { context in
            guard !isAdjustingRegion else {
                return
            }

            let clampedRegion = clampedZoomOutRegion(for: context.region)
            guard !clampedRegion.isApproximatelyEqual(to: context.region) else {
                return
            }

            isAdjustingRegion = true
            cameraPosition = .region(clampedRegion)
            isAdjustingRegion = false
        }
        .onAppear {
            manager.startLocationTracking()
        }
        .ignoresSafeArea()
        .overlay(alignment: .top) {
            VStack(spacing: 8) {
                AppInlineTipView(
                    tip: DiscoverabilityTips.mapLegend,
                    currentTipID: currentTipID,
                    arrowEdge: .bottom
                )

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
        .overlay(alignment: .bottomTrailing) {
            Button {
                recenterToFestivalArea(animated: true)
            } label: {
                Image(systemName: "scope")
                    .font(.title3.weight(.semibold))
                    .frame(width: 36, height: 36)
            }
            .modifier(MapRecenterButtonStyle())
            .padding(.trailing, 16)
            .padding(.bottom, 24)
            .accessibilityLabel("Center on festival area")
            .appPopoverTip(
                DiscoverabilityTips.mapRecenter,
                currentTipID: currentTipID,
                arrowEdge: .leading
            )
        }
    }

    private func recenterToFestivalArea(animated: Bool) {
        let update = {
            cameraPosition = .region(Self.recenterFestivalRegion)
        }

        if animated {
            withAnimation(.easeInOut(duration: 0.28), update)
        } else {
            update()
        }
    }

    private func clampedZoomOutRegion(for region: MKCoordinateRegion) -> MKCoordinateRegion {
        MKCoordinateRegion(
            center: region.center,
            span: MKCoordinateSpan(
                latitudeDelta: Swift.min(
                    region.span.latitudeDelta,
                    Self.maximumZoomOutSpan.latitudeDelta
                ),
                longitudeDelta: Swift.min(
                    region.span.longitudeDelta,
                    Self.maximumZoomOutSpan.longitudeDelta
                )
            )
        )
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

        return Circle()
            .frame(width: size, height: size)
            .foregroundStyle(color)
            .overlay(
                Circle()
                    .frame(width: size * 0.42, height: size * 0.42)
                    .foregroundStyle(.white.opacity(0.16))
                    .offset(x: -size * 0.17, y: -size * 0.17)
            )
            .overlay(
                Circle()
                    .stroke(.black.opacity(0.12), lineWidth: 1)
            )
            .overlay(
                Circle()
                    .inset(by: size * 0.12)
                    .stroke(.white.opacity(0.28), lineWidth: 0.8)
            )
            .shadow(color: .black.opacity(0.14), radius: 1.6, y: 1)
    }
}

private extension MKCoordinateRegion {
    func isApproximatelyEqual(
        to other: MKCoordinateRegion,
        tolerance: Double = 0.000_001
    ) -> Bool {
        abs(center.latitude - other.center.latitude) < tolerance
            && abs(center.longitude - other.center.longitude) < tolerance
            && abs(span.latitudeDelta - other.span.latitudeDelta) < tolerance
            && abs(span.longitudeDelta - other.span.longitudeDelta) < tolerance
    }
}

private struct MapRecenterButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .controlSize(.regular)
        } else {
            content
                .background(.ultraThinMaterial, in: Circle())
                .overlay {
                    Circle()
                        .stroke(.white.opacity(0.22), lineWidth: 0.8)
                }
                .shadow(color: .black.opacity(0.14), radius: 10, y: 4)
        }
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
        MapView(locations: [], currentTipID: nil)
    }
}
