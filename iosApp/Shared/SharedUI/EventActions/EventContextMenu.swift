import SwiftUI

private struct EventContextMenu<AdditionalActions: View>: ViewModifier {
    let event: Event
    let state: EventContextPreviewState
    let onToggleSaved: () -> Void
    let additionalActions: () -> AdditionalActions

    func body(content: Content) -> some View {
        content.contextMenu {
            additionalActions()
            SaveEventButton(event: event, isSaved: state.isSaved, onToggle: onToggleSaved)
        } preview: {
            EventContextPreview(event: event, state: state)
        }
    }
}

extension View {
    func eventContextMenu(
        event: Event, state: EventContextPreviewState, onToggleSaved: @escaping () -> Void
    ) -> some View {
        modifier(
            EventContextMenu(
                event: event, state: state, onToggleSaved: onToggleSaved,
                additionalActions: { EmptyView() }))
    }

    func eventContextMenu<AdditionalActions: View>(
        event: Event, state: EventContextPreviewState, onToggleSaved: @escaping () -> Void,
        @ViewBuilder additionalActions: @escaping () -> AdditionalActions
    ) -> some View {
        modifier(
            EventContextMenu(
                event: event, state: state, onToggleSaved: onToggleSaved,
                additionalActions: additionalActions))
    }
}
