import MapKit
import SwiftUI

struct ArtistCountryListRouteView: View {
    let countryCode: String
    let imageTransitionNamespace: Namespace.ID?
    var showsCountryPreview = true
    var onSelectArtist: ((AppNavigationRoute) -> Void)? = nil

    @Environment(\.festivalData) private var festivalData
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @EnvironmentObject private var settings: UserSettings
    @EnvironmentObject private var profile: FestivalProfileStore
    @EnvironmentObject private var friends: FriendProfilesStore
    @StateObject private var overlayLoader = GeoJSONCountryOverlayLoader.detailPreviewShared
    @Namespace private var localImageTransitionNamespace
    @State private var layout: ArtistPresentationMode = .grid

    private var gridColumns: [GridItem] {
        ArtistGridLayout.columns(
            for: dynamicTypeSize,
            density: settings.artistGridDensity
        )
    }

    private var resolvedImageTransitionNamespace: Namespace.ID {
        imageTransitionNamespace ?? localImageTransitionNamespace
    }

    private var navigationTitleText: String {
        localizedCountryName(forRegionCode: countryCode)
    }

    private var countryArtists: [Artist] {
        festivalData.artists
            .filter { artist in
                !artist.hiddenFromArtistList
                    && artist.countryCodes.contains(countryCode)
            }
            .sorted { first, second in
                normalizedArtistName(first.name) < normalizedArtistName(second.name)
            }
    }

