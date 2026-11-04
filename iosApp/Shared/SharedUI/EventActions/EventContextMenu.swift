import SwiftUI
#if os(macOS)
import AppKit
#endif

struct FestivalShareButton: View {
    let url: URL
    let subject: String
    let title: LocalizedStringKey

    var body: some View {
        if #available(macOS 13.0, *) {
            ShareLink(item: url, subject: Text(subject)) {
                Label(title, systemImage: "square.and.arrow.up")
            }
        } else {
            #if os(macOS)
            Menu {
                ForEach(NSSharingService.sharingServices(forItems: [url]), id: \.self) { service in
                    Button(service.title) { service.perform(withItems: [url]) }
                }
            } label: {
                Label(title, systemImage: "square.and.arrow.up")
            }
            #endif
        }
    }
}

private struct EventContextMenu<AdditionalActions: View>: ViewModifier {
    @Environment(\.festivalEdition) private var edition
    let event: Event
    let state: EventContextPreviewState
    let onToggleSaved: () -> Void
    let additionalActions: () -> AdditionalActions

    func body(content: Content) -> some View {
        content.contextMenu {
            additionalActions()
            SaveEventButton(event: event, isSaved: state.isSaved, onToggle: onToggleSaved)
            if let url = FestivalRegistry.catalog.adapter(for: edition.identity)?.services.publicLinks.value?.url(
                for: .artist(event.artist.id, highlightedEventID: event.id)) {
                FestivalShareButton(url: url, subject: event.artist.formattedName, title: "event.share")
            }
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
