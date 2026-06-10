import SwiftUI

#if os(iOS)
import TipKit
#endif

private let areDiscoverabilityTipsEnabled = false

struct AppDiscoverabilityTip: Identifiable, Sendable {
    let id: String

#if os(iOS)
    fileprivate let tip: any Tip
#endif

    fileprivate init(
        id: String,
        titleKey: String,
        messageKey: String,
        systemImage: String
    ) {
        self.id = id

#if os(iOS)
        self.tip = BasicDiscoverabilityTip(
            id: id,
            titleKey: titleKey,
            messageKey: messageKey,
            systemImage: systemImage
        )
#endif
    }
}

#if os(iOS)
private struct BasicDiscoverabilityTip: Tip {
    let id: String
    let titleKey: String
    let messageKey: String
    let systemImage: String

    var title: Text {
        Text(LocalizedStringKey(titleKey))
    }

    var message: Text? {
        Text(LocalizedStringKey(messageKey))
    }

    var image: Image? {
        Image(systemName: systemImage)
    }

    var rules: [Rule] {
        []
    }

    var options: [any TipOption] {
        [MaxDisplayCount(1)]
    }

    var actions: [Action] {
        []
    }
}
#endif

enum DiscoverabilityTips {
    static let artistViewMode = AppDiscoverabilityTip(
        id: "discoverability.artist.view-mode",
        titleKey: "tip.artist.view_mode.title",
        messageKey: "tip.artist.view_mode.message",
        systemImage: "square.grid.2x2"
    )

    static let artistFilters = AppDiscoverabilityTip(
        id: "discoverability.artist.filters",
        titleKey: "tip.artist.filters.title",
        messageKey: "tip.artist.filters.message",
        systemImage: "line.3.horizontal.decrease.circle"
    )

    static let artistFavorites = AppDiscoverabilityTip(
        id: "discoverability.artist.favorites",
        titleKey: "tip.artist.favorites.title",
        messageKey: "tip.artist.favorites.message",
        systemImage: "heart.fill"
    )

    static let scheduleViewMode = AppDiscoverabilityTip(
        id: "discoverability.schedule.view-mode",
        titleKey: "tip.schedule.view_mode.title",
        messageKey: "tip.schedule.view_mode.message",
        systemImage: "rectangle.grid.1x2"
    )

    static let scheduleFilters = AppDiscoverabilityTip(
        id: "discoverability.schedule.filters",
        titleKey: "tip.schedule.filters.title",
        messageKey: "tip.schedule.filters.message",
        systemImage: "wand.and.stars"
    )

    static let eventQuickActions = AppDiscoverabilityTip(
        id: "discoverability.events.quick-actions",
        titleKey: "tip.events.quick_actions.title",
        messageKey: "tip.events.quick_actions.message",
        systemImage: "hand.tap"
    )

    static let locationsViewMode = AppDiscoverabilityTip(
        id: "discoverability.locations.view-mode",
        titleKey: "tip.locations.view_mode.title",
        messageKey: "tip.locations.view_mode.message",
        systemImage: "map"
    )

    static let mapLegend = AppDiscoverabilityTip(
        id: "discoverability.map.legend",
        titleKey: "tip.map.legend.title",
        messageKey: "tip.map.legend.message",
        systemImage: "line.3.horizontal.decrease.circle"
    )

    static let mapRecenter = AppDiscoverabilityTip(
        id: "discoverability.map.recenter",
        titleKey: "tip.map.recenter.title",
        messageKey: "tip.map.recenter.message",
        systemImage: "scope"
    )

    static let artistRating = AppDiscoverabilityTip(
        id: "discoverability.artist.rating",
        titleKey: "tip.artist.rating.title",
        messageKey: "tip.artist.rating.message",
        systemImage: "heart.fill"
    )

    static let artistIconPicker = AppDiscoverabilityTip(
        id: "discoverability.artist.icon-picker",
        titleKey: "tip.artist.icon_picker.title",
        messageKey: "tip.artist.icon_picker.message",
        systemImage: "ellipsis.circle"
    )

    static let artistNotes = AppDiscoverabilityTip(
        id: "discoverability.artist.notes",
        titleKey: "tip.artist.notes.title",
        messageKey: "tip.artist.notes.message",
        systemImage: "square.and.pencil"
    )

