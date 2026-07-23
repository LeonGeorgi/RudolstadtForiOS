import SwiftUI

private let artistNoteFoldSize: CGFloat = 26

struct ArtistNoteBlock: View {
    let note: String
    let onEdit: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: onEdit) {
            Text(note)
                .font(.custom("Noteworthy-Light", size: 19, relativeTo: .body))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    ArtistNotePaper()
                        .fill(paperColor)
                        .overlay {
                            paperTexture
                                .clipShape(ArtistNotePaper())
                        }
                        .overlay(alignment: .bottomTrailing) {
                            ArtistNotePaperFold()
                                .fill(foldColor)
                                .frame(
                                    width: artistNoteFoldSize,
                                    height: artistNoteFoldSize
                                )
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
                .rotationEffect(.degrees(-0.3))
                .padding(.horizontal, 4)
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("artist.edit-note.button"))
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
    func path(in rect: CGRect) -> Path {
        let foldTop = CGPoint(
            x: rect.maxX,
            y: rect.maxY - artistNoteFoldSize
        )
        let foldBottom = CGPoint(
            x: rect.maxX - artistNoteFoldSize,
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
