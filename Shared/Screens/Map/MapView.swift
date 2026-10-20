//
//  ActualMapView.swift
//  RudolstadtForiOS (iOS)
//
//  Created by Leon Georgi on 14.06.22.
//

import MapKit
import SwiftUI

struct MapView: View {
    private enum MapSheet: Hashable, Identifiable {
        case numbers
        case stage(Int)

        var id: Self { self }
        var stageID: Int? {
            if case let .stage(id) = self { return id }
            return nil
        }
    }

    var stages: [Stage]
    let currentTipID: String?

    @StateObject private var manager = LocationManager()
    @State private var enabledStageFilters = Set(MapLegendFilter.allCases)
    @State private var selectedStageID: Int?
    @State private var focusStageIDs: [Int] = []
    @State private var focusTrigger = 0
    @State private var presentedSheet: MapSheet?
    @State private var sheetDetent: PresentationDetent = .medium
    @State private var showsUserLocation = false
    @State private var enableUserLocationTask: Task<Void, Never>?

    private var numberedStages: [Stage] {
        stages.filter { $0.stageNumber != nil }.sorted {
            ($0.stageNumber ?? .max, $0.id) < ($1.stageNumber ?? .max, $1.id)
        }
    }

    private var locatedStages: [Stage] {
        var located = numberedStages.filter(\.hasLocation)
        if let selected = stages.first(where: { $0.id == selectedStageID }),
            selected.stageNumber == nil, selected.hasLocation {
            located.append(selected)
        }
        return located
    }

    private var filteredStages: [Stage] {
        locatedStages.filter {
            enabledStageFilters.contains(MapLegendFilter(stageType: $0.stageType))
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            FestivalMapCanvas(
                stages: filteredStages,
                overviewStages: locatedStages,
                selectedStageID: selectedStageID,
                focusStageIDs: focusStageIDs,
                focusTrigger: focusTrigger,
                showsUserLocation: showsUserLocation,
                isStageSheetPresented: presentedSheet?.stageID != nil,
                onSelectStage: selectStage
            )
            .ignoresSafeArea()

            VStack(alignment: .trailing, spacing: 12) {
                Button {
                    selectedStageID = nil
                    focusStageIDs = []
                    focusTrigger += 1
                } label: {
                    Image(systemName: "scope")
                }
                .modifier(MapRecenterButtonStyle())
                .accessibilityLabel("Center on festival area")
                .accessibilityIdentifier("festival-map-recenter")
                .appPopoverTip(
                    DiscoverabilityTips.mapRecenter,
                    currentTipID: currentTipID,
                    arrowEdge: .leading
                )
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding()
            .padding(.bottom, 32) // Leave the native map attribution unobstructed.
        }
        .overlay(alignment: .top) { legend }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    sheetDetent = .medium
                    presentedSheet = .numbers
                } label: {
                    Label("map.numbers.title", systemImage: "number")
                }
                .accessibilityIdentifier("festival-map-number-picker")
            }
        }
        .sheet(item: $presentedSheet, onDismiss: {
            if presentedSheet == nil { selectedStageID = nil }
        }) { sheet in
            Group {
                switch sheet {
                case .numbers:
                    FestivalMapNumberPicker(
                        stages: numberedStages,
                        selectedStageID: selectedStageID,
                        select: selectStage
                    )
                case .stage(let rootStageID):
                    if let stage = stages.first(where: { $0.id == rootStageID }) {
                        MapStageSheet(stage: stage, onSelectStage: selectStageFromSheet)
                            .id(stage.id)
                    }
                }
            }
            .presentationDetents([.medium, .large], selection: $sheetDetent)
            .presentationDragIndicator(.visible)
            .presentationBackgroundInteraction(
                sheet.stageID != nil ? .enabled(upThrough: .medium) : .disabled
            )
        }
        .tint(.rudolstadt)
        .onAppear {
            guard enableUserLocationTask == nil else { return }
            enableUserLocationTask = Task { @MainActor in
                await Task.yield()
                guard !Task.isCancelled else { return }
                showsUserLocation = true
                manager.startLocationTracking()
            }
        }
        .onDisappear {
            enableUserLocationTask?.cancel()
            enableUserLocationTask = nil
        }
        .onChange(of: stages.map(\.id)) { _, updatedIDs in
            if let selectedStageID, !updatedIDs.contains(selectedStageID) {
                self.selectedStageID = nil
                if presentedSheet?.stageID != nil { presentedSheet = nil }
            }
            if let rootStageID = presentedSheet?.stageID, !updatedIDs.contains(rootStageID) {
                presentedSheet = nil
            }
        }
    }

    private func selectStage(_ id: Int) {
        guard let stage = stages.first(where: { $0.id == id }) else { return }
        updateMapSelection(stage)
        if presentedSheet?.stageID == nil { sheetDetent = .medium }
        presentedSheet = .stage(id)
    }

    private func selectStageFromSheet(_ id: Int) {
        guard let stage = stages.first(where: { $0.id == id }) else { return }
        updateMapSelection(stage)
        sheetDetent = .medium
    }

    private func updateMapSelection(_ stage: Stage) {
        guard selectedStageID != stage.id else { return }
        selectedStageID = stage.id
        enabledStageFilters.insert(MapLegendFilter(stageType: stage.stageType))
        if stage.hasLocation {
            focusStageIDs = [stage.id]
            focusTrigger += 1
        }
    }

    private var legend: some View {
        VStack(spacing: 8) {
            AppInlineTipView(
                tip: DiscoverabilityTips.mapLegend,
                currentTipID: currentTipID,
                arrowEdge: .bottom
            )
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    legendToggleChip(filter: .festivalTicket,
                                     color: StageNumber.baseColor(for: .festivalTicket),
                                     title: "ticket.type.festival")
                    legendToggleChip(filter: .festivalAndDayTicket,
                                     color: StageNumber.baseColor(for: .festivalAndDayTicket),
                                     title: "ticket.type.day-and-festival")
                    legendToggleChip(filter: .other,
                                     color: StageNumber.baseColor(for: .other),
                                     title: "ticket.type.other")
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .scrollClipDisabled()
        }
        .padding(.top, 8)
        .padding(.horizontal, 10)
    }

    private func legendToggleChip(
        filter: MapLegendFilter,
        color: Color,
        title: LocalizedStringKey
    ) -> some View {
        let isEnabled = enabledStageFilters.contains(filter)
        return Button { toggle(filter) } label: {
            Label {
                Text(title)
            } icon: {
                Image(systemName: "circle.fill")
                    .foregroundStyle(isEnabled ? color : .secondary)
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .padding(3)
        }
        .modifier(MapLegendChipButtonStyle(isEnabled: isEnabled, tintColor: color))
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
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
        }
    }
}

