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

private enum FriendRatingsAnchor: Hashable {
    case avatar(String)
    case viewport
}

private struct FriendRatingsAvatarAnchors: PreferenceKey {
    static let defaultValue: [FriendRatingsAnchor: Anchor<CGRect>] = [:]
    static func reduce(
        value: inout [FriendRatingsAnchor: Anchor<CGRect>],
        nextValue: () -> [FriendRatingsAnchor: Anchor<CGRect>]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct FriendArtistRatingsOverlay: View {
    private typealias Motion = FriendArtistRatingsMotion
    private typealias Entry = FriendArtistRatingSummary.Entry

    private enum Phase: Equatable {
        case waiting
        case flying(Motion.Flight)
        case open
    }

    let artistName: String
    let presentation: FriendRatingsPresentation
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase = Phase.waiting
    @State private var cardVisible = false
    @State private var layout: [FriendRatingsAnchor: CGRect] = [:]
    @AccessibilityFocusState private var closeFocused: Bool
    @ScaledMetric(relativeTo: .body) private var rowHeight: CGFloat = 60
    @ScaledMetric(relativeTo: .title2) private var headerHeight: CGFloat = 96

    private var badgeCount: Int { presentation.summary.visibleEntries.count }
    private var flightDuration: TimeInterval { Motion.duration(forFriendCount: presentation.summary.entries.count) }
    private var settled: Bool { phase == .open }

    private var isFlying: Bool {
        if case .flying = phase { return true }
        return false
    }

    private var playhead: TimeInterval {
        if reduceMotion { return flightDuration }
        switch phase {
        case .waiting: return 0
        case .flying(let flight): return flight.playhead(at: .now)
        case .open: return flightDuration
        }
    }

    private var overflow: [Entry] {
        guard let viewport = layout[.viewport] else { return [] }
        return presentation.summary.entries.dropFirst(badgeCount).filter { entry in
            guard let frame = layout[.avatar(entry.id)], !frame.isEmpty else { return false }
            return viewport.contains(frame)
        }
    }

    var body: some View {
        TimelineView(.animation(paused: !isFlying || reduceMotion)) { _ in
            overlay(at: playhead, overflow: overflow)
        }
        .ignoresSafeArea()
        .accessibilityAction(.escape, close)
        .task(id: phase) {
            switch phase {
            case .waiting:
                break
            case .open:
                closeFocused = true
            case .flying(let flight):
                do {
                    try await ContinuousClock().sleep(until: flight.deadline)
                } catch { return }
                guard phase == .flying(flight) else { return }
                if flight.to == 0 {
                    dismissWithoutTransition()
                } else {
                    phase = .open
                }
            }
        }
    }

    private func overlay(at playhead: TimeInterval, overflow: [Entry]) -> some View {
        GeometryReader { geometry in
            let availableHeight = max(0, geometry.size.height - geometry.safeAreaInsets.top - geometry.safeAreaInsets.bottom - 40)
            let reveal: Double = reduceMotion || cardVisible ? 1 : 0
            ZStack {
                Color.black.opacity(0.28 * reveal)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: close)
                    .accessibilityHidden(true)

                card(at: playhead, overflow: overflow)
                    .frame(
                        width: max(0, min(400, geometry.size.width - 40)),
                        height: min(availableHeight, headerHeight + rowHeight * CGFloat(presentation.summary.entries.count) + 12)
                    )
                    .background(.background, in: RoundedRectangle(cornerRadius: 28))
                    .shadow(color: .black.opacity(0.15), radius: 22, y: 12)
                    .opacity(reveal)
                    .position(x: geometry.size.width / 2, y: geometry.safeAreaInsets.top + 20 + availableHeight / 2)
            }
            .overlayPreferenceValue(FriendRatingsAvatarAnchors.self) { anchors in
                GeometryReader { proxy in
                    let frames = anchors.mapValues { proxy[$0] }
                    Color.clear
                        .overlay {
                            if !settled && !reduceMotion {
                                flyingBadges(at: playhead, overflow: overflow, geometry: proxy)
                            }
                        }
                        .onChange(of: frames, initial: true) { _, frames in
                            // Keep destinations fixed until the badges hand back to their rows.
                            guard !isFlying, frames[.viewport] != nil else { return }
                            layout = frames
                            if phase == .waiting,
                               reduceMotion || presentation.summary.visibleEntries.allSatisfy({
                                   frames[.avatar($0.id)] != nil
                               }) {
                                phase = reduceMotion ? .open : .flying(
                                    Motion.Flight(start: .now, from: 0, to: flightDuration)
                                )
                                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.13)) {
                                    cardVisible = true
                                }
                            }
                        }
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            .onChange(of: geometry.size) { dismissWithoutTransition() }
        }
    }

    private func card(at playhead: TimeInterval, overflow: [Entry]) -> some View {
        let fanIndices = Dictionary(uniqueKeysWithValues: overflow.enumerated().map { ($0.element.id, $0.offset) })
        return VStack(alignment: .leading, spacing: 0) {
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
                        let fan = fanIndices[entry.id].map {
                            Motion.fan(at: playhead, index: $0, count: overflow.count)
                        }
                        let progress = Motion.badgeProgress(at: playhead, index: min(index, badgeCount - 1))
                        let appearance = fan.map { Motion.reveal(($0.spread - 0.65) / 0.35) }
                            ?? Motion.reveal((progress - 0.85) / 0.15)
                        let isAnimatedAvatar = index < badgeCount || fan != nil
                        row(
                            entry: entry,
                            appearance: appearance,
                            avatarOpacity: isAnimatedAvatar && !settled && !reduceMotion ? 0 : appearance
                        )
                        .frame(minHeight: rowHeight)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            }
            .scrollDisabled(!settled)
            .transformAnchorPreference(key: FriendRatingsAvatarAnchors.self, value: .bounds) {
                $0[.viewport] = $1
            }
        }
        .accessibilityIdentifier("artist-friend-ratings-overview")
    }

