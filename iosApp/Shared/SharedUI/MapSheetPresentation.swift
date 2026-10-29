import SwiftUI

struct MapSheetNavigation<Selection> {
    private(set) var selection: Selection?
    var isSheetPresented = false
    private var isAwaitingReturn = false
    private var pendingDestination: AppNavigationRoute?

    mutating func select(_ selection: Selection) {
        self.selection = selection
        isSheetPresented = true
    }

    mutating func showList() {
        clearSelection()
        isSheetPresented = true
    }

    mutating func open(_ route: AppNavigationRoute) {
        pendingDestination = route
        isSheetPresented = false
    }

    mutating func sheetDismissed() -> AppNavigationRoute? {
        if let pendingDestination {
            self.pendingDestination = nil
            isAwaitingReturn = true
            return pendingDestination
        }
        clearSelection()
        return nil
    }

    mutating func clearSelection() {
        selection = nil
        isSheetPresented = false
        isAwaitingReturn = false
        pendingDestination = nil
    }

    mutating func returnToMap() {
        guard isAwaitingReturn else { return }
        isAwaitingReturn = false
        isSheetPresented = selection != nil
    }
}

private struct MapSheetPresentationKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var isPresentedInMapSheet: Bool {
        get { self[MapSheetPresentationKey.self] }
        set { self[MapSheetPresentationKey.self] = newValue }
    }
}

struct MapSheetNavigationBackground: ViewModifier {
    @Environment(\.isPresentedInMapSheet) private var isPresentedInMapSheet

    @ViewBuilder
    func body(content: Content) -> some View {
        #if os(iOS)
        if isPresentedInMapSheet {
            content.containerBackground(.clear, for: .navigation)
        } else {
            content
        }
        #else
        content
        #endif
    }
}
