//
// Created by Leon on 27.02.20.
// Copyright (c) 2020 Leon Georgi. All rights reserved.
//

import Foundation
import SwiftUI

struct NewsItemDetailView: View {
    let newsItem: NewsItem

    @EnvironmentObject var settings: UserSettings
    @EnvironmentObject var dataStore: DataStore

    @State private var mentionedArtists: [Artist] = []
    @State private var mentionedStages: [Stage] = []

    private var normalizedNewsText: String {
        normalizeForPlainMatch(
            [
                newsItem.formattedShortDescription,
                newsItem.formattedLongDescription,
                newsItem.formattedContent,
            ].joined(separator: "\n")
        )
    }

    private var mentionTaskKey: String {
        switch dataStore.data {
        case .loading:
            return "\(newsItem.id)-loading"
        case .failure(let reason):
            return "\(newsItem.id)-failure-\(reason.rawValue)"
        case .success(let entities):
            return "\(newsItem.id)-success-\(entities.artists.count)-\(entities.stages.count)"
        }
    }

    private var displayedLongDescription: String {
        collapseExcessiveBlankLines(newsItem.formattedLongDescription)
    }

    private var displayedContent: String {
        collapseExcessiveBlankLines(newsItem.formattedContent)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                Text(newsItem.formattedShortDescription)
                    .font(.title)
                    .bold()
                Text("\(newsItem.dateAsString) \(newsItem.timeAsString)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 5)

                Divider()

                Text(displayedLongDescription)
                    .font(.title3)
                    .bold()
                    .padding(.bottom, 5)

                Text(displayedContent)

                if !mentionedArtists.isEmpty || !mentionedStages.isEmpty {
                    Divider()
                        .padding(.vertical, 8)

                    if !mentionedArtists.isEmpty {
                        Text("news.featured_artists")
                            .font(.headline)
                            .padding(.bottom, 4)

                        ForEach(mentionedArtists) { artist in
                            artistPreviewLink(for: artist)
                                .padding(.bottom, 4)
                        }
                    }

                    if !mentionedStages.isEmpty {
                        Text("Stages")
                            .font(.headline)
                            .padding(.top, mentionedArtists.isEmpty ? 0 : 8)
                            .padding(.bottom, 2)

                        ForEach(mentionedStages) { stage in
                            NavigationLink(
                                value: AppNavigationRoute.stage(
                                    id: stage.id,
                                    highlightedEventId: nil
                                )
                            ) {
                                Text(stage.localizedName)
                            }
                            .padding(.bottom, 2)
                        }
                    }
                }
            }.padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            settings.markNewsAsRead(newsItem)
        }
        .task(id: mentionTaskKey) {
            await loadMentionsAsync()
        }
    }

    private func loadMentionsAsync() async {
        print("NewsMentionDebug: start lookup for news \(newsItem.id) - \(newsItem.formattedShortDescription)")

        guard case .success(let entities) = dataStore.data else {
            print("NewsMentionDebug: data not ready for news \(newsItem.id), skipping lookup")
            await MainActor.run {
                mentionedArtists = []
                mentionedStages = []
            }
            return
        }

        let normalizedText = normalizedNewsText
        print(
            "NewsMentionDebug: data ready for news \(newsItem.id), artists=\(entities.artists.count), stages=\(entities.stages.count), textLength=\(normalizedText.count)"
        )

        let result = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let artists = entities.artists.compactMap { artist -> (Artist, Int)? in
                    guard
                        let index = firstAppearanceIndex(
                            in: normalizedText,
                            candidate: artist.formattedName
                        )
                    else {
                        return nil
                    }
                    return (artist, index)
                }
                .sorted { lhs, rhs in
                    lhs.1 < rhs.1
                }
                .map { pair in
                    pair.0
                }

                let stages = entities.stages.filter { stage in
                    containsMention(
                        normalizedText: normalizedText,
                        candidate: stage.localizedName
                    )
                }
                continuation.resume(returning: MentionLookupResult(artists: artists, stages: stages))
            }
        }

        if Task.isCancelled {
            print("NewsMentionDebug: lookup cancelled for news \(newsItem.id)")
            return
        }

        let dotaCandidates = entities.artists.filter { artist in
            normalizeForPlainMatch(artist.formattedName).contains("dota")
        }
        for artist in dotaCandidates {
            let normalizedCandidate = normalizeForPlainMatch(artist.formattedName)
            print(
                "NewsMentionDebug: dota candidate='\(artist.formattedName)' normalized='\(normalizedCandidate)' matched=\(normalizedText.contains(normalizedCandidate))"
            )
        }

        print(
            "NewsMentionDebug: lookup done for news \(newsItem.id), matched artists=\(result.artists.count), matched stages=\(result.stages.count)"
        )

        await MainActor.run {
            mentionedArtists = result.artists
            mentionedStages = result.stages
            print(
                "NewsMentionDebug: applied to UI for news \(newsItem.id), artists=\(mentionedArtists.count), stages=\(mentionedStages.count)"
            )
        }
    }

    @ViewBuilder
    private func artistPreviewLink(for artist: Artist) -> some View {
        NavigationLink(
            value: AppNavigationRoute.artist(
                id: artist.id,
                highlightedEventId: nil
            )
        ) {
            HStack(alignment: .center, spacing: 14) {
                ArtistImageView(artist: artist, fullImage: true)
                    .frame(width: 96, height: 96)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 2)

                VStack(alignment: .leading, spacing: 7) {
                    Text(artist.formattedName)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)

                    if let countryAndFlags = artistCountryAndFlags(artist), !countryAndFlags.isEmpty {
                        Label {
                            Text(countryAndFlags)
                        } icon: {
                            Image(systemName: "globe.europe.africa")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .labelStyle(.titleAndIcon)
                        .lineLimit(1)
                    }

                    if let tagsText = artistTagsText(artist), !tagsText.isEmpty {
                        Label {
                            Text(tagsText)
                                .lineLimit(2)
                        } icon: {
                            Image(systemName: "sparkles.2")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .labelStyle(.titleAndIcon)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    private func artistCountryAndFlags(_ artist: Artist) -> String? {
        let country = artist.countries.trimmingCharacters(in: .whitespacesAndNewlines)
        let flags = artist.ai?.flags.joined(separator: "") ?? ""
        let value = [country, flags]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private func artistTagsText(_ artist: Artist) -> String? {
        let tags = (artist.ai?.localizedTags ?? [])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !tags.isEmpty else {
            return nil
        }
        return Array(tags.prefix(3)).joined(separator: " • ")
    }

    private func containsMention(normalizedText: String, candidate: String) -> Bool {
        firstAppearanceIndex(in: normalizedText, candidate: candidate) != nil
    }

    private func firstAppearanceIndex(in normalizedText: String, candidate: String) -> Int? {
        let normalizedCandidate = normalizeForPlainMatch(candidate)
        guard !normalizedCandidate.isEmpty else {
            return nil
        }
        guard let range = normalizedText.range(of: normalizedCandidate) else {
            return nil
        }
        return normalizedText.distance(
            from: normalizedText.startIndex,
            to: range.lowerBound
        )
    }

    private func normalizeForPlainMatch(_ text: String) -> String {
        normalize(string: text)
            .lowercased()
            .replacingOccurrences(
                of: "[^\\p{L}\\p{N}]+",
                with: " ",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: "\\s+",
                with: " ",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func collapseExcessiveBlankLines(_ text: String) -> String {
        text.replacingOccurrences(
            of: "(\\n\\s*){3,}",
            with: "\n\n",
            options: .regularExpression
        )
    }
}

private struct MentionLookupResult {
    let artists: [Artist]
    let stages: [Stage]
}

struct NewsItemDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NewsItemDetailView(newsItem: .example)
            .environmentObject(UserSettings())
            .environmentObject(DataStore())
    }
}
