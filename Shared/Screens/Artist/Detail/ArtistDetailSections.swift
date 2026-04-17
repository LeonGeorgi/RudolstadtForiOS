import SwiftUI

struct ArtistDetailSplitBackground: View {
    let artistBackgroundColor: Color
    let descriptionBackgroundColor: Color
    let descriptionBackgroundStartY: CGFloat

    var body: some View {
        GeometryReader { proxy in
            if descriptionBackgroundStartY < proxy.size.height {
                let splitY = max(descriptionBackgroundStartY, 0)

                VStack(spacing: 0) {
                    artistBackgroundColor
                        .frame(height: splitY)
                    descriptionBackgroundColor
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .ignoresSafeArea()
            } else {
                artistBackgroundColor
                    .ignoresSafeArea()
            }
        }
    }
}

struct ArtistAISummaryBlock: View {
    let artist: Artist
    let onInfoTap: () -> Void

    @EnvironmentObject var settings: UserSettings

    var body: some View {
        if settings.aiSummaryEnabled, let ai = artist.ai, ai.hasContent {
            let localizedSummary = ai.localizedSummary?.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

            VStack(alignment: .leading, spacing: 10) {
                if let localizedSummary, !localizedSummary.isEmpty {
                    HStack(alignment: .top, spacing: 10) {
                        Button(action: onInfoTap) {
                            ArtistAIGradientIcon()
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(localizedSummary)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

            }
        }
    }
}

private struct ArtistAIGradientIcon: View {
    var body: some View {
        Image(systemName: "sparkles.2")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        Color(red: 1.0, green: 0.48, blue: 0.19),
                        Color(red: 0.98, green: 0.23, blue: 0.60),
                        Color(red: 0.39, green: 0.36, blue: 1.0),
                        Color(red: 0.0, green: 0.72, blue: 1.0),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }
}

struct ArtistNoteBlock: View {
    let note: String?
    let onEdit: () -> Void

    var body: some View {
        if let note, !note.isEmpty {
            ArtistDetailContentBlock {
                ArtistDetailSectionHeader("artist.notes.headline")

                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(note)
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Button(action: onEdit) {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
        }
    }
}

struct ArtistEventsBlock: View {
    let artistEvents: LoadingEntity<[Event]>
    let highlightedEventId: Int?

    @Environment(\.colorScheme) private var colorScheme

    private var eventDividerColor: Color {
        colorScheme == .dark ? .white.opacity(0.22) : .black.opacity(0.12)
    }

    private var highlightedEventBackgroundColor: Color {
        colorScheme == .dark ? .white.opacity(0.10) : .black.opacity(0.08)
    }

    var body: some View {
        switch artistEvents {
        case .loading:
            Text("events.loading")
                .font(.body)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
        case .failure(let reason):
            Text("Failed to load: " + reason.rawValue)
                .font(.body)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
        case .success(let events):
            if !events.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                            NavigationLink(
                                value: AppNavigationRoute.stage(
                                    id: event.stage.id,
                                    highlightedEventId: event.id
                                )
                            ) {
                                ArtistEventCell(event: event)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 16)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(
                                        highlightedEventId == event.id && events.count > 1
                                            ? highlightedEventBackgroundColor
                                            : Color.clear
                                    )
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            if index < events.count - 1 {
                                Divider()
                                    .overlay(eventDividerColor)
                                    .padding(.leading, 16 + 52 + 10)
                            }
                        }
                    }
                }
                .padding(.horizontal, -16)
            }
        }
    }
}

struct ArtistDescriptionBlock: View {
    let description: String?
    let backgroundColor: Color

    var body: some View {
        if let description, !description.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(description)
                    .font(.body)
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                backgroundColor
                    .overlay {
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: DescriptionBackgroundStartPreferenceKey.self,
                                value: proxy.frame(in: .global).minY
                            )
                        }
                    }
            )
        }
    }
}

struct ArtistBrowseGenresBlock: View {
    let artist: Artist

    @EnvironmentObject var dataStore: DataStore

    private var localizedBrowseGenres: [String] {
        let browseGenreIDs = artist.ai?.browseGenreIDs ?? []
        var seen = Set<String>()
        return browseGenreIDs.compactMap { genreID in
            let label = dataStore.localizedBrowseGenreLabel(for: genreID)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !label.isEmpty else {
                return nil
            }
            if seen.contains(label) {
                return nil
            }
            seen.insert(label)
            return label
        }
    }

    var body: some View {
        if !localizedBrowseGenres.isEmpty {
            Text(localizedBrowseGenres.joined(separator: " • "))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 26)
        }
    }
}

struct DescriptionBackgroundStartPreferenceKey: SwiftUI.PreferenceKey {
    static let defaultValue = CGFloat.infinity

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct ArtistDetailSectionHeader: View {
    let title: LocalizedStringKey

    init(_ title: LocalizedStringKey) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
    }
}

private struct ArtistDetailContentBlock<Content: View>: View {
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(0.16), lineWidth: 0.5)
        )
    }
}
