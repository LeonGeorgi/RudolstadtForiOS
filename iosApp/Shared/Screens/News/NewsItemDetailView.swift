//
// Created by Leon on 27.02.20.
// Copyright (c) 2020 Leon Georgi. All rights reserved.
//

import Foundation
import Nuke
import RudolstadtCore
import SwiftUI

extension NewsLinkPreview: @unchecked @retroactive Sendable {}

private actor NewsPreviewDiskCache {
    static let shared = NewsPreviewDiskCache()
    private func file(for url: String) -> URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("news-link-previews", isDirectory: true)
            .appendingPathComponent(NewsLinkPreviews.shared.cacheKey(url: url) + ".json")
    }
    func read(_ url: String) -> NewsLinkPreview? {
        guard let file = file(for: url), let value = try? String(contentsOf: file, encoding: .utf8) else { return nil }
        return NewsLinkPreviews.shared.decode(value: value)
    }
    func write(_ preview: NewsLinkPreview) {
        guard let file = file(for: preview.url) else { return }
        do {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try NewsLinkPreviews.shared.encode(preview: preview).write(to: file, atomically: true, encoding: .utf8)
        } catch {
            // The system may evict or deny writes to this optional cache.
        }
    }
}
#if os(iOS)
import UIKit
typealias NewsFont = UIFont
typealias NewsColor = UIColor
#else
import AppKit
typealias NewsFont = NSFont
typealias NewsColor = NSColor
#endif

struct NewsItemDetailView: View {
    let newsItem: NewsItem
    var navigate: ((AppNavigationRoute) -> Void)? = nil

    @Environment(\.festivalData) private var festivalData
    @EnvironmentObject var settings: UserSettings

    @State private var mentionedArtists: [Artist] = []
    @State private var mentionedStages: [Stage] = []
    @State private var loadedYouTubeVideoID: String?

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

    private var inlineMentions: [ProgramInlineMention] {
        newsInlineMentions(
            texts: [displayedLongDescription, displayedContent],
            artists: mentionedArtists, stages: mentionedStages
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
                seen.insert(videoID).inserted
            else {
                return nil
            }

            return YouTubePreview(
                videoID: videoID,
                videoURL: url
            )
        }
    }

