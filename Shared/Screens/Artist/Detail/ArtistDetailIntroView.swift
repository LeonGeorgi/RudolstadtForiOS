import SwiftUI

struct ArtistDetailIntroView: View {
    let artist: Artist
    let note: String?
    let currentTipID: String?
    let topPadding: CGFloat
    let onEditNote: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    @EnvironmentObject private var settings: UserSettings

    private var localizedSummary: String? {
        guard settings.aiSummaryEnabled else {
            return nil
        }

        guard
            let summary = artist.ai?
                .localizedSummary(locale: locale)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
            !summary.isEmpty
        else {
            return nil
        }

        return summary
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    introText

                    noteBlock
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            } else {
                HStack(alignment: .top, spacing: 12) {
                    introText
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .layoutPriority(1)

                    noteBlock
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, topPadding)
    }

    @ViewBuilder
    private var introText: some View {
        if let localizedSummary {
            Text(localizedSummary)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var noteBlock: some View {
        ArtistNoteBlock(note: note, onEdit: onEditNote)
            .appPopoverTip(
                DiscoverabilityTips.artistNotes,
                currentTipID: currentTipID,
                arrowEdge: .top
            )
    }

}

#if DEBUG
struct ArtistDetailIntroView_Previews: PreviewProvider {
    @MainActor
    static var previews: some View {
        ArtistDetailIntroView(
            artist: PreviewMockData.featuredArtist,
            note: "Don't miss the early set.",
            currentTipID: nil,
            topPadding: 20,
            onEditNote: {}
        )
            .padding()
            .previewMockEnvironment(suiteName: "ArtistDetailIntroViewPreview")
            .previewLayout(.sizeThatFits)
    }
}
#endif