    private func row(entry: Entry, appearance: Double, avatarOpacity: Double) -> some View {
        HStack(spacing: 12) {
            FestivalProfileBadgeAvatar(badge: entry.badge, diameter: 40)
                .opacity(avatarOpacity)
                .anchorPreference(key: FriendRatingsAvatarAnchors.self, value: .bounds) { [.avatar(entry.id): $0] }
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

    @ViewBuilder
    private func flyingBadges(
        at playhead: TimeInterval,
        overflow: [Entry],
        geometry: GeometryProxy
    ) -> some View {
        let origin = geometry.frame(in: .global).origin
        let source = presentation.source.offsetBy(dx: -origin.x, dy: -origin.y)
        let entries = presentation.summary.visibleEntries
        if !entries.isEmpty {
            let middle = entries.count / 2
            let referenceStart = sourcePoint(index: middle, source: source)
            let targetHeights = (entries + overflow).compactMap { layout[.avatar($0.id)]?.midY }
            let control = Motion.controlPoint(
                from: referenceStart,
                to: target(for: entries[middle], fallback: referenceStart),
                targetHeights: targetHeights
            )
            ZStack {
                if presentation.summary.remainingCount > 0 {
                    flyingOverflow(at: playhead, entries: overflow, source: source, control: control)
                }
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    let start = sourcePoint(index: index, source: source)
                    let progress = Motion.badgeProgress(at: playhead, index: index)
                    FriendArtistRatingBadge(
                        entry: entry,
                        style: .detailInline,
                        diameter: 24 + 16 * progress,
                        borderOpacity: 1 - Motion.reveal((progress - 0.75) / 0.20),
                        preferenceOpacity: 1 - Motion.reveal((progress - 0.85) / 0.15)
                    )
                    .position(Motion.point(
                        from: start,
                        to: target(for: entry, fallback: start),
                        control: control,
                        progress: progress
                    ))
                    .zIndex(presentation.summary.badgeZIndex(at: index))
                }
            }
        }
    }

    private func flyingOverflow(
        at playhead: TimeInterval,
        entries: [Entry],
        source: CGRect,
        control: CGPoint
    ) -> some View {
        let start = CGPoint(x: source.maxX - 12, y: source.midY)
        let groupTarget = entries.first.map { target(for: $0, fallback: start) } ?? start
        let counter = Motion.counter(at: playhead)
        let hub = entries.isEmpty ? start : Motion.point(
            from: start, to: groupTarget, control: control, progress: counter.progress
        )

        return ZStack {
            ForEach(Array(entries.enumerated().reversed()), id: \.element.id) { index, entry in
                let fan = Motion.fan(at: playhead, index: index, count: entries.count)
                let destination = target(for: entry, fallback: groupTarget)
                FestivalProfileBadgeAvatar(badge: entry.badge, diameter: 24 + 16 * fan.spread)
                    .opacity(fan.opacity)
                    .position(
                        x: hub.x + (destination.x - groupTarget.x) * fan.spread,
                        y: hub.y + (destination.y - groupTarget.y) * fan.spread
                    )
            }
            FriendArtistRemainingCountBadge(count: presentation.summary.remainingCount, style: .detailInline)
                .opacity(counter.opacity)
                .position(hub)
        }
    }

    private func sourcePoint(index: Int, source: CGRect) -> CGPoint {
        CGPoint(x: source.minX + 12 + CGFloat(index) * 20, y: source.midY)
    }

    private func target(for entry: Entry, fallback: CGPoint) -> CGPoint {
        guard let frame = layout[.avatar(entry.id)] else { return fallback }
        return CGPoint(x: frame.midX, y: frame.midY)
    }

    private func close() {
        if case .flying(let flight) = phase, flight.to == 0 { return }
        let from = playhead
        guard !reduceMotion, from > 0 else {
            dismissWithoutTransition()
            return
        }
        phase = .flying(Motion.Flight(start: .now, from: from, to: 0))
        withAnimation(.easeInOut(duration: min(0.18, from))) {
            cardVisible = false
        }
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
