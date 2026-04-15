//
//  ArtistListView.swift
//  RudolstadtForiOS
//
//  Created by Leon on 22.02.20.
//  Copyright © 2020 Leon Georgi. All rights reserved.
//

import CoreImage
import Foundation
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
    private func artistOverview(_ artists: [Artist]) -> some View {
        let sortedArtists = sortArtistsByName(artists)

        if settings.artistViewType == 1 {
            ScrollView {
                LazyVGrid(columns: gridColumns, spacing: 0) {
                    ForEach(sortedArtists) { artist in
                        NavigationLink(
                            value: AppNavigationRoute.artist(
                                id: artist.id,
                                highlightedEventId: nil
                            )
                        ) {
                            ArtistGridCell(
                                artist: artist,
                                imageTransitionNamespace: artistImageTransition
                            )
                        }
                        .buttonStyle(.plain)
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
                        value: AppNavigationRoute.artist(
                            id: artist.id,
                            highlightedEventId: nil
                        )
                    ) {
                        ArtistCell(artist: artist)
                    }.listRowInsets(
                        .init(top: 0, leading: 0, bottom: 0, trailing: 16)
                    )
                }
            }.listStyle(.plain)
        }
    }

    var body: some View {
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

struct ArtistImageDominantColor: Codable {
    let red: Double
    let green: Double
    let blue: Double

    var backgroundColor: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: 1.0)
    }

    func descriptionBackgroundColor(for colorScheme: ColorScheme) -> Color {
        adjustedDescriptionColor(for: colorScheme).backgroundColor
    }

    func adjustedToMeetReadability(for colorScheme: ColorScheme) -> ArtistImageDominantColor {
        switch colorScheme {
        case .light:
            if relativeLuminance >= 0.22 {
                return self
            }

            var adjustedColor = self
            for _ in 0..<10 where adjustedColor.relativeLuminance < 0.22 {
                adjustedColor = adjustedColor.adjusted(by: 0.05)
            }
            return adjustedColor
        case .dark:
            if relativeLuminance <= 0.18 {
                return self
            }

            var adjustedColor = self
            for _ in 0..<10 where adjustedColor.relativeLuminance > 0.18 {
                adjustedColor = adjustedColor.adjusted(by: -0.05)
            }
            return adjustedColor
        @unknown default:
            return self
        }
    }

    private func adjustedDescriptionColor(for colorScheme: ColorScheme) -> ArtistImageDominantColor {
        let adjustedColor: ArtistImageDominantColor
        if relativeLuminance > 0.92 {
            adjustedColor = adjusted(by: -0.08)
        } else if relativeLuminance < 0.04 {
            adjustedColor = adjusted(by: 0.08)
        } else if colorScheme == .dark {
            adjustedColor = adjusted(by: -0.10)
        } else {
            adjustedColor = adjusted(by: 0.10)
        }

        return adjustedColor
    }

    var relativeLuminance: Double {
        0.2126 * linearized(red)
            + 0.7152 * linearized(green)
            + 0.0722 * linearized(blue)
    }

    private func adjusted(by amount: Double) -> ArtistImageDominantColor {
        ArtistImageDominantColor(
            red: clamped(red + amount),
            green: clamped(green + amount),
            blue: clamped(blue + amount)
        )
    }

    private func clamped(_ value: Double) -> Double {
        min(1.0, max(0.0, value))
    }

    private func linearized(_ value: Double) -> Double {
        value <= 0.03928
            ? value / 12.92
            : pow((value + 0.055) / 1.055, 2.4)
    }
}

struct ArtistImageThemeColors: Codable {
    let light: ArtistImageDominantColor
    let dark: ArtistImageDominantColor

    func backgroundColor(for colorScheme: ColorScheme) -> Color {
        switch colorScheme {
        case .light:
            return light.backgroundColor
        case .dark:
            return dark.backgroundColor
        @unknown default:
            return light.backgroundColor
        }
    }

