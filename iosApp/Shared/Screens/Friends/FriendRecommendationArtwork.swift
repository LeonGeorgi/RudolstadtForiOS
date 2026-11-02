#if os(iOS)
import SwiftUI
import UIKit

/// Horizontal color profiles of the displayed square crop's bottom edge.
/// The lower profile mixes neighboring colors more strongly as they extend down the card.
struct FriendRecommendationArtworkColors {
    let upper: [SIMD3<Double>]
    let lower: [SIMD3<Double>]

    init?(image: UIImage) {
        let size = 256
        guard image.size.width > 0, image.size.height > 0 else { return nil }
        var source = image
        if let cgImage = image.cgImage {
            let side = min(cgImage.width, cgImage.height)
            let crop = CGRect(x: (cgImage.width - side) / 2, y: (cgImage.height - side) / 2,
                              width: side, height: side)
            guard let cropped = cgImage.cropping(to: crop) else { return nil }
            // A centered square crop is invariant under camera rotation and mirroring.
            // Crop before resampling so colors outside the visible image cannot bleed in.
            source = UIImage(cgImage: cropped, scale: image.scale, orientation: image.imageOrientation)
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let square = UIGraphicsImageRenderer(
            size: CGSize(width: size, height: size), format: format
        ).image { renderer in
            UIColor.black.setFill()
            renderer.fill(CGRect(x: 0, y: 0, width: size, height: size))
            let scale = CGFloat(size) / min(source.size.width, source.size.height)
            let width = source.size.width * scale
            let height = source.size.height * scale
            source.draw(in: CGRect(
                x: (CGFloat(size) - width) / 2, y: (CGFloat(size) - height) / 2,
                width: width, height: height
            ))
        }
        guard let cgImage = square.cgImage,
              let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        var pixels = [UInt8](repeating: 0, count: size * size * 4)
        let drewImage = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: size, height: size,
                bitsPerComponent: 8, bytesPerRow: size * 4, space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                    | CGBitmapInfo.byteOrder32Big.rawValue
            ) else { return false }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: size, height: size))
            return true
        }
        guard drewImage else { return nil }

        // Ratios calibrated against the Apple Music reference, applied to each photo.
        let center = Double(size) * 1.01
        let sigma = Double(size) * 0.005
        let weights = (0..<size).map { y in
            exp(-0.5 * pow((Double(y) - center) / sigma, 2))
        }
        let totalWeight = weights.reduce(0, +)
        let edge = (0..<size).map { x -> SIMD3<Double> in
            var color = SIMD3<Double>.zero
            for y in (size - 12)..<size {
                let offset = (y * size + x) * 4
                color += SIMD3(
                    Double(pixels[offset]), Double(pixels[offset + 1]),
                    Double(pixels[offset + 2])
                ) * weights[y]
            }
            return color / (totalWeight * 255)
        }
        upper = Self.smoothedStops(edge, sigma: Double(size) * 16 / 600)
        lower = Self.smoothedStops(edge, sigma: Double(size) * 60 / 600)
    }

    private static func smoothedStops(
        _ edge: [SIMD3<Double>], sigma: Double
    ) -> [SIMD3<Double>] {
        let radius = Int(ceil(sigma * 3))
        let weights = (-radius...radius).map { exp(-0.5 * pow(Double($0) / sigma, 2)) }
        let totalWeight = weights.reduce(0, +)
        return (0...40).map { stop in
            let x = Int((Double(stop) / 40 * Double(edge.count - 1)).rounded())
            var color = SIMD3<Double>.zero
            for offset in -radius...radius {
                let sample = min(max(x + offset, 0), edge.count - 1)
                color += edge[sample] * weights[offset + radius]
            }
            return color / totalWeight
        }
    }
}

struct FriendRecommendationArtwork: View {
    let artist: Artist
    @State private var colors: FriendRecommendationArtworkColors?

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            ZStack(alignment: .top) {
                surface
                    .frame(height: max(0, height - width * 0.9) * 16 / 13)
                    .offset(y: width * 0.9)

                ArtistImageView(artist: artist, fullImage: true, onImageLoaded: { image in
                    colors = FriendRecommendationArtworkColors(image: image)
                })
                .frame(width: width, height: width)
                .clipped()
                .mask {
                    LinearGradient(stops: [
                        .init(color: .black, location: 0),
                        .init(color: .black, location: 0.9),
                        .init(color: .clear, location: 1)
                    ], startPoint: .top, endPoint: .bottom)
                }

                LinearGradient(stops: Self.readabilityStops,
                               startPoint: .top, endPoint: .bottom)
                .frame(height: max(0, height - width * 5 / 6))
                .offset(y: width * 5 / 6)
            }
            .frame(width: width, height: height, alignment: .top)
            .clipped()
        }
        .accessibilityHidden(true)
    }

    private static let readabilityStops: [Gradient.Stop] = [
        0, 6, 13, 19, 25, 23, 26, 29, 32, 36, 39, 42, 45, 49, 52, 55,
        57, 60, 62, 64, 66, 68, 70, 72, 73, 74, 75, 75, 75, 75, 75
    ].enumerated().map { index, alpha in
        .init(color: .black.opacity(Double(alpha) / 255), location: Double(index) / 30)
    }

    @ViewBuilder
    private var surface: some View {
        if let colors {
            horizontalGradient(colors.lower)
                .overlay {
                    horizontalGradient(colors.upper)
                        .mask {
                            LinearGradient(colors: [.black, .clear],
                                           startPoint: .top, endPoint: .bottom)
                        }
                }
        } else {
            Color(white: 0.4)
        }
    }

    private func horizontalGradient(_ colors: [SIMD3<Double>]) -> LinearGradient {
        LinearGradient(colors: colors.map { Color(red: $0.x, green: $0.y, blue: $0.z) },
                       startPoint: .leading, endPoint: .trailing)
    }
}
#endif
