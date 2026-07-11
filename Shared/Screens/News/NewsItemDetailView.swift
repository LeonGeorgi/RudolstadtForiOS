//
// Created by Leon on 27.02.20.
// Copyright (c) 2020 Leon Georgi. All rights reserved.
//

import Foundation
import NukeUI
import SwiftUI

struct NewsItemDetailView: View {
    let newsItem: NewsItem
    var navigate: ((AppNavigationRoute) -> Void)? = nil

    @Environment(\.festivalData) private var festivalData
    @EnvironmentObject var settings: UserSettings

    @State private var mentionedArtists: [Artist] = []
    @State private var mentionedStages: [Stage] = []

    private var normalizedNewsText: String {
        normalizeForNewsMentionMatch(
            [
                newsItem.formattedShortDescription,
                newsItem.formattedLongDescription,
                newsItem.formattedContent,
            ].joined(separator: "\n")
        )
    }

    private var mentionTaskKey: String {
        "\(newsItem.id)-\(festivalData.artists.count)-\(festivalData.stages.count)"
    }

    private var displayedLongDescription: String {
        collapseExcessiveBlankLines(newsItem.formattedLongDescription)
    }

    private var displayedContent: String {
        collapseExcessiveBlankLines(newsItem.formattedContent)
    }

    private var inlineLinkedArtistsInLongDescription: [Artist] {
        firstLinkedArtists(
            in: displayedLongDescription,
            artists: mentionedArtists
        )
    }

    private var inlineLinkedArtistsInContent: [Artist] {
        firstLinkedArtists(
            in: displayedContent,
            artists: mentionedArtists,
            excludingArtistIDs: Set(
                inlineLinkedArtistsInLongDescription.map(\.id)
            )
        )
    }