    func descriptionBackgroundColor(for colorScheme: ColorScheme) -> Color {
        switch colorScheme {
        case .light:
            return light.descriptionBackgroundColor(for: .light)
        case .dark:
            return dark.descriptionBackgroundColor(for: .dark)
        @unknown default:
            return light.descriptionBackgroundColor(for: .light)
        }
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
    private static let persistedColorsKey = "artist.image.theme.colors.v2"

    private let lock = NSLock()
    private var colorsByArtistId: [Int: ArtistImageThemeColors] = [:]
    private var inFlightColorTasksByArtistId: [Int: Task<ArtistImageThemeColors?, Never>] = [:]

    private init() {
        restorePersistedColors()
    }

    func cachedBackgroundColor(for artistId: Int, colorScheme: ColorScheme) -> Color? {
        cachedThemeColors(for: artistId)?.backgroundColor(for: colorScheme)
    }

    func cachedDescriptionBackgroundColor(for artistId: Int, colorScheme: ColorScheme) -> Color? {
        cachedThemeColors(for: artistId)?.descriptionBackgroundColor(for: colorScheme)
    }

    func cachedThemeColors(for artistId: Int) -> ArtistImageThemeColors? {
        lock.lock()
        defer { lock.unlock() }
        return colorsByArtistId[artistId]
    }

    private func store(_ color: ArtistImageThemeColors, for artistId: Int) {
        lock.lock()
        defer { lock.unlock() }
        colorsByArtistId[artistId] = color
        persistLockedColors()
    }

    private func restorePersistedColors() {
        guard
            let data = UserDefaults.standard.data(forKey: Self.persistedColorsKey),
            let decodedColors = try? JSONDecoder().decode([Int: ArtistImageThemeColors].self, from: data)
        else {
            return
        }

        lock.lock()
        colorsByArtistId = decodedColors
        lock.unlock()
    }

    private func persistLockedColors() {
        guard let encoded = try? JSONEncoder().encode(colorsByArtistId) else {
            return
        }
        UserDefaults.standard.set(encoded, forKey: Self.persistedColorsKey)
    }

    func clearCache() {
        lock.lock()
        defer { lock.unlock() }

        inFlightColorTasksByArtistId.values.forEach { $0.cancel() }
        inFlightColorTasksByArtistId.removeAll()
        colorsByArtistId.removeAll()
        UserDefaults.standard.removeObject(forKey: Self.persistedColorsKey)
    }

    private func inFlightTask(for artistId: Int) -> Task<ArtistImageThemeColors?, Never>? {
        lock.lock()
        defer { lock.unlock() }
        return inFlightColorTasksByArtistId[artistId]
    }

    private func setInFlightTask(
        _ task: Task<ArtistImageThemeColors?, Never>?,
        for artistId: Int
    ) {
        lock.lock()
        defer { lock.unlock() }
        inFlightColorTasksByArtistId[artistId] = task
    }

    func prepareBackgroundColor(for artist: Artist) async {
        _ = await themeColors(for: artist)
    }

    func themeColors(for artist: Artist) async -> ArtistImageThemeColors? {
        if let cachedThemeColors = cachedThemeColors(for: artist.id) {
            return cachedThemeColors
        }

        guard let imageUrl = artist.thumbImageUrl ?? artist.fullImageUrl else {
            return nil
        }

        if let inFlightTask = inFlightTask(for: artist.id) {
            if let inFlightThemeColors = await inFlightTask.value {
                store(inFlightThemeColors, for: artist.id)
                return inFlightThemeColors
            }
            return nil
        }

        let task = Task.detached(priority: .utility) { () -> ArtistImageThemeColors? in
            do {
                let (data, _) = try await URLSession.shared.data(from: imageUrl)
                return Self.themeColors(from: data)
            } catch {
                return nil
            }
        }

        setInFlightTask(task, for: artist.id)
        let themeColors = await task.value
        setInFlightTask(nil, for: artist.id)

        guard let themeColors else {
            return nil
        }

        store(themeColors, for: artist.id)
        return themeColors
    }

    private static func themeColors(from imageData: Data) -> ArtistImageThemeColors? {
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

        return themeColors(from: bitmap, width: width, height: height)
    }

    private static func scaledImageForDominantColorSampling(_ image: CIImage) -> CIImage {
        let maxDimension = max(image.extent.width, image.extent.height)
        guard maxDimension > 0 else {
            return image
        }

        let scale = CGFloat(dominantColorSampleSize) / maxDimension
        return image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
    }

    private static func themeColors(
        from bitmap: [UInt8],
        width: Int,
        height: Int
    ) -> ArtistImageThemeColors? {
        var lightPreferredBuckets: [Int: ArtistImageColorBucket] = [:]
        var darkPreferredBuckets: [Int: ArtistImageColorBucket] = [:]
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
                    if isReadableWithDarkText(red: red, green: green, blue: blue) {
                        addPixel(red: red, green: green, blue: blue, to: &lightPreferredBuckets)
                    }
                    if isReadableWithLightText(red: red, green: green, blue: blue) {
                        addPixel(red: red, green: green, blue: blue, to: &darkPreferredBuckets)
                    }
                }
            }
        }

        guard let fallbackColor = dominantColor(from: fallbackBuckets) else {
            return nil
        }

        let lightColor = (dominantColor(from: lightPreferredBuckets) ?? fallbackColor)
            .adjustedToMeetReadability(for: .light)
        let darkColor = (dominantColor(from: darkPreferredBuckets) ?? fallbackColor)
            .adjustedToMeetReadability(for: .dark)

        return ArtistImageThemeColors(light: lightColor, dark: darkColor)
    }

    private static func dominantColor(from buckets: [Int: ArtistImageColorBucket]) -> ArtistImageDominantColor? {
        buckets.values.max { first, second in
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

    private static func isReadableWithDarkText(red: UInt8, green: UInt8, blue: UInt8) -> Bool {
        relativeLuminance(red: red, green: green, blue: blue) >= 0.25
    }

    private static func isReadableWithLightText(red: UInt8, green: UInt8, blue: UInt8) -> Bool {
        relativeLuminance(red: red, green: green, blue: blue) <= 0.15
    }

    private static func relativeLuminance(red: UInt8, green: UInt8, blue: UInt8) -> Double {
        let redLinear = linearized(Double(red) / 255)
        let greenLinear = linearized(Double(green) / 255)
        let blueLinear = linearized(Double(blue) / 255)
        return 0.2126 * redLinear + 0.7152 * greenLinear + 0.0722 * blueLinear
    }

    private static func linearized(_ value: Double) -> Double {
        value <= 0.03928
            ? value / 12.92
            : pow((value + 0.055) / 1.055, 2.4)
    }
}

struct ArtistListView_Previews: PreviewProvider {
    static var previews: some View {
        ArtistListView()
            .environmentObject(DataStore())
    }
}
