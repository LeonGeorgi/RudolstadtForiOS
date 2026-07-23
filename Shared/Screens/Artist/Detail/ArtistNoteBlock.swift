import SwiftUI
import CoreFoundation

struct ArtistNoteBlock: View {
    let note: String?
    let onEdit: () -> Void

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
                ArtistNotePaperBackground(foldSize: foldSize)
            }
            .rotationEffect(.degrees(2.2))
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
        ArtistNotePaper(foldSize: foldSize)
            .fill(paperColor)
            .overlay {
                paperTexture
                    .clipShape(ArtistNotePaper(foldSize: foldSize))
            }
            .overlay(alignment: .bottomTrailing) {
                ArtistNotePaperFold()
                    .fill(foldColor)
                    .frame(width: foldSize, height: foldSize)
                    .overlay {
                        paperTexture
                            .clipShape(ArtistNotePaperFold())
                    }
            }
            .shadow(
                color: .black.opacity(colorScheme == .dark ? 0.20 : 0.09),
                radius: 3,
                y: 2
            )
    }

    private var paperTexture: some View {
        Image(decorative: "artist-note-paper-texture")
            .resizable(resizingMode: .tile)
            .blendMode(.multiply)
            .opacity(colorScheme == .dark ? 0.30 : 0.52)
    }

    private var paperColor: Color {
        if colorScheme == .dark {
            Color(red: 0.31, green: 0.28, blue: 0.16)
        } else {
            Color(red: 1.00, green: 0.96, blue: 0.72)
        }
    }

    private var foldColor: Color {
        if colorScheme == .dark {
            Color(red: 0.18, green: 0.16, blue: 0.08)
        } else {
            Color(red: 0.84, green: 0.74, blue: 0.34)
        }
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
