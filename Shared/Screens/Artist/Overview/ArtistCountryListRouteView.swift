import MapKit
import SwiftUI

struct ArtistCountryListRouteView: View {
    let countryCode: String
    let imageTransitionNamespace: Namespace.ID?

    @EnvironmentObject private var dataStore: DataStore
    @StateObject private var overlayLoader = GeoJSONCountryOverlayLoader.detailPreviewShared
    @Namespace private var localImageTransitionNamespace
    @State private var layout: CountryArtistLayout = .grid

    private let gridColumns = Array(
        repeating: GridItem(.flexible(), spacing: 11),
        count: 3
    )

    private var resolvedImageTransitionNamespace: Namespace.ID {
        imageTransitionNamespace ?? localImageTransitionNamespace
    }

    private var navigationTitleText: String {
        localizedCountryName(forRegionCode: countryCode)
    }

    private var flagText: String {
        emojiFlag(forRegionCode: countryCode) ?? ""
    }

    private var compactCountText: String {
        if Locale.current.language.languageCode?.identifier == "de" {
            return "\(countryArtists.count) Künstler"
        }
        return "\(countryArtists.count) artists"
    }

    private var countryArtists: [Artist] {
        guard case .success(let data) = dataStore.data else {
            return []
        }

        return data.artists
            .filter { artist in
                !artist.hiddenFromArtistList
                    && artist.countryCodes.contains(countryCode)
            }
            .sorted { first, second in
                normalizeArtistName(first.name) < normalizeArtistName(second.name)
            }
    }

    var body: some View {
        Group {
            switch dataStore.data {
            case .loading:
                ProgressView()
            case .failure(let reason):
                Text("Failed to load: " + reason.rawValue)
            case .success:
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        countryHeader

                        if countryArtists.isEmpty {
                            Text("artists.none-found")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 32)
                        } else if layout == .grid {
                            LazyVGrid(columns: gridColumns, spacing: 18) {
                                ForEach(countryArtists) { artist in
                                    NavigationLink(
                                        value: AppNavigationRoute.artist(
                                            id: artist.id,
                                            highlightedEventId: nil,
                                            transitionSourceID: artist.id
                                        )
                                    ) {
                                        ArtistGridCell(
                                            artist: artist,
                                            imageTransitionNamespace: resolvedImageTransitionNamespace
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.bottom, 24)
                        } else {
                            VStack(alignment: .leading, spacing: 10) {
                                countrySectionHeader("artists.title")

                                LazyVStack(spacing: 0) {
                                    ForEach(countryArtists) { artist in
                                        NavigationLink(
                                            value: AppNavigationRoute.artist(
                                                id: artist.id,
                                                highlightedEventId: nil,
                                                transitionSourceID: nil
                                            )
                                        ) {
                                            CountryArtistListRow(artist: artist)
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 10)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)

                                        if artist.id != countryArtists.last?.id {
                                            Divider()
                                                .padding(.leading, 96)
                                        }
                                    }
                                }
                                .background(
                                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                                        .fill(.thinMaterial)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                                        .stroke(Color.primary.opacity(0.08), lineWidth: 0.8)
                                )
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 24)
                        }
                    }
                    .padding(.top, 16)
                }
                .background(Color.primary.opacity(0.02))
                .task {
                    overlayLoader.loadIfNeeded()
                }
            }
        }
        .navigationTitle(navigationTitleText)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                CountryArtistLayoutPicker(layout: $layout)
            }
        }
    }

    private var countryHeader: some View {
        VStack(spacing: 16) {
            CountryBorderPreview(
                countryCode: countryCode,
                loadedMap: overlayLoader.loadedMap
            )
            .frame(width: 240, height: 180)
            .frame(maxWidth: .infinity)

            VStack(spacing: 10) {
                if !flagText.isEmpty {
                    HStack(spacing: 10) {
                        Text(flagText)
                            .font(.system(size: 34))

                        Text(navigationTitleText)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                }

                countryMetaChip(text: compactCountText, systemImage: "person.2.fill")
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }

    private func countryMetaChip(text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.regularMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(Color.white.opacity(0.35), lineWidth: 0.8)
            )
    }

    private func countrySectionHeader(_ titleKey: LocalizedStringKey) -> some View {
        Text(titleKey)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 2)
    }
}

private enum CountryArtistLayout: Int, CaseIterable, Identifiable {
    case grid
    case list

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .grid:
            return "Grid"
        case .list:
            return "List"
        }
    }

    var systemImage: String {
        switch self {
        case .grid:
            return "square.grid.2x2"
        case .list:
            return "list.bullet"
        }
    }
}

private struct CountryArtistLayoutPicker: View {
    @Binding var layout: CountryArtistLayout

    var body: some View {
        Menu {
            ForEach(CountryArtistLayout.allCases) { option in
                Button {
                    layout = option
                } label: {
                    if layout == option {
                        Label(option.title, systemImage: "checkmark")
                    } else {
                        Label(option.title, systemImage: option.systemImage)
                    }
                }
            }
        } label: {
            Label(layout.title, systemImage: layout.systemImage)
        }
        .labelStyle(.iconOnly)
    }
}

private struct CountryArtistListRow: View {
    let artist: Artist

    @EnvironmentObject private var settings: UserSettings

    private var artistRating: Int {
        settings.ratings["\(artist.id)"] ?? 0
    }

    var body: some View {
        HStack(spacing: 12) {
            ArtistImageView(artist: artist, fullImage: false)
                .frame(width: 64, height: 56)
                .clipShape(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                )

            Text(artist.formattedName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            if artistRating != 0 {
                ArtistRatingSymbol(artist: artist)
                    .foregroundStyle(.secondary)
            }
        }
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

private func normalizeArtistName(_ name: String) -> String {
    name.folding(
        options: [
            .diacriticInsensitive, .caseInsensitive, .widthInsensitive,
        ],
        locale: Locale.current
    )
}

private func emojiFlag(forRegionCode code: String) -> String? {
    guard let alpha2Code = alpha2CountryCode(forRegionCode: code) else {
        return nil
    }

    let base: UInt32 = 127397
    let scalars = alpha2Code.uppercased().unicodeScalars.compactMap {
        UnicodeScalar(base + $0.value)
    }
    guard scalars.count == 2 else {
        return nil
    }
    return String(String.UnicodeScalarView(scalars))
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