private struct MapStageSheet: View {
    let stage: Stage
    let onSelectStage: (Int) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.festivalData) private var festivalData
    @State private var path: [AppNavigationRoute] = []

    private var activeStageID: Int {
        for route in path.reversed() {
            if case let .stage(id, _) = route { return id }
        }
        return stage.id
    }

    var body: some View {
        NavigationStack(path: $path) {
            StageDetailView(stage: stage, highlightedEventId: nil, showsMap: false)
                .navigationDestination(for: AppNavigationRoute.self) { route in
                    if case let .stage(id, highlightedEventId) = route {
                        if let nearbyStage = festivalData.stages.first(where: { $0.id == id }) {
                            StageDetailView(
                                stage: nearbyStage,
                                highlightedEventId: highlightedEventId,
                                showsMap: false
                            )
                        } else {
                            Text("locations.empty")
                        }
                    } else {
                        AppNavigationDestination(route: route, navigate: { path.append($0) })
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("common.done") { dismiss() }
                    }
                }
        }
        .onChange(of: activeStageID) { _, id in onSelectStage(id) }
    }
}

private struct MapLegendChipButtonStyle: ViewModifier {
    let isEnabled: Bool
    let tintColor: Color

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

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var didConfigureManager = false
    private var isUpdatingLocation = false

    override init() {
        super.init()
    }

    func startLocationTracking() {
        if !didConfigureManager {
            manager.delegate = self
            manager.desiredAccuracy = kCLLocationAccuracyBest
            didConfigureManager = true
        }

        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            guard !isUpdatingLocation else {
                return
            }
            isUpdatingLocation = true
            manager.startUpdatingLocation()
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            return
        @unknown default:
            return
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        startLocationTracking()
    }
}

struct MapView_Previews: PreviewProvider {
    static var previews: some View {
        MapView(stages: [], currentTipID: nil)
    }
}