    private var youtubePreviews: [YouTubePreview] {
        var seen = Set<String>()

        return detectedURLs(
            in: [
                newsItem.formattedShortDescription,
                displayedLongDescription,
                displayedContent,
            ]
        )
        .compactMap { url in
            guard
                let videoID = extractYouTubeVideoID(from: url),
                let thumbnailURL = youtubeThumbnailURL(for: videoID),
                seen.insert(videoID).inserted
            else {
                return nil
            }

            return YouTubePreview(
                videoID: videoID,
                videoURL: url,
                thumbnailURL: thumbnailURL
            )
        }
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

                if !displayedLongDescription.isEmpty {
                    NewsTextView(
                        text: displayedLongDescription,
                        linkedArtists: inlineLinkedArtistsInLongDescription,
                        onArtistTap: handleInlineArtistTap
                    )
                        .font(.title3)
                        .bold()
                        .padding(.bottom, 5)
                }

                if !displayedContent.isEmpty {
                    NewsTextView(
                        text: displayedContent,
                        linkedArtists: inlineLinkedArtistsInContent,
                        onArtistTap: handleInlineArtistTap
                    )
                }

                if !youtubePreviews.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(youtubePreviews) { preview in
                            YouTubePreviewCard(preview: preview)
                        }
                    }
                    .padding(.top, 12)
                }

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
        .accessibilityIdentifier("news-detail-\(newsItem.id)")
        .navigationTitle(newsItem.formattedShortDescription)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("")
                    .accessibilityHidden(true)
            }
        }
        .onAppear {
            settings.markNewsAsRead(newsItem)
        }
        .task(id: mentionTaskKey) {
            await loadMentionsAsync()
        }
    }

    private func handleInlineArtistTap(_ artist: Artist) {
        navigate?(
            .artist(
                id: artist.id,
                highlightedEventId: nil,
                transitionSourceID: nil
            )
        )
    }

    private func loadMentionsAsync() async {
        let normalizedText = normalizedNewsText

        let result = MentionLookupResult(
            artists: festivalData.artists.compactMap { artist -> (Artist, Int)? in
                guard
                    let index = firstWholeMentionAppearanceIndex(
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
            },
            stages: festivalData.stages.filter { stage in
                containsMention(
                    normalizedText: normalizedText,
                    candidate: stage.localizedName
                )
            }
        )

        if Task.isCancelled {
            return
        }

        await MainActor.run {
            mentionedArtists = result.artists
            mentionedStages = result.stages
        }
    }

    @ViewBuilder
    private func artistPreviewLink(for artist: Artist) -> some View {
        NavigationLink(
            value: AppNavigationRoute.artist(
                id: artist.id,
                highlightedEventId: nil,
                transitionSourceID: nil
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
        firstWholeMentionAppearanceIndex(in: normalizedText, candidate: candidate) != nil
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

func firstWholeMentionAppearanceIndex(in normalizedText: String, candidate: String) -> Int? {
    let normalizedCandidate = normalizeForNewsMentionMatch(candidate)
    guard !normalizedCandidate.isEmpty else {
        return nil
    }

    var searchRange = normalizedText.startIndex..<normalizedText.endIndex
    while let range = normalizedText.range(
        of: normalizedCandidate,
        options: [],
        range: searchRange
    ) {
        let characterBeforeMatch = range.lowerBound == normalizedText.startIndex
            ? nil
            : normalizedText[normalizedText.index(before: range.lowerBound)]
        let characterAfterMatch = range.upperBound == normalizedText.endIndex
            ? nil
            : normalizedText[range.upperBound]

        if isNewsMentionBoundary(characterBeforeMatch)
            && isNewsMentionBoundary(characterAfterMatch)
        {
            return normalizedText.distance(
                from: normalizedText.startIndex,
                to: range.lowerBound
            )
        }

        searchRange = range.upperBound..<normalizedText.endIndex
    }

    return nil
}

func normalizeForNewsMentionMatch(_ text: String) -> String {
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

private func isNewsMentionBoundary(_ character: Character?) -> Bool {
    character == nil || character == " "
}

private struct NewsTextView: View {
    let text: String
    let linkedArtists: [Artist]
    let onArtistTap: (Artist) -> Void

    var body: some View {
        Text(
            attributedStringWithDetectedLinksAndArtistMentions(
                text,
                artists: linkedArtists
            )
        )
            .frame(maxWidth: .infinity, alignment: .leading)
            .tint(.accentColor)
            .environment(
                \.openURL,
                OpenURLAction { url in
                    guard
                        let artist = linkedArtists.first(where: { artist in
                            inlineArtistLinkURL(for: artist) == url
                        })
                    else {
                        return .systemAction(url)
                    }

                    onArtistTap(artist)
                    return .handled
                }
            )
    }
}

func attributedStringWithDetectedLinksAndArtistMentions(
    _ text: String,
    artists: [Artist]
) -> AttributedString {
    let mutableString = NSMutableAttributedString(string: text)
    var occupiedRanges = detectedLinkRanges(in: text)

    for occupiedRange in occupiedRanges {
        if let url = URL(string: String(text[occupiedRange])) {
            mutableString.addAttribute(
                .link,
                value: url,
                range: NSRange(occupiedRange, in: text)
            )
        }
    }

    let artistsBySpecificity = artists.sorted { lhs, rhs in
        lhs.formattedName.count > rhs.formattedName.count
    }

    for artist in artistsBySpecificity {
        guard let range = artistMentionRanges(
            in: text,
            candidate: artist.formattedName
        ).first(where: { range in
            !occupiedRanges.contains(where: { $0.overlaps(range) })
        }) else {
            continue
        }

        mutableString.addAttribute(
            .link,
            value: inlineArtistLinkURL(for: artist),
            range: NSRange(range, in: text)
        )
        occupiedRanges.append(range)
    }

    return (try? AttributedString(mutableString, including: \.foundation))
        ?? AttributedString(text)
}

func firstLinkedArtists(
    in text: String,
    artists: [Artist],
    excludingArtistIDs: Set<Int> = []
) -> [Artist] {
    artists.filter { artist in
        !excludingArtistIDs.contains(artist.id)
            && !artistMentionRanges(in: text, candidate: artist.formattedName)
                .isEmpty
    }
}

func artistMentionRanges(in text: String, candidate: String) -> [Range<String.Index>] {
    let trimmedCandidate = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedCandidate.isEmpty else {
        return []
    }

    var ranges: [Range<String.Index>] = []
    var searchStart = text.startIndex

    while searchStart < text.endIndex,
        let range = text.range(
            of: trimmedCandidate,
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            range: searchStart..<text.endIndex,
            locale: Locale.current
        )
    {
        let characterBeforeMatch = range.lowerBound == text.startIndex
            ? nil
            : text[text.index(before: range.lowerBound)]
        let characterAfterMatch = range.upperBound == text.endIndex
            ? nil
            : text[range.upperBound]

        if isArtistMentionBoundary(characterBeforeMatch)
            && isArtistMentionBoundary(characterAfterMatch)
        {
            ranges.append(range)
        }

        searchStart = range.upperBound
    }

    return ranges
}

func inlineArtistLinkURL(for artist: Artist) -> URL {
    URL(string: "rudolstadt://artist/\(artist.id)")!
}

private func detectedLinkRanges(in text: String) -> [Range<String.Index>] {
    let detector = try? NSDataDetector(
        types: NSTextCheckingResult.CheckingType.link.rawValue
    )
    let range = NSRange(text.startIndex..<text.endIndex, in: text)

    return detector?.matches(in: text, options: [], range: range).compactMap {
        match in
        Range(match.range, in: text)
    } ?? []
}

private func isArtistMentionBoundary(_ character: Character?) -> Bool {
    guard let character else {
        return true
    }

    return character.unicodeScalars.allSatisfy { scalar in
        !CharacterSet.alphanumerics.contains(scalar)
    }
}

private struct YouTubePreview: Identifiable {
    let videoID: String
    let videoURL: URL
    let thumbnailURL: URL

    var id: String {
        videoID
    }

    var hostLabel: String {
        let host = videoURL.host?
            .replacingOccurrences(of: "www.", with: "")
            .replacingOccurrences(of: "m.", with: "")
        return host?.isEmpty == false ? host! : "youtube.com"
    }
}

private struct YouTubePreviewCard: View {
    let preview: YouTubePreview

    private let cardShape = RoundedRectangle(cornerRadius: 22, style: .continuous)

    var body: some View {
        Link(destination: preview.videoURL) {
            ZStack(alignment: .bottomLeading) {
                ZStack {
                    cardShape
                        .fill(Color.secondary.opacity(0.12))

                    LazyImage(url: preview.thumbnailURL) { state in
                        if let image = state.image {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            LinearGradient(
                                colors: [
                                    Color(red: 0.17, green: 0.08, blue: 0.10),
                                    Color(red: 0.46, green: 0.09, blue: 0.12),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .overlay {
                                ProgressView()
                                    .tint(.white)
                            }
                        }
                    }

                    LinearGradient(
                        colors: [
                            .black.opacity(0.02),
                            .clear,
                            .black.opacity(0.68),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    VStack {
                        HStack {
                            youtubeBadge
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding(14)

                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial.opacity(0.92))
                                .frame(width: 58, height: 58)

                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.96, green: 0.18, blue: 0.16),
                                            Color(red: 0.78, green: 0.05, blue: 0.09),
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 46, height: 46)

                            Image(systemName: "play.fill")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(.white)
                                .offset(x: 1)
                        }
                        .shadow(color: .black.opacity(0.22), radius: 12, y: 5)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Watch on YouTube")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.white)

                            Text(preview.hostLabel)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.82))
                        }

                        Spacer()

                        Image(systemName: "arrow.up.right")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .padding(16)
                    .background(
                        LinearGradient(
                            colors: [
                                .clear,
                                .black.opacity(0.10),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(maxHeight: .infinity, alignment: .bottom)
                }
                .clipShape(cardShape)
            }
            .aspectRatio(16 / 9, contentMode: .fit)
            .overlay {
                cardShape
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            }
            .overlay {
                cardShape
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.18), radius: 16, y: 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open YouTube video")
    }

    private var youtubeBadge: some View {
        HStack(spacing: 8) {
            Image("youtube")
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)

            Text("YouTube")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.34))
        )
        .overlay {
            Capsule(style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        }
    }
}

struct NewsItemDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NewsItemDetailView(newsItem: .example)
            .environmentObject(UserSettings())
            .environmentObject(DataStore())
    }
}
