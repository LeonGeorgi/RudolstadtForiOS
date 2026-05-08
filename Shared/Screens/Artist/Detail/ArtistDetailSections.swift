import SwiftUI

struct ArtistAISummaryBlock: View {
    let artist: Artist

    @EnvironmentObject var settings: UserSettings

    private var headlineGradient: LinearGradient {
        let warm = OKHSLColorConverter.okhslToSRGB(.init(h: 0.02, s: 0.82, l: 0.71))
        let pink = OKHSLColorConverter.okhslToSRGB(.init(h: 0.89, s: 0.79, l: 0.68))
        let blue = OKHSLColorConverter.okhslToSRGB(.init(h: 0.67, s: 0.83, l: 0.69))
        let cyan = OKHSLColorConverter.okhslToSRGB(.init(h: 0.56, s: 0.79, l: 0.72))
        return LinearGradient(
            colors: [
                Color(red: warm.r, green: warm.g, blue: warm.b),
                Color(red: pink.r, green: pink.g, blue: pink.b),
                Color(red: blue.r, green: blue.g, blue: blue.b),
                Color(red: cyan.r, green: cyan.g, blue: cyan.b),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        if settings.aiSummaryEnabled, let ai = artist.ai, ai.hasContent {
            let localizedSummary = ai.localizedSummary?.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

            ArtistDetailContentBlock {
                Text("artist.ai.header")
                    .font(.headline)
                    .foregroundStyle(headlineGradient)

                if let localizedSummary, !localizedSummary.isEmpty {
                    Text(localizedSummary)
                        .font(.body)
                }

                Text("artist.ai.footer")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 1)
        }
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
    let currentTipID: String?
    let navigate: ((AppNavigationRoute) -> Void)?

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
                    AppInlineTipView(
                        tip: DiscoverabilityTips.eventQuickActions,
                        currentTipID: currentTipID,
                        arrowEdge: .bottom
                    )
                    .padding(.bottom, 10)

                    VStack(spacing: 0) {
                        ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                            NavigationLink(
                                value: AppNavigationRoute.stage(
                                    id: event.stage.id,
                                    highlightedEventId: event.id
                                )
                            ) {
                                ArtistEventCell(event: event)
                                    .environment(\.artistNavigationHandler, navigate)
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
            .padding(.top, 6)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(backgroundColor)
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
        VStack(alignment: .leading, spacing: 8) {
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
