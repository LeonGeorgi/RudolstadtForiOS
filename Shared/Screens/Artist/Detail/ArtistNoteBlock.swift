import SwiftUI
import CoreFoundation

struct ArtistNotePreviewGeometry: Equatable {
    let frame: CGRect
    let unrotatedSize: CGSize
}

private struct ArtistNotePreviewHiddenKey: EnvironmentKey {
    static let defaultValue = false
}

private struct ArtistNotePreviewFrameHandlerKey: EnvironmentKey {
    static let defaultValue: (ArtistNotePreviewGeometry) -> Void = { _ in }
}

extension EnvironmentValues {
    var isArtistNotePreviewHidden: Bool {
        get { self[ArtistNotePreviewHiddenKey.self] }
        set { self[ArtistNotePreviewHiddenKey.self] = newValue }
    }

    var artistNotePreviewFrameHandler: (ArtistNotePreviewGeometry) -> Void {
        get { self[ArtistNotePreviewFrameHandlerKey.self] }
        set { self[ArtistNotePreviewFrameHandlerKey.self] = newValue }
    }
}

struct ArtistNoteBlock: View {
    let note: String?
    var showsPaper = true
    let onEdit: () -> Void

    @Environment(\.artistNotePreviewFrameHandler)
    private var previewFrameHandler
    @Environment(\.isArtistNotePreviewHidden)
    private var isPreviewHidden
    @Environment(\.locale) private var locale

    private var noteText: String {
        note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var displayText: String {
        noteText.addingSoftHyphens(for: locale)
    }

    private var isEmpty: Bool {
        noteText.isEmpty
    }

    private var noteWidth: CGFloat {
        isEmpty ? 58 : 150
    }

    private var noteHeight: CGFloat? {
        isEmpty ? 42 : nil
    }

    private var foldSize: CGFloat {
        isEmpty ? 10 : 17
    }

    private var accessibilityLabel: Text {
        if isEmpty {
            Text("artist.add-note.button")
        } else {
            Text(noteText)
        }
    }

    var body: some View {
        Button(action: onEdit) {
            Group {
                if isEmpty {
                    Image(systemName: "pencil.and.scribble")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.62))
                } else {
                    Text(displayText)
                        .font(
                            .custom(
                                "Noteworthy-Light",
                                size: 14,
                                relativeTo: .caption
                            )
                        )
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(5)
                        .padding(.leading, 10)
                        .padding(.trailing, 12)
                        .padding(.vertical, 7)
                }
            }
            .opacity(isPreviewHidden ? 0 : 1)
            .frame(
                width: noteWidth,
                height: noteHeight,
                alignment: isEmpty ? .center : .topLeading
            )
            .frame(
                minHeight: isEmpty ? nil : 52,
                alignment: .topLeading
            )
            .background {
                if !isPreviewHidden, showsPaper {
                    ArtistNotePaperBackground(foldSize: foldSize)
                }
            }
            .rotationEffect(.degrees(2.2))
            .onGeometryChange(for: ArtistNotePreviewGeometry.self) { proxy in
                ArtistNotePreviewGeometry(
                    frame: proxy.frame(in: .global),
                    unrotatedSize: proxy.size
                )
            } action: { geometry in
                previewFrameHandler(geometry)
            }
            .padding(.vertical, 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(Text("artist.edit-note.button"))
    }
}

private extension String {
    func addingSoftHyphens(for locale: Locale) -> String {
        let hyphenationLocale = locale as CFLocale
        guard CFStringIsHyphenationAvailableForLocale(hyphenationLocale) else {
            return self
        }

        let source = self as CFString
        var hyphenationLocations: [Int] = []

        enumerateSubstrings(
            in: startIndex..<endIndex,
            options: .byWords
        ) { _, wordRange, _, _ in
            let utf16WordRange = NSRange(wordRange, in: self)
            var searchLocation = NSMaxRange(utf16WordRange)

            while searchLocation > utf16WordRange.location {
                var hyphenCharacter: UTF32Char = 0
                let hyphenationLocation =
                    CFStringGetHyphenationLocationBeforeIndex(
                        source,
                        searchLocation,
                        CFRange(
                            location: utf16WordRange.location,
                            length: utf16WordRange.length
                        ),
                        0,
                        hyphenationLocale,
                        &hyphenCharacter
                    )

                guard
                    hyphenationLocation != kCFNotFound,
                    hyphenationLocation < searchLocation
                else {
                    break
                }

                hyphenationLocations.append(hyphenationLocation)
                searchLocation = hyphenationLocation
            }
        }

        let result = NSMutableString(string: self)
        for location in hyphenationLocations.sorted(by: >) {
            result.insert("\u{00AD}", at: location)
        }
        return result as String
    }
}

struct ArtistNotePaperBackground: View {
    let foldSize: CGFloat

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Canvas(opaque: false, rendersAsynchronously: false) { context, size in
            ArtistNotePaperDrawing.draw(
                in: &context,
                bounds: CGRect(origin: .zero, size: size),
                foldSize: foldSize,
                colorScheme: colorScheme
            )
        }
        .shadow(
            color: .black.opacity(
                ArtistNotePaperDrawing.shadowOpacity(for: colorScheme)
            ),
            radius: 3,
            y: 2
        )
    }
}

