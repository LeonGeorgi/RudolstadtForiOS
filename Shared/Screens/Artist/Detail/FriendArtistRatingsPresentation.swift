#if os(iOS)
import SwiftUI

private struct FriendRatingsPresentation: Identifiable {
    let id = UUID()
    let summary: FriendArtistRatingSummary
    let source: CGRect
}

private struct PresentFriendRatingsKey: EnvironmentKey {
    static let defaultValue: ((FriendArtistRatingSummary, CGRect) -> Void)? = nil
}

private struct FriendRatingsSourceHiddenKey: EnvironmentKey {
    static let defaultValue = false
}

private extension EnvironmentValues {
    var presentFriendRatings: ((FriendArtistRatingSummary, CGRect) -> Void)? {
        get { self[PresentFriendRatingsKey.self] }
        set { self[PresentFriendRatingsKey.self] = newValue }
    }

    var friendRatingsSourceHidden: Bool {
        get { self[FriendRatingsSourceHiddenKey.self] }
        set { self[FriendRatingsSourceHiddenKey.self] = newValue }
    }
}

struct FriendArtistRatingsButton: View {
    let summary: FriendArtistRatingSummary
    @Environment(\.presentFriendRatings) private var present
    @Environment(\.friendRatingsSourceHidden) private var isHidden
    @State private var source = CGRect.zero

    var body: some View {
        Button {
            guard !source.isEmpty else { return }
            present?(summary, source)
        } label: {
            FriendArtistRatingsBubble(summary: summary, style: .detailInline)
                .fixedSize()
                .onGeometryChange(for: CGRect.self) { geometry in
                    geometry.frame(in: .global)
                } action: { frame in
                    source = frame
                }
                .frame(minWidth: 56, minHeight: 56, alignment: .bottomTrailing)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .fixedSize()
        .opacity(isHidden ? 0 : 1)
        .accessibilityIdentifier("artist-friend-ratings")
        .accessibilityHint(Text("artist.friend_ratings.open"))
    }
}

struct FriendArtistRatingsPresentationModifier: ViewModifier {
    let artistName: String
    @State private var presentation: FriendRatingsPresentation?

    func body(content: Content) -> some View {
        content
            .environment(\.presentFriendRatings, { summary, source in
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    presentation = FriendRatingsPresentation(summary: summary, source: source)
                }
            })
            .environment(\.friendRatingsSourceHidden, presentation != nil)
            .fullScreenCover(item: $presentation) { selection in
                FriendArtistRatingsOverlay(artistName: artistName, presentation: selection)
                    .presentationBackground(.clear)
                    .interactiveDismissDisabled()
            }
    }
}

