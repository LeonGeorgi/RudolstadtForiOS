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

    @EnvironmentObject var settings: UserSettings

    var body: some View {
        if settings.aiSummaryEnabled && artist.ai?.hasContent == true {
            ArtistDetailContentBlock {
                Text("artist.ai.header")
                    .font(.headline)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.red, .purple, .blue, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                if let ai = artist.ai {
                    if let localizedGenres = ai.localizedGenres,
                        !localizedGenres.isEmpty
                    {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(localizedGenres, id: \.self) { genre in
                                    Text(genre)
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(
                                            Capsule()
                                                .fill(Color.accentColor.opacity(0.18))
                                        )
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                    }

                    if let localizedSummary = ai.localizedSummary,
                        !localizedSummary.isEmpty
                    {
                        Text(localizedSummary)
                            .font(.body)
                    }
                }

                Text("artist.ai.footer")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
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

    @Environment(\.colorScheme) private var colorScheme

    private var eventDividerColor: Color {
        colorScheme == .dark ? .white.opacity(0.22) : .black.opacity(0.12)
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
                                    .padding(.horizontal, 0)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(
                                        highlightedEventId == event.id && events.count > 1
                                            ? Color.yellow.opacity(0.24)
                                            : Color.clear
                                    )
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            if index < events.count - 1 {
                                Divider()
                                    .overlay(eventDividerColor)
                                    .padding(.leading, 90)
                            }
                        }
                    }
                }
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