    var body: some View {
        let links = inlineMentions
        return ScrollView {
            VStack(alignment: .leading) {
                Text(newsItem.formattedShortDescription)
                    .font(.title)
                    .bold()
                Text("\(newsItem.dateAsString) \(newsItem.timeAsString)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 5)

                Divider()

                if !displayedLongDescription.isEmpty {
                    NewsTextView(
                        text: displayedLongDescription,
                        mentions: links.filter { $0.textIndex == 0 },
                        isSubtitle: true,
                        onInternalLink: handleInlineLink
                    )
                        .padding(.bottom, 5)
                }

                if !displayedContent.isEmpty {
                    NewsTextView(
                        text: displayedContent,
                        mentions: links.filter { $0.textIndex == 1 },
                        isSubtitle: false,
                        onInternalLink: handleInlineLink
                    )
                }

                if !youtubePreviews.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(youtubePreviews) { preview in
                            YouTubePreviewCard(
                                preview: preview,
                                isPlayerLoaded: loadedYouTubeVideoID == preview.id
                            ) {
                                loadedYouTubeVideoID = preview.id
                            }
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

    private func handleInlineLink(_ url: URL) -> Bool {
        if let artist = mentionedArtists.first(where: { inlineArtistLinkURL(for: $0) == url }) {
            navigate?(.artist(id: artist.id, highlightedEventId: nil, transitionSourceID: nil))
            return true
        }
        if let stage = mentionedStages.first(where: { inlineStageLinkURL(for: $0) == url }) {
            navigate?(.stage(id: stage.id, highlightedEventId: nil))
            return true
        }
        return false
    }

    private func loadMentionsAsync() async {
        let normalizedText = normalizedNewsText

        let result = ProgramMentions.shared.find(
            normalizedText: normalizedText,
            artists: festivalData.artists,
            places: festivalData.stages,
            normalizedArtistName: { normalizeForNewsMentionMatch($0.formattedName) },
            normalizedPlaceName: { normalizeForNewsMentionMatch($0.localizedName) }
        )

        if Task.isCancelled {
            return
        }

        await MainActor.run {
            mentionedArtists = result.artists
            mentionedStages = result.places
        }
    }

    @ViewBuilder
    private func artistPreviewLink(for artist: Artist) -> some View {
        let countryAndFlags = artistCountryAndFlags(artist)
        let tagsText = artistTagsText(artist)

        NavigationLink(
            value: AppNavigationRoute.artist(
                id: artist.id,
                highlightedEventId: nil,
                transitionSourceID: nil
            )
        ) {
            FestivalListRow(hasThirdLine: countryAndFlags != nil && tagsText != nil) {
                ArtistListRowImage(artist: artist)
            } content: {
                FestivalListRowTitle(artist.formattedName)

                if let countryAndFlags {
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

                if let tagsText {
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
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    private func artistCountryAndFlags(_ artist: Artist) -> String? {
        let country = artist.countries.trimmingCharacters(in: .whitespacesAndNewlines)
        let flags = artist.flagSymbols.joined(separator: "")
        let value = [country, flags]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private func artistTagsText(_ artist: Artist) -> String? {
        let tags = (artist.keywordLabels() ?? [])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !tags.isEmpty else {
            return nil
        }
        return Array(tags.prefix(3)).joined(separator: " • ")
    }

    private func collapseExcessiveBlankLines(_ text: String) -> String {
        text.replacingOccurrences(
            of: "(\\n\\s*){3,}",
            with: "\n\n",
            options: .regularExpression
        )
    }
}

func firstWholeMentionAppearanceIndex(in normalizedText: String, candidate: String) -> Int? {
    guard let offset = KotlinCore.bridge.firstMention(text: normalizedText, candidate: normalizeForNewsMentionMatch(candidate)) else { return nil }
    let index = String.Index(utf16Offset: Int(offset.intValue), in: normalizedText)
    return normalizedText.distance(from: normalizedText.startIndex, to: index)
    }

func normalizeForNewsMentionMatch(_ text: String) -> String {
    KotlinCore.bridge.normalizeMention(value: normalize(string: text))
    }

func newsInlineMentions(texts: [String], artists: [Artist], stages: [Stage]) -> [ProgramInlineMention] {
    let occupied = texts.map { text in
        detectedLinkRanges(in: text).map { range in
            let native = NSRange(range, in: text)
            return TextMentionRange(start: Int32(native.location), endExclusive: Int32(NSMaxRange(native)))
        }
    }
    return ProgramMentions.shared.inline(
        texts: texts, artists: artists, places: stages, occupiedRanges: occupied,
        fold: { $0.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current) },
        placeName: { $0.localizedName }
    )
}

private struct NewsTextView: View {
    let text: String
    let mentions: [ProgramInlineMention]
    let isSubtitle: Bool
    let onInternalLink: (URL) -> Bool

    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var images: [URL: PlatformImage] = [:]
    @State private var previews: [String: NewsLinkPreview] = [:]

    private var webURLs: [URL] {
        Array(Set(detectedNewsLinks(in: text).map(\.url).filter { NewsLinkPreviews.shared.requestURL(url: $0.absoluteString) != nil }))
            .sorted { $0.absoluteString < $1.absoluteString }
    }

    private var imageURLs: [URL] {
        Array(Set(mentions.compactMap { $0.artist?.thumbImageUrl ?? $0.artist?.fullImageUrl }
                  + previews.values.compactMap { $0.imageURL.flatMap(URL.init(string:)) }))
            .sorted { $0.absoluteString < $1.absoluteString }
    }

    var body: some View {
        NativeNewsText(
            text: text, mentions: mentions, images: images, isSubtitle: isSubtitle,
            colorScheme: colorScheme, dynamicTypeSize: dynamicTypeSize, previews: previews
        ) { url in
            if !onInternalLink(url) { openURL(url) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task(id: webURLs) {
            await withTaskGroup(of: (String, NewsLinkPreview?).self) { group in
                for url in webURLs {
                    group.addTask {
                        let cached = await NewsPreviewDiskCache.shared.read(url.absoluteString)
                        do {
                            let preview = try await awaitKotlinRequest { request in
                                try await sharedRemoteClient.linkPreview(url: url.absoluteString, cached: cached, request: request)
                            }
                            if let preview, !Task.isCancelled { await NewsPreviewDiskCache.shared.write(preview) }
                            return (url.absoluteString, preview)
                        } catch { return (url.absoluteString, cached) }
                    }
                }
                for await (url, preview) in group {
                    guard !Task.isCancelled else { return }
                    if let preview { previews[url] = preview }
                }
            }
        }
        #if !os(iOS)
        .task(id: imageURLs) {
            for url in imageURLs where images[url] == nil {
                do {
                    let image = try await ImagePipeline.shared.image(for: url)
                    guard !Task.isCancelled else { return }
                    images[url] = image
                } catch {
                    if Task.isCancelled { return }
                }
            }
        }
        #endif
    }
}

func inlineStageLinkURL(for stage: Stage) -> URL? {
    var components = URLComponents()
    components.scheme = "rudolstadt"
    components.host = "stage"
    components.path = "/" + stage.placeKey
    return components.url
}

func artistMentionRanges(in text: String, candidate: String) -> [Range<String.Index>] {
    TextMentions.shared.ranges(text: text, candidate: candidate) {
        $0.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
    }.compactMap { match in
        Range(NSRange(location: Int(match.start), length: Int(match.endExclusive - match.start)), in: text)
    }
}

func inlineArtistLinkURL(for artist: Artist) -> URL {
    URL(string: "rudolstadt://artist/\(artist.id)")!
}

private func detectedLinkRanges(in text: String) -> [Range<String.Index>] {
    detectedNewsLinks(in: text).compactMap { Range($0.range, in: text) }
}

private func detectedNewsLinks(in text: String) -> [(range: NSRange, url: URL)] {
    var links: [(range: NSRange, url: URL)] = NewsTextLinks.shared.find(text: text).compactMap { link in
        guard let url = URL(string: link.url) else { return nil }
        return (NSRange(location: Int(link.range.start), length: Int(link.range.endExclusive - link.range.start)), url)
    }
    let detector = try? NSDataDetector(
        types: NSTextCheckingResult.CheckingType.link.rawValue
    )
    let range = NSRange(text.startIndex..<text.endIndex, in: text)

    for match in detector?.matches(in: text, options: [], range: range) ?? [] {
        if let url = match.url, !links.contains(where: { NSIntersectionRange($0.range, match.range).length > 0 }) {
            links.append((match.range, url))
        }
    }
    return links.sorted { $0.range.location < $1.range.location }
}

final class NewsInlineAttachment: NSTextAttachment {
    let destination: URL
    let displayLabel: String?
    #if os(iOS)
    var makeContent: (@MainActor () -> AnyView)?

    override var usesTextAttachmentView: Bool {
        (allowsTextAttachmentView && makeContent != nil) || super.usesTextAttachmentView
    }

    override func viewProvider(for parentView: UIView?, location: any NSTextLocation, textContainer: NSTextContainer?) -> NSTextAttachmentViewProvider? {
        guard makeContent != nil else { return super.viewProvider(for: parentView, location: location, textContainer: textContainer) }
        return NewsAttachmentViewProvider(textAttachment: self, parentView: parentView,
                                          textLayoutManager: textContainer?.textLayoutManager, location: location)
    }
    #endif

    init(destination: URL, displayLabel: String? = nil) {
        self.destination = destination
        self.displayLabel = displayLabel
        super.init(data: nil, ofType: nil)
    }

    required init?(coder: NSCoder) {
        guard let url = coder.decodeObject(of: NSURL.self, forKey: "destination") as URL? else { return nil }
        destination = url
        displayLabel = coder.decodeObject(of: NSString.self, forKey: "displayLabel") as String?
        super.init(coder: coder)
    }

    override func encode(with coder: NSCoder) {
        super.encode(with: coder)
        coder.encode(destination as NSURL, forKey: "destination")
        coder.encode(displayLabel as NSString?, forKey: "displayLabel")
    }
}

#if os(iOS)
private final class NewsAttachmentViewProvider: NSTextAttachmentViewProvider {
    override func loadView() {
        MainActor.assumeIsolated {
            guard let attachment = textAttachment as? NewsInlineAttachment,
                  let content = attachment.makeContent?() else { return }
            let hosted = UIHostingConfiguration { content }.margins(.all, 0).makeContentView()
            hosted.frame = CGRect(origin: .zero, size: attachment.bounds.size)
            hosted.backgroundColor = .clear
            hosted.isUserInteractionEnabled = false
            hosted.accessibilityElementsHidden = true
            view = hosted
        }
    }
}

private struct NewsPreviewThumbnail: View {
    let url: URL?
    let isLoadingMetadata: Bool

    var body: some View {
        if isLoadingMetadata {
            RemoteImageLoadingSkeleton()
        } else {
            RemoteImageView(url: url) {
                ZStack {
                    Color(uiColor: .tertiarySystemFill)
                    Image(systemName: "link").font(.title3).foregroundStyle(.secondary)
                }
            }
        }
    }
}
#endif

@MainActor
func newsAttributedText(
    _ text: String, mentions: [ProgramInlineMention], images: [URL: PlatformImage] = [:],
    isSubtitle: Bool, font: NewsFont, accent: NewsColor, colorScheme: ColorScheme,
    maxWidth: CGFloat = 260, previews: [String: NewsLinkPreview] = [:]
) -> NSAttributedString {
    #if os(iOS)
    let foreground = UIColor.label
    #else
    let foreground = NSColor.labelColor
    #endif
    let result = NSMutableAttributedString(string: text, attributes: [.font: font, .foregroundColor: foreground])
    for link in detectedNewsLinks(in: text) {
        result.addAttributes([.link: link.url, .underlineStyle: NSUnderlineStyle.single.rawValue], range: link.range)
    }
    for mention in mentions.sorted(by: { $0.range.start > $1.range.start }) {
        let destination = mention.artist.map(inlineArtistLinkURL) ?? mention.place.flatMap(inlineStageLinkURL)
        guard let destination else { continue }
        let range = NSRange(location: Int(mention.range.start), length: Int(mention.range.endExclusive - mention.range.start))
        guard range.location >= 0, NSMaxRange(range) <= result.length else { continue }
        let attributes: [NSAttributedString.Key: Any] = [
            .link: destination, .foregroundColor: accent, .underlineStyle: NSUnderlineStyle.single.rawValue,
        ]
        result.addAttributes(attributes, range: range)
        let scale = font.pointSize / (isSubtitle ? 20 : 17)
        let size: CGFloat = (mention.artist != nil && !isSubtitle ? 18 : 20) * scale
        let gap = 4 * scale
        if let image = newsInlineIcon(mention, images: images, size: size, gap: gap, colorScheme: colorScheme) {
            let attachment = NewsInlineAttachment(destination: destination)
            attachment.image = image
            attachment.bounds = CGRect(x: 0, y: (font.capHeight - size) / 2, width: size + gap, height: size)
            #if os(iOS)
            if let artist = mention.artist {
                let url = artist.thumbImageUrl ?? artist.fullImageUrl
                attachment.makeContent = {
                    AnyView(HStack(spacing: 0) {
                        RemoteImageView(url: url, loadingStyle: .quiet) {
                            Image("placeholder_thumb").resizable().aspectRatio(contentMode: .fill).clipped()
                        }
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                        Spacer(minLength: 0)
                    }
                    .frame(width: size + gap, height: size)
                    .environment(\.colorScheme, colorScheme))
                }
            }
            #endif
            let prefix = NSMutableAttributedString(attachment: attachment)
            prefix.append(NSAttributedString(string: "\u{2060}"))
            prefix.addAttributes(attributes.merging([.font: font, .underlineStyle: 0]) { _, new in new }, range: NSRange(location: 0, length: prefix.length))
            result.insert(prefix, at: range.location)
        }
    }
    var webLinks: [(NSRange, URL)] = []
    result.enumerateAttribute(.link, in: NSRange(location: 0, length: result.length)) { value, range, _ in
        if let url = value as? URL, ["http", "https", "mailto"].contains(url.scheme?.lowercased() ?? "") {
            webLinks.append((range, url))
        }
    }
    for (range, url) in webLinks.reversed() {
        let displayed = result.attributedSubstring(from: range).string
        let email = NewsMailLinks.shared.address(url: url.absoluteString)
        guard let label = email ?? NewsWebLinks.shared.label(url: url.absoluteString, displayedText: displayed) else { continue }
        let attachment: NewsInlineAttachment
        if email == nil {
            let preview = previews[url.absoluteString]
            attachment = newsPreviewAttachment(url: url, preview: preview, fallback: label,
                image: preview?.imageURL.flatMap(URL.init(string:)).flatMap { images[$0] ?? cachedRemoteImage(for: $0) },
                font: font, accent: accent, colorScheme: colorScheme, maxWidth: maxWidth)
        } else {
            attachment = newsWebAttachment(url: url, label: label, font: font, accent: accent,
                                          colorScheme: colorScheme, maxWidth: maxWidth, isEmail: email != nil)
        }
        let chip = NSMutableAttributedString(attachment: attachment)
        chip.addAttributes([.link: url, .font: font, .underlineStyle: 0], range: NSRange(location: 0, length: chip.length))
        result.replaceCharacters(in: range, with: chip)
    }
    return result
}

@MainActor
private func newsWebAttachment(url: URL, label: String, font: NewsFont, accent: NewsColor,
                               colorScheme: ColorScheme, maxWidth: CGFloat, isEmail: Bool) -> NewsInlineAttachment {
    let scale = font.pointSize / 17
    let chipFont = NewsFont.systemFont(ofSize: font.pointSize * 0.76, weight: .medium)
    let paragraph = NSMutableParagraphStyle()
    paragraph.lineBreakMode = .byTruncatingTail
    #if os(iOS)
    let tint = accent.resolvedColor(with: UITraitCollection(userInterfaceStyle: colorScheme == .dark ? .dark : .light))
    #else
    let tint = accent
    #endif
    let attributes: [NSAttributedString.Key: Any] = [.font: chipFont, .foregroundColor: tint, .paragraphStyle: paragraph]
    let measured = (label as NSString).size(withAttributes: attributes)
    let iconSpace: CGFloat = isEmail ? 22 * scale : 0
    let size = CGSize(width: min(max(maxWidth, 1), ceil(measured.width + 16 * scale + iconSpace)), height: ceil(max(measured.height + 6 * scale, 26 * scale)))
    let draw: (CGContext) -> Void = { context in
        context.addPath(CGPath(roundedRect: CGRect(origin: .zero, size: size), cornerWidth: 6 * scale, cornerHeight: 6 * scale, transform: nil))
        context.setFillColor(tint.withAlphaComponent(colorScheme == .dark ? 0.22 : 0.12).cgColor)
        context.fillPath()
        if isEmail {
            let iconRect = CGRect(x: 8 * scale, y: (size.height - 16 * scale) / 2, width: 16 * scale, height: 16 * scale)
            #if os(iOS)
            if let icon = UIImage(systemName: "envelope")?.withTintColor(tint, renderingMode: .alwaysOriginal) {
                icon.draw(in: newsAspectFitRect(imageSize: icon.size, target: iconRect))
            }
            #else
            ("✉︎" as NSString).draw(in: iconRect, withAttributes: [.font: NewsFont.systemFont(ofSize: 16 * scale), .foregroundColor: tint])
            #endif
        }
        let textRect = CGRect(x: 8 * scale + iconSpace, y: (size.height - measured.height) / 2,
                              width: max(0, size.width - 16 * scale - iconSpace), height: measured.height)
        (label as NSString).draw(in: textRect, withAttributes: attributes)
    }
    let image: PlatformImage
    #if os(iOS)
    image = UIGraphicsImageRenderer(size: size).image { draw($0.cgContext) }
    #else
    image = NSImage(size: size, flipped: false) { _ in
        guard let context = NSGraphicsContext.current?.cgContext else { return false }
        draw(context)
        return true
    }
    #endif
    let attachment = NewsInlineAttachment(destination: url, displayLabel: label)
    attachment.image = image
    attachment.bounds = CGRect(x: 0, y: (font.capHeight - size.height) / 2, width: size.width, height: size.height)
    #if os(iOS)
    attachment.accessibilityLabel = label
    attachment.accessibilityValue = url.absoluteString
    #endif
    return attachment
}

func newsAspectFillRect(imageSize: CGSize, target: CGRect) -> CGRect {
    guard imageSize.width > 0, imageSize.height > 0 else { return target }
    let factor = max(target.width / imageSize.width, target.height / imageSize.height)
    let size = CGSize(width: imageSize.width * factor, height: imageSize.height * factor)
    return CGRect(x: target.midX - size.width / 2, y: target.midY - size.height / 2, width: size.width, height: size.height)
}

func newsAspectFitRect(imageSize: CGSize, target: CGRect) -> CGRect {
    guard imageSize.width > 0, imageSize.height > 0 else { return target }
    let factor = min(target.width / imageSize.width, target.height / imageSize.height)
    let size = CGSize(width: imageSize.width * factor, height: imageSize.height * factor)
    return CGRect(x: target.midX - size.width / 2, y: target.midY - size.height / 2, width: size.width, height: size.height)
}

@MainActor
private func newsPreviewAttachment(url: URL, preview: NewsLinkPreview?, fallback: String, image: PlatformImage?,
                                   font: NewsFont, accent: NewsColor, colorScheme: ColorScheme, maxWidth: CGFloat) -> NewsInlineAttachment {
    let scale = font.pointSize / 17
    let size = CGSize(width: max(1, maxWidth), height: 92 * scale)
    let padding = min(10 * scale, size.width / 10)
    let side = min(72 * scale, size.width * 0.28)
    let thumbnail = CGRect(x: padding, y: (size.height - side) / 2, width: side, height: side)
    let title = preview?.title ?? fallback
    let domain = preview?.domain ?? NewsLinkPreviews.shared.domain(url: url.absoluteString)
    #if os(iOS)
    let traits = UITraitCollection(userInterfaceStyle: colorScheme == .dark ? .dark : .light)
    let tint = accent.resolvedColor(with: traits)
    let titleColor = UIColor.label.resolvedColor(with: traits)
    let domainColor = UIColor.secondaryLabel.resolvedColor(with: traits)
    #else
    let tint = accent
    let titleColor = NSColor.labelColor
    let domainColor = NSColor.secondaryLabelColor
    #endif
    let paragraph = NSMutableParagraphStyle()
    paragraph.lineBreakMode = .byTruncatingTail
    let titleFont = NewsFont.systemFont(ofSize: 15 * scale, weight: .medium)
    let domainFont = NewsFont.systemFont(ofSize: 12 * scale)
    let titleParagraph = NSMutableParagraphStyle()
    titleParagraph.lineBreakMode = .byWordWrapping
    let draw: (CGContext) -> Void = { context in
        context.addPath(CGPath(roundedRect: CGRect(origin: .zero, size: size), cornerWidth: 12 * scale, cornerHeight: 12 * scale, transform: nil))
        context.setFillColor(tint.withAlphaComponent(colorScheme == .dark ? 0.22 : 0.12).cgColor)
        context.fillPath()
        context.saveGState()
        context.addPath(CGPath(roundedRect: thumbnail, cornerWidth: 8 * scale, cornerHeight: 8 * scale, transform: nil))
        context.clip()
        context.setFillColor(tint.withAlphaComponent(0.12).cgColor)
        context.fill(thumbnail)
        if let image { image.draw(in: newsAspectFillRect(imageSize: image.size, target: thumbnail)) }
        else {
            let glyph = "↗" as NSString
            let attributes: [NSAttributedString.Key: Any] = [.font: NewsFont.systemFont(ofSize: min(side * 0.4, 26 * scale)), .foregroundColor: tint]
            let measured = glyph.size(withAttributes: attributes)
            glyph.draw(at: CGPoint(x: thumbnail.midX - measured.width / 2, y: thumbnail.midY - measured.height / 2), withAttributes: attributes)
        }
        context.restoreGState()
        let x = thumbnail.maxX + 12 * scale
        let width = max(0, size.width - x - padding)
        let titleAttributes: [NSAttributedString.Key: Any] = [.font: titleFont, .foregroundColor: titleColor, .paragraphStyle: titleParagraph]
        let measured = (title as NSString).boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
                                                       options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: titleAttributes, context: nil)
        let titleHeight = min(ceil(measured.height), 36 * scale)
        let domainHeight = 18 * scale
        let top = (size.height - titleHeight - domainHeight - 6 * scale) / 2
        (title as NSString).draw(with: CGRect(x: x, y: top, width: width, height: titleHeight),
                                 options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], attributes: titleAttributes, context: nil)
        (domain as NSString).draw(in: CGRect(x: x, y: top + titleHeight + 6 * scale, width: width, height: domainHeight),
                                          withAttributes: [.font: domainFont, .foregroundColor: domainColor, .paragraphStyle: paragraph])
    }
    let bitmap: PlatformImage
    #if os(iOS)
    bitmap = UIGraphicsImageRenderer(size: size).image { draw($0.cgContext) }
    #else
    bitmap = NSImage(size: size, flipped: false) { _ in
        guard let context = NSGraphicsContext.current?.cgContext else { return false }
        draw(context)
        return true
    }
    #endif
    let attachment = NewsInlineAttachment(destination: url, displayLabel: title)
    attachment.image = bitmap
    attachment.bounds = CGRect(x: 0, y: font.descender, width: size.width, height: size.height)
    #if os(iOS)
    attachment.accessibilityLabel = title + ", " + domain
    attachment.accessibilityValue = url.absoluteString
    attachment.makeContent = {
        AnyView(HStack(spacing: 12 * scale) {
            NewsPreviewThumbnail(url: preview?.imageURL.flatMap(URL.init(string:)), isLoadingMetadata: preview == nil)
                .frame(width: side, height: side)
                .clipShape(RoundedRectangle(cornerRadius: 8 * scale))
            VStack(alignment: .leading, spacing: 6 * scale) {
                Text(title).font(.system(size: 15 * scale, weight: .medium)).foregroundStyle(Color(uiColor: titleColor))
                    .lineLimit(2)
                Text(domain).font(.system(size: 12 * scale)).foregroundStyle(Color(uiColor: domainColor))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(padding)
        .frame(width: size.width, height: size.height)
        .background(Color(uiColor: tint.withAlphaComponent(colorScheme == .dark ? 0.22 : 0.12)))
        .clipShape(RoundedRectangle(cornerRadius: 12 * scale))
        .environment(\.colorScheme, colorScheme))
    }
    #endif
    return attachment
}

@MainActor
private func newsInlineIcon(
    _ mention: ProgramInlineMention, images: [URL: PlatformImage], size: CGFloat, gap: CGFloat,
    colorScheme: ColorScheme
) -> PlatformImage? {
    let stageCode = mention.place?.displayCode?.trimmingCharacters(in: .whitespacesAndNewlines)
    guard mention.artist != nil || stageCode?.isEmpty == false else { return nil }
    let canvas = CGSize(width: size + gap, height: size)
    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    let draw: (CGContext) -> Void = { context in
        context.saveGState()
        defer { context.restoreGState() }
        if let artist = mention.artist {
            context.addEllipse(in: rect)
            context.clip()
            let url = artist.thumbImageUrl ?? artist.fullImageUrl
            let image = url.flatMap { images[$0] ?? cachedRemoteImage(for: $0) }
                ?? (url == nil ? PlatformImage(named: "placeholder_thumb") : nil)
            if let image, image.size.width > 0, image.size.height > 0 {
                let factor = max(size / image.size.width, size / image.size.height)
                let width = image.size.width * factor
                let height = image.size.height * factor
                image.draw(in: CGRect(x: (size - width) / 2, y: (size - height) / 2, width: width, height: height))
            } else {
                context.setFillColor(NewsColor.gray.withAlphaComponent(0.12).cgColor)
                context.fill(rect)
            }
        } else if let stage = mention.place, let code = stageCode, !code.isEmpty {
            let base = NewsColor(StageNumber.baseColor(for: stage, colorScheme: colorScheme))
            #if os(iOS)
            let tint = base.resolvedColor(with: UITraitCollection(userInterfaceStyle: colorScheme == .dark ? .dark : .light))
            #else
            let tint = base
            #endif
            context.addPath(CGPath(roundedRect: rect, cornerWidth: size * 0.25, cornerHeight: size * 0.25, transform: nil))
            context.setFillColor(tint.withAlphaComponent(0.2).cgColor)
            context.fillPath()
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NewsFont.systemFont(ofSize: size * 0.56, weight: .semibold), .foregroundColor: tint,
            ]
            let glyph = code as NSString
            let measured = glyph.size(withAttributes: attributes)
            glyph.draw(at: CGPoint(x: (size - measured.width) / 2, y: (size - measured.height) / 2), withAttributes: attributes)
        }
    }
    #if os(iOS)
    return UIGraphicsImageRenderer(size: canvas).image { draw($0.cgContext) }
    #else
    return NSImage(size: canvas, flipped: false) { _ in
        guard let context = NSGraphicsContext.current?.cgContext else { return false }
        draw(context)
        return true
    }
    #endif
}

private struct NativeNewsText {
    let text: String
    let mentions: [ProgramInlineMention]
    let images: [URL: PlatformImage]
    let isSubtitle: Bool
    let colorScheme: ColorScheme
    let dynamicTypeSize: DynamicTypeSize
    var previews: [String: NewsLinkPreview] = [:]
    let onOpenURL: (URL) -> Void
}

#if os(iOS)
private struct NewsTextRenderInput: Equatable {
    let text: String
    let mentions: [ProgramInlineMention]
    let previews: [String: NewsLinkPreview]
    let isSubtitle: Bool
    let font: UIFont
    let accent: UIColor
    let colorScheme: ColorScheme
    let width: CGFloat
}

private final class NewsUIKitTextView: UITextView {
    var renderInput: NewsTextRenderInput?
}

extension NativeNewsText: UIViewRepresentable {
    func makeUIView(context: Context) -> NewsUIKitTextView {
        let view = NewsUIKitTextView(usingTextLayoutManager: true)
        view.isEditable = false
        view.isScrollEnabled = false
        view.isSelectable = true
        // UIKit's drag lift can invalidate ranges around linked inline attachments.
        // These read-only articles keep selection and link menus without text dragging.
        view.textDragInteraction?.isEnabled = false
        view.backgroundColor = .clear
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.delegate = context.coordinator
        return view
    }

    func updateUIView(_ view: NewsUIKitTextView, context: Context) {
        context.coordinator.onOpenURL = onOpenURL
        context.coordinator.mentions = mentions
        updateText(view, width: view.bounds.width > 0 ? view.bounds.width : 260)
    }

    @MainActor private func updateText(_ view: NewsUIKitTextView, width: CGFloat) {
        var font = UIFont.preferredFont(forTextStyle: isSubtitle ? .title3 : .body, compatibleWith: view.traitCollection)
        if isSubtitle, let descriptor = font.fontDescriptor.withSymbolicTraits(.traitBold) {
            font = UIFont(descriptor: descriptor, size: font.pointSize)
        }
        let input = NewsTextRenderInput(text: text, mentions: mentions, previews: previews, isSubtitle: isSubtitle,
                                        font: font, accent: view.tintColor, colorScheme: colorScheme, width: width)
        guard view.renderInput != input else { return }
        view.renderInput = input
        view.linkTextAttributes = [.foregroundColor: view.tintColor as Any]
        view.attributedText = newsAttributedText(text, mentions: mentions, images: images, isSubtitle: isSubtitle,
                                                font: font, accent: view.tintColor, colorScheme: colorScheme, maxWidth: width, previews: previews)
        view.accessibilityIdentifier = isSubtitle ? "news-inline-subtitle" : "news-inline-content"
        view.invalidateIntrinsicContentSize()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: NewsUIKitTextView, context: Context) -> CGSize? {
        guard let width = proposal.width, width > 0 else { return nil }
        updateText(uiView, width: width)
        return uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
    }

    func makeCoordinator() -> Coordinator { Coordinator(onOpenURL: onOpenURL) }

    final class Coordinator: NSObject, UITextViewDelegate {
        var onOpenURL: (URL) -> Void
        var mentions: [ProgramInlineMention] = []
        init(onOpenURL: @escaping (URL) -> Void) { self.onOpenURL = onOpenURL }

        func textView(_ textView: UITextView, primaryActionFor textItem: UITextItem, defaultAction: UIAction) -> UIAction? {
            let url: URL
            switch textItem.content {
            case .link(let link): url = link
            case .textAttachment(let attachment):
                guard let attachment = attachment as? NewsInlineAttachment else { return defaultAction }
                url = attachment.destination
            default: return defaultAction
            }
            return UIAction { [weak self] _ in self?.onOpenURL(url) }
        }

        func textView(_ textView: UITextView, menuConfigurationFor textItem: UITextItem, defaultMenu: UIMenu) -> UITextItem.MenuConfiguration? {
            let url: URL
            switch textItem.content {
            case .link(let link): url = link
            case .textAttachment(let attachment):
                guard let attachment = attachment as? NewsInlineAttachment else { return .init(menu: defaultMenu) }
                url = attachment.destination
            default: return .init(menu: defaultMenu)
            }
            if let artist = mentions.compactMap(\.artist).first(where: { inlineArtistLinkURL(for: $0) == url }) {
                return .init(preview: nil, menu: UIMenu(title: artist.formattedName, children: [
                    UIAction(title: NSLocalizedString("news.open_artist", comment: ""), image: UIImage(systemName: "theatermasks.fill")) { [weak self] _ in
                        self?.onOpenURL(url)
                    },
                ]))
            }
            if let stage = mentions.compactMap(\.place).first(where: { inlineStageLinkURL(for: $0) == url }) {
                return .init(preview: nil, menu: UIMenu(title: stage.localizedName, children: [
                    UIAction(title: NSLocalizedString("news.open_stage", comment: ""), image: UIImage(systemName: "mappin.and.ellipse")) { [weak self] _ in
                        self?.onOpenURL(url)
                    },
                ]))
            }
            let email = NewsMailLinks.shared.address(url: url.absoluteString)
            guard email != nil || ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { return .init(menu: defaultMenu) }
            return .init(preview: nil, menu: UIMenu(title: email ?? url.absoluteString, children: [
                UIAction(title: NSLocalizedString(email != nil ? "news.write_email" : "news.open_link", comment: ""), image: UIImage(systemName: email != nil ? "envelope" : "arrow.up.right")) { [weak self] _ in
                    self?.onOpenURL(url)
                },
                UIAction(title: NSLocalizedString(email != nil ? "copy.email.title" : "copy.link.title", comment: ""), image: UIImage(systemName: "doc.on.doc")) { _ in
                    UIPasteboard.general.string = email ?? url.absoluteString
                },
            ]))
        }
    }
}
#else
extension NativeNewsText: NSViewRepresentable {
    func makeNSView(context: Context) -> NewsMacTextView {
        let view = NewsMacTextView()
        view.isEditable = false
        view.isSelectable = true
        view.drawsBackground = false
        view.textContainerInset = .zero
        view.textContainer?.lineFragmentPadding = 0
        view.textContainer?.widthTracksTextView = true
        view.isHorizontallyResizable = false
        view.isVerticallyResizable = true
        view.delegate = context.coordinator
        return view
    }

    func updateNSView(_ view: NewsMacTextView, context: Context) {
        context.coordinator.onOpenURL = onOpenURL
        view.onOpenURL = onOpenURL
        let font = NSFont.systemFont(ofSize: isSubtitle ? 20 : NSFont.systemFontSize,
                                     weight: isSubtitle ? .bold : .regular)
        let accent = NSColor.controlAccentColor
        view.linkTextAttributes = [.foregroundColor: accent]
        view.textStorage?.setAttributedString(newsAttributedText(text, mentions: mentions, images: images,
            isSubtitle: isSubtitle, font: font, accent: accent, colorScheme: colorScheme,
            maxWidth: view.bounds.width > 0 ? view.bounds.width : 260, previews: previews))
        view.invalidateIntrinsicContentSize()
    }

    @available(macOS 13.0, *)
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NewsMacTextView, context: Context) -> CGSize? {
        guard let width = proposal.width, width > 0 else { return nil }
        return nsView.contentSize(width: width)
    }

    func makeCoordinator() -> Coordinator { Coordinator(onOpenURL: onOpenURL) }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var onOpenURL: (URL) -> Void
        init(onOpenURL: @escaping (URL) -> Void) { self.onOpenURL = onOpenURL }

        func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
            guard let url = link as? URL else { return false }
            onOpenURL(url)
            return true
        }
    }
}

private final class NewsMacTextView: NSTextView {
    var onOpenURL: ((URL) -> Void)?

    override func menu(for event: NSEvent) -> NSMenu? {
        guard let layoutManager, let textContainer else { return super.menu(for: event) }
        var point = convert(event.locationInWindow, from: nil)
        point.x -= textContainerOrigin.x
        point.y -= textContainerOrigin.y
        let glyph = layoutManager.glyphIndex(for: point, in: textContainer)
        guard glyph < layoutManager.numberOfGlyphs,
              layoutManager.boundingRect(forGlyphRange: NSRange(location: glyph, length: 1), in: textContainer).contains(point) else { return super.menu(for: event) }
        let index = layoutManager.characterIndexForGlyph(at: glyph)
        guard let url = textStorage?.attribute(.link, at: index, effectiveRange: nil) as? URL,
              ["http", "https", "mailto"].contains(url.scheme?.lowercased() ?? "") else { return super.menu(for: event) }
        let menu = NSMenu()
        let email = NewsMailLinks.shared.address(url: url.absoluteString)
        let address = NSMenuItem(title: email ?? url.absoluteString, action: nil, keyEquivalent: "")
        address.isEnabled = false
        menu.addItem(address)
        for (title, action) in [(NSLocalizedString(email != nil ? "news.write_email" : "news.open_link", comment: ""), #selector(openWebLink(_:))),
                                (NSLocalizedString(email != nil ? "copy.email.title" : "copy.link.title", comment: ""), #selector(copyWebLink(_:)))] {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.target = self
            item.representedObject = url
            menu.addItem(item)
        }
        return menu
    }

    @objc private func openWebLink(_ sender: NSMenuItem) {
        if let url = sender.representedObject as? URL { onOpenURL?(url) }
    }

    @objc private func copyWebLink(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(NewsMailLinks.shared.address(url: url.absoluteString) ?? url.absoluteString, forType: .string)
    }

    func contentSize(width: CGFloat) -> CGSize {
        guard let textContainer, let layoutManager else { return .zero }
        textContainer.containerSize = CGSize(width: width, height: .greatestFiniteMagnitude)
        layoutManager.ensureLayout(for: textContainer)
        return CGSize(width: width, height: ceil(layoutManager.usedRect(for: textContainer).height))
    }

    override var intrinsicContentSize: NSSize {
        CGSize(width: NSView.noIntrinsicMetric, height: contentSize(width: max(bounds.width, 1)).height)
    }

    override func setFrameSize(_ newSize: NSSize) {
        let changed = abs(frame.width - newSize.width) > 0.5
        super.setFrameSize(newSize)
        if changed { invalidateIntrinsicContentSize() }
    }
}
#endif

private struct YouTubePreview: Identifiable {
    let videoID: String
    let videoURL: URL

    var id: String {
        videoID
    }
}

private struct YouTubePreviewCard: View {
    let preview: YouTubePreview
    let isPlayerLoaded: Bool
    let loadPlayer: () -> Void

    var body: some View {
        YouTubeVideoView(
            videoID: preview.videoID,
            videoURL: preview.videoURL,
            cornerRadius: 22,
            isPlayerLoaded: isPlayerLoaded,
            loadPlayer: loadPlayer
        )
        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
    }
}

struct NewsItemDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NewsItemDetailView(newsItem: .example)
            .environmentObject(UserSettings())
            .environmentObject(DataStore())
    }
}
