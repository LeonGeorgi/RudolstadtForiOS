//
//  ArtistListView.swift
//  RudolstadtForiOS
//
//  Created by Leon on 22.02.20.
//  Copyright © 2020 Leon Georgi. All rights reserved.
//

import CoreImage
import SwiftUI

// import URLImage

struct ArtistListView: View {

    @EnvironmentObject var settings: UserSettings

    @State private var shownArtistTypes = Set(ShownArtistTypes.allCases)
    @Namespace private var artistImageTransition

    @State var searchText = ""
    @State var favoriteArtistsOnly = false

    private let gridColumns = Array(
        repeating: GridItem(.flexible(), spacing: 10),
        count: 3
    )

    func normalize(string: String) -> String {
        string.folding(
            options: [
                .diacriticInsensitive, .caseInsensitive, .widthInsensitive,
            ],
            locale: Locale.current
        )
    }

    func getFilteredArtists(data: FestivalData) -> [Artist] {
        data.artists.filter { artist in
            shownArtistTypes.contains(ShownArtistTypes(artistType: artist.artistType))
        }
    }

    private var allArtistTypesSelected: Bool {
        shownArtistTypes.count == ShownArtistTypes.allCases.count
    }

    private func showAllArtistTypes() {
        shownArtistTypes = Set(ShownArtistTypes.allCases)
    }

    private func binding(for artistType: ShownArtistTypes) -> Binding<Bool> {
        Binding(
            get: {
                shownArtistTypes.contains(artistType)
            },
            set: { isSelected in
                if isSelected {
                    shownArtistTypes.insert(artistType)
                } else {
                    shownArtistTypes.remove(artistType)
                }
            }
        )
    }

    @ViewBuilder
    private var filterButtonLabel: some View {
        if allArtistTypesSelected {
            Image(systemName: "line.3.horizontal.decrease.circle")
        } else {
            ZStack {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 26, height: 26)
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
    }

    func generateArtistsToShow(artists: [Artist]) -> [Artist] {
        if favoriteArtistsOnly {
            let artists = artists.map { artist in
                (artist: artist, rating: settings.ratings[String(artist.id)])
            }
            let filteredArtists = artists.filter { item in
                item.rating != nil && item.rating! > 0
            }
            let sortedArtists = filteredArtists.sorted { first, second in
                first.rating! > second.rating!
            }
            return sortedArtists.map { artist, rating in
                artist
            }
        } else {
            return artists
        }
    }

    private func sortArtistsByName(_ artists: [Artist]) -> [Artist] {
        artists.sorted { first, second in
            normalize(string: first.name) < normalize(string: second.name)
        }
    }

    @ViewBuilder
    private func artistDetailDestination(for artist: Artist) -> some View {
        if #available(iOS 18.0, macOS 15.0, *) {
            ArtistDetailView(artist: artist, highlightedEventId: nil)
                .navigationTransition(
                    .zoom(sourceID: artist.id, in: artistImageTransition)
                )
        } else {
            ArtistDetailView(artist: artist, highlightedEventId: nil)
        }
    }

