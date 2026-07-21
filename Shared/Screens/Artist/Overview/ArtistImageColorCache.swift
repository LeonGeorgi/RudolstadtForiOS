import CoreImage
import Foundation
import SwiftUI

struct ArtistImageDominantColor: Codable {
    // App-specific target above WCAG AAA to stay legible in bright
    // environments and leave more headroom for reduced-emphasis text.
    static let minimumContrastRatio = 10.0
    static let blackTextLuminance = 0.0
    static let whiteTextLuminance = 1.0

    let red: Double
    let green: Double
    let blue: Double

    var backgroundColor: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: 1.0)
    }

    func adjustedToMeetReadability(for colorScheme: ColorScheme) -> ArtistImageDominantColor {
        switch colorScheme {
        case .light:
            if contrastRatio(with: Self.blackTextLuminance) >= Self.minimumContrastRatio {
                return self
            }

            var adjustedColor = self
            for _ in 0..<10 where adjustedColor.contrastRatio(with: Self.blackTextLuminance) < Self.minimumContrastRatio {
                adjustedColor = adjustedColor.adjusted(by: 0.05)
            }
            return adjustedColor
        case .dark:
            if contrastRatio(with: Self.whiteTextLuminance) >= Self.minimumContrastRatio {
                return self
            }

            var adjustedColor = self
            for _ in 0..<10 where adjustedColor.contrastRatio(with: Self.whiteTextLuminance) < Self.minimumContrastRatio {
                adjustedColor = adjustedColor.adjusted(by: -0.05)
            }
            return adjustedColor
        @unknown default:
            return self
        }
    }

    var relativeLuminance: Double {
        0.2126 * linearized(red)
            + 0.7152 * linearized(green)
            + 0.0722 * linearized(blue)
    }

    func contrastRatio(with otherLuminance: Double) -> Double {
        let lighter = max(relativeLuminance, otherLuminance)
        let darker = min(relativeLuminance, otherLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    private func adjusted(by amount: Double) -> ArtistImageDominantColor {
        let okhsl = OKHSLColorConverter.srgbToOKHSL(.init(r: red, g: green, b: blue))
        let adjustedOKHSL = OKHSLColorConverter.OKHSL(
            h: okhsl.h,
            s: okhsl.s,
            l: clamped(okhsl.l + amount)
        )
        let rgb = OKHSLColorConverter.okhslToSRGB(adjustedOKHSL)

        return ArtistImageDominantColor(
            red: clamped(rgb.r),
            green: clamped(rgb.g),
            blue: clamped(rgb.b)
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

    func artistDetailTheme(for colorScheme: ColorScheme) -> ArtistDetailTheme {
        let dominantColor = colorScheme == .dark ? dark : light
        let isDark = colorScheme == .dark
        let contentSurface = dominantColor.surfaceColor(
            saturationMultiplier: 0.78,
            lightnessDelta: isDark ? 0.07 : -0.055
        )

        return ArtistDetailTheme(
            pageBackground: dominantColor.backgroundColor,
            actionSurface: dominantColor.surfaceColor(
                saturationMultiplier: 0.72,
                lightnessDelta: isDark ? 0.09 : -0.08
            ),
            contentSurface: contentSurface,
            separator: dominantColor.surfaceColor(
                saturationMultiplier: 0.65,
                lightnessDelta: isDark ? 0.14 : -0.13
            ).opacity(isDark ? 0.55 : 0.4),
            imageBorder: dominantColor.surfaceColor(
                saturationMultiplier: 0.7,
                lightnessDelta: isDark ? 0.2 : -0.2
            ).opacity(0.65)
        )
    }
}

private extension ArtistImageDominantColor {
    func surfaceColor(
        saturationMultiplier: Double = 1,
        lightnessDelta: Double
    ) -> Color {
        let okhsl = OKHSLColorConverter.srgbToOKHSL(.init(r: red, g: green, b: blue))
        let adjusted = OKHSLColorConverter.OKHSL(
            h: okhsl.h,
            s: min(1, max(0, okhsl.s * saturationMultiplier)),
            l: min(1, max(0, okhsl.l + lightnessDelta))
        )
        let rgb = OKHSLColorConverter.okhslToSRGB(adjusted)
        return Color(
            .sRGB,
            red: min(1, max(0, rgb.r)),
            green: min(1, max(0, rgb.g)),
            blue: min(1, max(0, rgb.b)),
            opacity: 1
        )
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
    private static let persistedColorsKey = "artist.image.theme.colors.v5"

    private let lock = NSLock()
    private var colorsByArtistId: [Int: ArtistImageThemeColors] = [:]
    private var inFlightColorTasksByArtistId: [Int: Task<ArtistImageThemeColors?, Never>] = [:]

    private init() {
        restorePersistedColors()
    }

    func cachedBackgroundColor(for artistId: Int, colorScheme: ColorScheme) -> Color? {
        cachedThemeColors(for: artistId)?.backgroundColor(for: colorScheme)
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

                if isReadableWithDarkText(red: red, green: green, blue: blue) {
                    addPixel(red: red, green: green, blue: blue, to: &lightPreferredBuckets)
                }
                if isReadableWithLightText(red: red, green: green, blue: blue) {
                    addPixel(red: red, green: green, blue: blue, to: &darkPreferredBuckets)
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

    private static func isReadableWithDarkText(red: UInt8, green: UInt8, blue: UInt8) -> Bool {
        contrastRatio(
            backgroundLuminance: relativeLuminance(red: red, green: green, blue: blue),
            textLuminance: ArtistImageDominantColor.blackTextLuminance
        ) >= ArtistImageDominantColor.minimumContrastRatio
    }

    private static func isReadableWithLightText(red: UInt8, green: UInt8, blue: UInt8) -> Bool {
        contrastRatio(
            backgroundLuminance: relativeLuminance(red: red, green: green, blue: blue),
            textLuminance: ArtistImageDominantColor.whiteTextLuminance
        ) >= ArtistImageDominantColor.minimumContrastRatio
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

    private static func contrastRatio(backgroundLuminance: Double, textLuminance: Double) -> Double {
        let lighter = max(backgroundLuminance, textLuminance)
        let darker = min(backgroundLuminance, textLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }
}