    var body: some View {
        let artists = countryArtists

        let countText = String(
            format: NSLocalizedString(
                artists.count == 1
                    ? "artists.map.accessibility.artist_count.one"
                    : "artists.map.accessibility.artist_count.other",
                comment: ""
            ),
            locale: Locale.current,
            artists.count
        )

        Group {
            if #available(iOS 26.0, macOS 11.0, *) {
                countryContent(artists)
                    .navigationSubtitle(countText)
            } else {
                VStack(spacing: 0) {
                    Text(countText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                    countryContent(artists)
                }
            }
        }
        .task {
            if showsCountryPreview { overlayLoader.loadIfNeeded() }
        }
        .navigationTitle("\(emojiFlag(forRegionCode: countryCode) ?? "") \(navigationTitleText)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                CountryArtistLayoutPicker(layout: $layout)
            }
        }
    }

    private func countryContent(_ artists: [Artist]) -> some View {
        Group {
            if artists.isEmpty {
                Text("artists.none-found")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if layout == .grid {
                ScrollView {
                    VStack(spacing: 16) {
                        countryPreview

                        LazyVGrid(
                            columns: gridColumns,
                            spacing: ArtistGridLayout.rowSpacing
                        ) {
                            ForEach(artists) { artist in
                                artistLink(artist, transitionSourceID: artist.id) {
                                    ArtistGridCell(
                                        artist: artist,
                                        imageTransitionNamespace: resolvedImageTransitionNamespace,
                                        artistRating: profile.rating(for: artist.id),
                                        artistIconName: profile.iconName(forArtistID: artist.id),
                                        friendRatingSummary: friends.friendArtistRatingSummary(for: artist.id)
                                    )
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("country-artist-\(artist.id)")
                            }
                        }
                    }
                    .padding(.horizontal, ArtistGridLayout.horizontalPadding)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            } else {
                List {
                    if showsCountryPreview {
                        countryPreview
                            .listRowSeparator(.hidden)
                    }

                    ForEach(artists) { artist in
                        artistLink(artist, transitionSourceID: nil) {
                            ArtistCell(
                                artist: artist,
                                artistRating: profile.rating(for: artist.id),
                                artistIconName: profile.iconName(forArtistID: artist.id),
                                friendRatingSummary: friends.friendArtistRatingSummary(for: artist.id)
                            )
                        }
                        .accessibilityIdentifier("country-artist-\(artist.id)")
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func artistLink<Label: View>(_ artist: Artist, transitionSourceID: Int?, @ViewBuilder label: () -> Label) -> some View {
        let route = AppNavigationRoute.artist(
            id: artist.id,
            highlightedEventId: nil,
            transitionSourceID: onSelectArtist == nil ? transitionSourceID : nil
        )
        if let onSelectArtist {
            Button { onSelectArtist(route) } label: { label() }
        } else {
            NavigationLink(value: route, label: label)
        }
    }

    @ViewBuilder
    private var countryPreview: some View {
        if showsCountryPreview {
            CountryBorderPreview(
                countryCode: countryCode,
                loadedMap: overlayLoader.loadedMap
            )
            .frame(width: 240, height: 180)
            .frame(maxWidth: .infinity)
        }
    }
}

private struct CountryArtistLayoutPicker: View {
    @Binding var layout: ArtistPresentationMode

    var body: some View {
        Menu {
            Picker("artists.view.layout", selection: $layout) {
                ForEach([ArtistPresentationMode.grid, .list], id: \.self) { option in
                    Label(option.localizedTitle, systemImage: option.systemImageName)
                        .tag(option)
                }
            }
            .pickerStyle(.inline)
        } label: {
            Label(layout.localizedTitle, systemImage: layout.systemImageName)
        }
        .labelStyle(.iconOnly)
    }
}

private struct CountryBorderPreview: View {
    let countryCode: String
    let loadedMap: LoadedWorldCountryMap?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let path = countryPreviewPath(
                    for: countryCode,
                    loadedMap: loadedMap,
                    size: proxy.size,
                    inset: 4
                ) {
                    path
                        .fill(Color.rudolstadt.opacity(0.18))
                        .overlay {
                            path
                                .stroke(Color.rudolstadt, lineWidth: 2)
                        }
                } else {
                    Image(systemName: "globe.europe.africa.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private func countryPreviewPath(
    for countryCode: String,
    loadedMap: LoadedWorldCountryMap?,
    size: CGSize,
    inset: CGFloat
) -> Path? {
    guard let loadedMap else {
        return nil
    }

    let polygons = loadedMap.overlays.filter { overlay in
        loadedMap.overlayMetadataByID[ObjectIdentifier(overlay)]?.code == countryCode
    }
    guard !polygons.isEmpty else {
        return nil
    }

    var boundingRect = MKMapRect.null
    for polygon in polygons {
        boundingRect = boundingRect.isNull
            ? polygon.boundingMapRect
            : boundingRect.union(polygon.boundingMapRect)
    }
    guard !boundingRect.isNull else {
        return nil
    }

    let drawableRect = CGRect(
        x: inset,
        y: inset,
        width: size.width - inset * 2,
        height: size.height - inset * 2
    )

    let scale = min(
        drawableRect.width / boundingRect.size.width,
        drawableRect.height / boundingRect.size.height
    )

    let xOffset = drawableRect.midX - (boundingRect.size.width * scale) / 2
    let yOffset = drawableRect.midY - (boundingRect.size.height * scale) / 2

    var path = Path()
    for polygon in polygons {
        addPreviewPath(
            of: polygon,
            to: &path,
            boundingRect: boundingRect,
            scale: scale,
            xOffset: xOffset,
            yOffset: yOffset
        )
        for interior in polygon.interiorPolygons ?? [] {
            addPreviewPath(
                of: interior,
                to: &path,
                boundingRect: boundingRect,
                scale: scale,
                xOffset: xOffset,
                yOffset: yOffset
            )
        }
    }
    return path
}

private func addPreviewPath(
    of polygon: MKPolygon,
    to path: inout Path,
    boundingRect: MKMapRect,
    scale: CGFloat,
    xOffset: CGFloat,
    yOffset: CGFloat
) {
    guard polygon.pointCount > 0 else {
        return
    }

    let points = polygon.points()
    let first = CGPoint(
        x: xOffset + CGFloat(points[0].x - boundingRect.origin.x) * scale,
        y: yOffset + CGFloat(points[0].y - boundingRect.origin.y) * scale
    )
    path.move(to: first)

    for index in 1..<polygon.pointCount {
        path.addLine(
            to: CGPoint(
                x: xOffset + CGFloat(points[index].x - boundingRect.origin.x) * scale,
                y: yOffset + CGFloat(points[index].y - boundingRect.origin.y) * scale
            )
        )
    }

    path.closeSubpath()
}