    @ViewBuilder
    private func artistOverview(_ artists: [Artist]) -> some View {
        let sortedArtists = sortArtistsByName(artists)

        if settings.artistViewType == 1 {
            ScrollView {
                LazyVGrid(columns: gridColumns, spacing: 0) {
                    ForEach(sortedArtists) { artist in
                        NavigationLink(
                            destination: artistDetailDestination(for: artist)
                        ) {
                            ArtistGridCell(
                                artist: artist,
                                imageTransitionNamespace: artistImageTransition
                            )
                        }
                        .buttonStyle(.plain)
                        .task(id: artist.id) {
                            await ArtistImageColorCache.shared.prepareBackgroundColor(for: artist)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 12)
            }
        } else {
            List {
                ForEach(sortedArtists) { artist in
                    NavigationLink(
                        destination: ArtistDetailView(
                            artist: artist,
                            highlightedEventId: nil
                        )
                    ) {
                        ArtistCell(artist: artist)
                    }.listRowInsets(
                        .init(top: 0, leading: 0, bottom: 0, trailing: 16)
                    )
                    .task(id: artist.id) {
                        await ArtistImageColorCache.shared.prepareBackgroundColor(for: artist)
                    }
                }
            }.listStyle(.plain)
        }
    }

    var body: some View {
        NavigationStack {

            LoadingListView(
                noDataMessage: "artists.none-found",
                noDataSubtitle: nil,
                dataMapper: { data in
                    generateArtistsToShow(
                        artists: getFilteredArtists(data: data)
                    ).withApplied(searchTerm: searchText) { artist in
                        artist.name
                    }
                }
            ) { artists in
                artistOverview(artists)
            }
            .searchable(text: $searchText)
            .disableAutocorrection(true)
            .navigationBarTitle(
                favoriteArtistsOnly ? "rated_artists.title" : "artists.title"
            )
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        favoriteArtistsOnly.toggle()
                    }) {
                        if favoriteArtistsOnly {
                            Text("artists.all.button")
                        } else {
                            Text("artists.favorites.button")
                        }
                    }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        settings.toggleArtistViewType()
                    } label: {
                        if settings.artistViewType == 1 {
                            Label("list.title", systemImage: "list.bullet")
                        } else {
                            Label("grid.title", systemImage: "square.grid.3x3")
                        }
                    }
                    .labelStyle(.iconOnly)

                    Menu {
                        ForEach(ShownArtistTypes.allCases, id: \.self) { artistType in
                            Toggle(isOn: binding(for: artistType)) {
                                Text(artistType.localizedName)
                            }
                        }

                        if !allArtistTypesSelected {
                            Divider()

                            Button("artisttypes.all") {
                                showAllArtistTypes()
                            }
                        }
                    } label: {
                        filterButtonLabel
                    }
                    .accessibilityLabel(Text("filter.button"))
                }
            }
        }
    }
}


enum ShownArtistTypes: CaseIterable, Hashable {
    case stage, street, dance, other

    init(artistType: ArtistType) {
        switch artistType {
        case .stage:
            self = .stage
        case .street:
            self = .street
        case .dance:
            self = .dance
        case .other:
            self = .other
        }
    }

    var localizedName: String {
        switch self {
        case .stage:
            return ArtistType.stage.localizedName
        case .street:
            return ArtistType.street.localizedName
        case .dance:
            return ArtistType.dance.localizedName
        case .other:
            return ArtistType.other.localizedName
        }
    }
}

struct ArtistImageDominantColor {
    let red: Double
    let green: Double
    let blue: Double

    var backgroundColor: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: 1.0)
    }

    var preferredColorScheme: ColorScheme {
        relativeLuminance > 0.45 ? .light : .dark
    }

    private var relativeLuminance: Double {
        0.2126 * linearized(red)
            + 0.7152 * linearized(green)
            + 0.0722 * linearized(blue)
    }

    private func linearized(_ value: Double) -> Double {
        value <= 0.03928
            ? value / 12.92
            : pow((value + 0.055) / 1.055, 2.4)
    }
}

private struct ArtistImageColorBucket {
    var redTotal: Int = 0
    var greenTotal: Int = 0
    var blueTotal: Int = 0
    var count: Int = 0

    mutating func add(red: UInt8, green: UInt8, blue: UInt8) {
        redTotal += Int(red)
        greenTotal += Int(green)
        blueTotal += Int(blue)
        count += 1
    }

    var dominantColor: ArtistImageDominantColor {
        ArtistImageDominantColor(
            red: Double(redTotal) / Double(count) / 255,
            green: Double(greenTotal) / Double(count) / 255,
            blue: Double(blueTotal) / Double(count) / 255
        )
    }

    var score: Double {
        let red = Double(redTotal) / Double(count) / 255
        let green = Double(greenTotal) / Double(count) / 255
        let blue = Double(blueTotal) / Double(count) / 255
        let brightness = max(red, green, blue)
        let saturation = brightness == 0
            ? 0
            : (brightness - min(red, green, blue)) / brightness
        let brightnessWeight = 1 - abs(brightness - 0.55)

        return Double(count) * (0.6 + saturation) * brightnessWeight
    }
}

final class ArtistImageColorCache {
    static let shared = ArtistImageColorCache()

    private static let colorContext = CIContext()
    private static let dominantColorSampleSize = 48
    private static let bucketSize = 32

    private let lock = NSLock()
    private var colorsByArtistId: [Int: ArtistImageDominantColor] = [:]

    private init() {}

    func cachedBackgroundColor(for artistId: Int) -> Color? {
        cachedDominantColor(for: artistId)?.backgroundColor
    }