    static let newsSwipeReadState = AppDiscoverabilityTip(
        id: "discoverability.news.read-state",
        titleKey: "tip.news.read_state.title",
        messageKey: "tip.news.read_state.message",
        systemImage: "rectangle.portrait.and.arrow.right"
    )

    static let stageMapPreview = AppDiscoverabilityTip(
        id: "discoverability.stage.map-preview",
        titleKey: "tip.stage.map_preview.title",
        messageKey: "tip.stage.map_preview.message",
        systemImage: "map"
    )
}

enum DiscoverabilityTipSequences {
    static let artistScreen = [
        DiscoverabilityTips.artistViewMode,
        DiscoverabilityTips.artistFilters,
        DiscoverabilityTips.artistFavorites,
    ]

    static let artistMapScreen = [
        DiscoverabilityTips.artistViewMode,
    ]

    static let scheduleScreen = [
        DiscoverabilityTips.scheduleViewMode,
        DiscoverabilityTips.scheduleFilters,
        DiscoverabilityTips.eventQuickActions,
    ]

    static let locationsScreen = [
        DiscoverabilityTips.locationsViewMode,
        DiscoverabilityTips.mapLegend,
        DiscoverabilityTips.mapRecenter,
    ]

    static let artistDetailScreen = [
        DiscoverabilityTips.artistRating,
        DiscoverabilityTips.artistIconPicker,
        DiscoverabilityTips.artistNotes,
        DiscoverabilityTips.eventQuickActions,
    ]

    static let newsScreen = [
        DiscoverabilityTips.newsSwipeReadState,
    ]

    static let stageDetailScreen = [
        DiscoverabilityTips.stageMapPreview,
    ]
}

@MainActor
final class TipSequencer: ObservableObject {
    @Published private(set) var currentTipID: String? = nil

    private let tips: [AppDiscoverabilityTip]

#if os(iOS)
    private var observerTasks: [Task<Void, Never>] = []
#endif

    init(_ tips: [AppDiscoverabilityTip]) {
        self.tips = tips
        refreshCurrentTip()
        startObserving()
    }

    deinit {
#if os(iOS)
        observerTasks.forEach { task in
            task.cancel()
        }
#endif
    }

    func isCurrent(_ tip: AppDiscoverabilityTip) -> Bool {
        currentTipID == tip.id
    }

    private func refreshCurrentTip() {
        guard areDiscoverabilityTipsEnabled else {
            currentTipID = nil
            return
        }

#if os(iOS)
        currentTipID = tips.first(where: { appTip in
            appTip.tip.shouldDisplay
        })?.id
#else
        currentTipID = nil
#endif
    }

    private func startObserving() {
        guard areDiscoverabilityTipsEnabled else {
            return
        }

#if os(iOS)
        observerTasks = tips.map { appTip in
            Task { [weak self] in
                for await _ in appTip.tip.shouldDisplayUpdates {
                    self?.handleTipStatusChange()
                }
            }
        }
#endif
    }

    private func handleTipStatusChange() {
        refreshCurrentTip()
    }
}

func configureDiscoverabilityTips() {
    guard areDiscoverabilityTipsEnabled else {
        return
    }

#if os(iOS)
    do {
        try Tips.configure([
            .displayFrequency(.immediate),
        ])
    } catch {
        print("Error configuring TipKit: \(error.localizedDescription)")
    }
#endif
}

struct AppInlineTipView: View {
    let tip: AppDiscoverabilityTip
    let currentTipID: String?
    var arrowEdge: Edge? = .top

    var body: some View {
#if os(iOS)
        if currentTipID == tip.id {
            TipView(tip.tip, arrowEdge: arrowEdge)
                .tipBackground(.regularMaterial)
                .tipCornerRadius(18)
                .padding(.horizontal, 16)
        } else {
            EmptyView()
        }
#else
        EmptyView()
#endif
    }
}

extension View {
    @ViewBuilder
    func appPopoverTip(
        _ tip: AppDiscoverabilityTip,
        currentTipID: String?,
        arrowEdge: Edge? = nil
    ) -> some View {
#if os(iOS)
        if let arrowEdge {
            popoverTip(
                currentTipID == tip.id ? tip.tip : nil,
                arrowEdge: arrowEdge
            )
        } else {
            popoverTip(currentTipID == tip.id ? tip.tip : nil)
        }
#else
        self
#endif
    }
}