struct ArtistNoteGrowingPaper: View, Animatable {
    var progress: CGFloat
    let start: CGPoint
    let end: CGPoint
    let sourceSize: CGSize
    let destinationSize: CGSize
    let sourceFoldSize: CGFloat
    let safeAreaTop: CGFloat

    @Environment(\.colorScheme) private var colorScheme

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        Canvas(opaque: false, rendersAsynchronously: false) { context, _ in
            let size = CGSize(
                width: ArtistNoteMotionGeometry.interpolate(
                    from: sourceSize.width,
                    to: destinationSize.width,
                    progress: progress
                ),
                height: ArtistNoteMotionGeometry.interpolate(
                    from: sourceSize.height,
                    to: destinationSize.height,
                    progress: progress
                )
            )
            let curveCenter = ArtistNoteMotionGeometry.point(
                progress: progress,
                start: start,
                end: end,
                minimumY: safeAreaTop + sourceSize.height / 2
            )
            let center = CGPoint(
                x: curveCenter.x,
                y: max(curveCenter.y, safeAreaTop + size.height / 2)
            )
            let foldSize = ArtistNoteMotionGeometry.interpolate(
                from: sourceFoldSize,
                to: 34,
                progress: progress
            )
            let rotation = ArtistNoteMotionGeometry.interpolate(
                from: ArtistNoteMotionGeometry.previewRotation,
                to: 0,
                progress: progress
            )

            context.translateBy(x: center.x, y: center.y)
            context.rotate(by: .degrees(rotation))
            ArtistNotePaperDrawing.draw(
                in: &context,
                bounds: CGRect(
                    x: -size.width / 2,
                    y: -size.height / 2,
                    width: size.width,
                    height: size.height
                ),
                foldSize: foldSize,
                colorScheme: colorScheme
            )
        }
        .shadow(
            color: .black.opacity(
                ArtistNotePaperDrawing.shadowOpacity(for: colorScheme)
            ),
            radius: 3,
            y: 2
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

enum ArtistNoteMotionGeometry {
    static let previewRotation = 2.2
    private static let previewTextScale: CGFloat = 20 / 14

    static func scaledPreviewTextScale(for progress: CGFloat) -> CGFloat {
        interpolate(
            from: 1,
            to: previewTextScale,
            progress: progress
        )
    }

    static func textReflowProgress(for progress: CGFloat) -> CGFloat {
        let crossfadeProgress = clamped((progress - 0.68) / 0.22)
        return crossfadeProgress
            * crossfadeProgress
            * (3 - 2 * crossfadeProgress)
    }

    static func point(
        progress: CGFloat,
        start: CGPoint,
        end: CGPoint,
        minimumY: CGFloat
    ) -> CGPoint {
        let deltaX = end.x - start.x
        let deltaY = end.y - start.y
        let distance = max(hypot(deltaX, deltaY), 1)
        let curveAmount = min(distance * 0.34, 180)
        let control = CGPoint(
            x: (start.x + end.x) / 2
                - deltaY / distance * curveAmount,
            y: max(
                (start.y + end.y) / 2
                    + deltaX / distance * curveAmount,
                minimumY
            )
        )
        let progress = min(max(progress, 0), 1)
        let inverseProgress = 1 - progress

        return CGPoint(
            x: inverseProgress * inverseProgress * start.x
                + 2 * inverseProgress * progress * control.x
                + progress * progress * end.x,
            y: inverseProgress * inverseProgress * start.y
                + 2 * inverseProgress * progress * control.y
                + progress * progress * end.y
        )
    }

    static func interpolate(
        from start: CGFloat,
        to end: CGFloat,
        progress: CGFloat
    ) -> CGFloat {
        start + (end - start) * clamped(progress)
    }

    private static func clamped(_ progress: CGFloat) -> CGFloat {
        min(max(progress, 0), 1)
    }
}

private enum ArtistNotePaperDrawing {
    static func draw(
        in context: inout GraphicsContext,
        bounds: CGRect,
        foldSize: CGFloat,
        colorScheme: ColorScheme
    ) {
        drawPaper(
            in: &context,
            bounds: bounds,
            foldSize: foldSize,
            colorScheme: colorScheme
        )
    }

    static func shadowOpacity(for colorScheme: ColorScheme) -> Double {
        colorScheme == .dark ? 0.20 : 0.09
    }

    private static func drawPaper(
        in context: inout GraphicsContext,
        bounds: CGRect,
        foldSize: CGFloat,
        colorScheme: ColorScheme
    ) {
        let effectiveFoldSize = max(
            0,
            min(foldSize, bounds.width, bounds.height)
        )
        let paperPath = ArtistNotePaper(foldSize: effectiveFoldSize)
            .path(in: bounds)
        let foldBounds = CGRect(
            x: bounds.maxX - effectiveFoldSize,
            y: bounds.maxY - effectiveFoldSize,
            width: effectiveFoldSize,
            height: effectiveFoldSize
        )
        let foldPath = ArtistNotePaperFold().path(in: foldBounds)

        context.fill(
            paperPath,
            with: .color(paperColor(for: colorScheme))
        )
        context.fill(
            foldPath,
            with: .color(foldColor(for: colorScheme))
        )

        context.drawLayer { textureContext in
            textureContext.blendMode = .multiply
            textureContext.opacity = textureOpacity(for: colorScheme)
            let texture = GraphicsContext.Shading.tiledImage(
                Image(decorative: "artist-note-paper-texture"),
                origin: bounds.origin
            )
            textureContext.fill(paperPath, with: texture)
            textureContext.fill(foldPath, with: texture)
        }
    }

    private static func paperColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.31, green: 0.28, blue: 0.16)
            : Color(red: 1.00, green: 0.96, blue: 0.72)
    }

    private static func foldColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.18, green: 0.16, blue: 0.08)
            : Color(red: 0.84, green: 0.74, blue: 0.34)
    }

    private static func textureOpacity(
        for colorScheme: ColorScheme
    ) -> Double {
        colorScheme == .dark ? 0.30 : 0.52
    }
}

private struct ArtistNotePaper: Shape {
    let foldSize: CGFloat

    func path(in rect: CGRect) -> Path {
        let foldTop = CGPoint(
            x: rect.maxX,
            y: rect.maxY - foldSize
        )
        let foldBottom = CGPoint(
            x: rect.maxX - foldSize,
            y: rect.maxY
        )

        return Path { path in
            path.move(to: rect.origin)
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: foldTop)
            path.addLine(to: foldBottom)
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

private struct ArtistNotePaperFold: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: rect.origin)
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

#if DEBUG
struct ArtistNoteBlock_Previews: PreviewProvider {
    static var previews: some View {
        ArtistNoteBlock(
            note: "Try the early set first, then leave enough time to cross to the next stage.",
            onEdit: {}
        )
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