    func cachedPreferredColorScheme(for artistId: Int) -> ColorScheme? {
        cachedDominantColor(for: artistId)?.preferredColorScheme
    }

    private func cachedDominantColor(for artistId: Int) -> ArtistImageDominantColor? {
        lock.lock()
        defer { lock.unlock() }
        return colorsByArtistId[artistId]
    }

    private func store(_ color: ArtistImageDominantColor, for artistId: Int) {
        lock.lock()
        defer { lock.unlock() }
        colorsByArtistId[artistId] = color
    }

    func prepareBackgroundColor(for artist: Artist) async {
        _ = await backgroundColor(for: artist)
    }

    func backgroundColor(for artist: Artist) async -> Color? {
        if let cachedColor = cachedBackgroundColor(for: artist.id) {
            return cachedColor
        }

        guard let imageUrl = artist.thumbImageUrl ?? artist.fullImageUrl else {
            return nil
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: imageUrl)
            guard let dominantColor = Self.dominantColor(from: data) else {
                return nil
            }

            store(dominantColor, for: artist.id)

            return dominantColor.backgroundColor
        } catch {
            return nil
        }
    }

    private static func dominantColor(from imageData: Data) -> ArtistImageDominantColor? {
        guard let image = CIImage(data: imageData) else {
            return nil
        }

        let scaledImage = scaledImageForDominantColorSampling(image)
        let width = max(1, Int(scaledImage.extent.width.rounded(.up)))
        let height = max(1, Int(scaledImage.extent.height.rounded(.up)))
        let rowBytes = width * 4
        var bitmap = [UInt8](repeating: 0, count: rowBytes * height)

        colorContext.render(
            scaledImage,
            toBitmap: &bitmap,
            rowBytes: rowBytes,
            bounds: scaledImage.extent,
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        return dominantColor(from: bitmap, width: width, height: height)
    }

    private static func scaledImageForDominantColorSampling(_ image: CIImage) -> CIImage {
        let maxDimension = max(image.extent.width, image.extent.height)
        guard maxDimension > 0 else {
            return image
        }

        let scale = CGFloat(dominantColorSampleSize) / maxDimension
        return image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
    }

    private static func dominantColor(
        from bitmap: [UInt8],
        width: Int,
        height: Int
    ) -> ArtistImageDominantColor? {
        var preferredBuckets: [Int: ArtistImageColorBucket] = [:]
        var fallbackBuckets: [Int: ArtistImageColorBucket] = [:]

        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                let red = bitmap[offset]
                let green = bitmap[offset + 1]
                let blue = bitmap[offset + 2]
                let alpha = bitmap[offset + 3]

                guard alpha > 200 else {
                    continue
                }

                addPixel(red: red, green: green, blue: blue, to: &fallbackBuckets)

                if isGoodDominantColorCandidate(red: red, green: green, blue: blue) {
                    addPixel(red: red, green: green, blue: blue, to: &preferredBuckets)
                }
            }
        }

        let buckets = preferredBuckets.isEmpty ? fallbackBuckets : preferredBuckets
        return buckets.values.max { first, second in
            first.score < second.score
        }?.dominantColor
    }

    private static func addPixel(
        red: UInt8,
        green: UInt8,
        blue: UInt8,
        to buckets: inout [Int: ArtistImageColorBucket]
    ) {
        let key = bucketKey(red: red, green: green, blue: blue)
        var bucket = buckets[key] ?? ArtistImageColorBucket()
        bucket.add(red: red, green: green, blue: blue)
        buckets[key] = bucket
    }

    private static func bucketKey(red: UInt8, green: UInt8, blue: UInt8) -> Int {
        let redBucket = Int(red) / bucketSize
        let greenBucket = Int(green) / bucketSize
        let blueBucket = Int(blue) / bucketSize
        return redBucket << 16 | greenBucket << 8 | blueBucket
    }

    private static func isGoodDominantColorCandidate(
        red: UInt8,
        green: UInt8,
        blue: UInt8
    ) -> Bool {
        let red = Double(red) / 255
        let green = Double(green) / 255
        let blue = Double(blue) / 255
        let brightness = max(red, green, blue)
        let saturation = brightness == 0
            ? 0
            : (brightness - min(red, green, blue)) / brightness

        return saturation < 0.8
    }
}

struct ArtistListView_Previews: PreviewProvider {
    static var previews: some View {
        ArtistListView()
            .environmentObject(DataStore())
    }
}