private struct FriendRatingsAvatarAnchors: PreferenceKey {
    static let defaultValue: [String: Anchor<CGRect>] = [:]
    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct FriendArtistRatingsOverlay: View {
    let artistName: String
    let presentation: FriendRatingsPresentation
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expanded = false
    @State private var closing = false
    @State private var settled = false
    @State private var openedAt = Date()
    // Preserve the current pose when closing interrupts the opening animation.
    @State private var returnStart = FriendArtistRatingsMotion.Values.expanded
    @State private var avatarFrames: [String: CGRect] = [:]
    @AccessibilityFocusState private var closeFocused: Bool
    @ScaledMetric(relativeTo: .body) private var rowHeight: CGFloat = 60
    @ScaledMetric(relativeTo: .title2) private var headerHeight: CGFloat = 96

    var body: some View {
        KeyframeAnimator(initialValue: closing ? returnStart : .init(), trigger: expanded) { values in
            overlay(values: reduceMotion ? .expanded : values)
        } keyframes: { initial in
            FriendArtistRatingsMotion.Frames(opening: expanded, initial: initial)
        }
        .ignoresSafeArea()
        .accessibilityAction(.escape, close)
        .task {
            openedAt = Date()
            expanded = true
            if !reduceMotion {
                do {
                    try await Task.sleep(for: .seconds(FriendArtistRatingsMotion.duration))
                } catch { return }
            }
            guard !closing else { return }
            settled = true
            closeFocused = true
        }
        .task(id: closing) {
            guard closing else { return }
            if !reduceMotion {
                do {
                    try await Task.sleep(for: .seconds(FriendArtistRatingsMotion.duration))
                } catch { return }
            }
            dismissWithoutTransition()
        }
    }

    private func overlay(values: FriendArtistRatingsMotion.Values) -> some View {
        GeometryReader { geometry in
            let availableHeight = max(0, geometry.size.height - geometry.safeAreaInsets.top - geometry.safeAreaInsets.bottom - 40)
            ZStack {
                Color.black.opacity(0.28 * values.reveal)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: close)
                    .accessibilityHidden(true)

                card(values: values)
                    .frame(
                        width: max(0, min(400, geometry.size.width - 40)),
                        height: min(availableHeight, headerHeight + rowHeight * CGFloat(presentation.summary.entries.count) + 12)
                    )
                    .background(.background, in: RoundedRectangle(cornerRadius: 28))
                    .shadow(color: .black.opacity(0.15), radius: 22, y: 12)
                    .opacity(values.reveal)
                    .position(x: geometry.size.width / 2, y: geometry.safeAreaInsets.top + 20 + availableHeight / 2)
            }
            .overlayPreferenceValue(FriendRatingsAvatarAnchors.self) { anchors in
                GeometryReader { proxy in
                    let frames = anchors.mapValues { proxy[$0] }
                    Color.clear
                        .overlay {
                            if !settled && !reduceMotion {
                                flyingBadges(
                                    values: values,
                                    frames: closing ? avatarFrames : frames,
                                    geometry: proxy
                                )
                            }
                        }
                        .onChange(of: frames, initial: true) { _, frames in
                            if !closing && !frames.isEmpty {
                                avatarFrames = frames
                            }
                        }
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            .onChange(of: geometry.size) { dismissWithoutTransition() }
        }
    }

    private func card(values: FriendArtistRatingsMotion.Values) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("artist.friend_ratings.title")
                        .font(.title2.bold())
                        .accessibilityHeading(.h2)
                    Text(artistName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                Button(action: close) {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("artist.friend_ratings.close"))
                .accessibilityFocused($closeFocused)
                .accessibilityIdentifier("artist-friend-ratings-close")
            }
            .padding(.leading, 24)
            .padding(.trailing, 12)
            .padding(.top, 16)
            .padding(.bottom, 12)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(presentation.summary.entries.enumerated()), id: \.element.id) { index, entry in
                        row(entry: entry, index: index, values: values)
                            .frame(minHeight: rowHeight)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            }
            .scrollDisabled(!settled)
        }
        .accessibilityIdentifier("artist-friend-ratings-overview")
    }

    private func row(entry: FriendArtistRatingSummary.Entry, index: Int, values: FriendArtistRatingsMotion.Values) -> some View {
        let appearance = reduceMotion ? 1 : FriendArtistRatingsMotion.reveal((values[index] - 0.85) / 0.15)
        return HStack(spacing: 12) {
            FestivalProfileBadgeAvatar(badge: entry.badge, diameter: 40, showsShadow: false)
                .opacity(index < 3 && !settled && !reduceMotion ? 0 : appearance)
                .anchorPreference(key: FriendRatingsAvatarAnchors.self, value: .bounds) { [entry.id: $0] }
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.badge.displayName)
                    .font(.body.weight(.semibold))
                Text(entry.ratingDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            .opacity(appearance)
            Spacer(minLength: 8)
            CompactArtistRatingSymbol(rating: entry.preference.rating, iconName: entry.preference.iconName)
                .frame(width: 28, height: 28)
                .opacity(appearance)
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(entry.badge.displayName), \(entry.ratingDescription)"))
    }

    private func flyingBadges(
        values: FriendArtistRatingsMotion.Values,
        frames: [String: CGRect],
        geometry: GeometryProxy
    ) -> some View {
        ForEach(Array(presentation.summary.visibleEntries.enumerated()), id: \.element.id) { index, entry in
            if let target = frames[entry.id] {
                let origin = geometry.frame(in: .global).origin
                let start = CGPoint(x: presentation.source.minX + 12 + CGFloat(index) * 20 - origin.x, y: presentation.source.midY - origin.y)
                let end = CGPoint(x: target.midX, y: target.midY)
                let progress = values[index]
                let size = 24 + 16 * min(max(progress, 0), 1)
                FriendArtistRatingBadge(
                    entry: entry,
                    style: .detailInline,
                    diameter: size,
                    preferenceOpacity: 1 - FriendArtistRatingsMotion.reveal((progress - 0.85) / 0.15)
                )
                    .position(FriendArtistRatingsMotion.point(from: start, to: end, index: index, progress: progress))
            }
        }
    }

    private func close() {
        guard !closing else { return }
        returnStart = settled ? .expanded : FriendArtistRatingsMotion.openingValue(at: Date().timeIntervalSince(openedAt))
        settled = false
        closing = true
        expanded = false
    }

    private func dismissWithoutTransition() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { dismiss() }
    }
}

private extension FriendArtistRatingSummary.Entry {
    var ratingDescription: String {
        if preference.rating > 0 {
            return String.localizedStringWithFormat(
                NSLocalizedString(
                    preference.rating == 1 ? "artist.friend_rating.value.one" : "artist.friend_rating.value.other",
                    comment: "Number of hearts a friend gave an artist"
                ),
                preference.rating
            )
        }
        let key = "artist.icon.\(preference.iconName ?? "other")"
        let text = NSLocalizedString(key, comment: "A friend's alternative artist rating")
        return text == key ? NSLocalizedString("artist.icon.other", comment: "Alternative artist rating") : text
    }
}
#endif
