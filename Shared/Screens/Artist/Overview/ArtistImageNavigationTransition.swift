import SwiftUI

extension View {
    @ViewBuilder
    func artistImageTransitionSource(id: Int, namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, macOS 15.0, *) {
            self.matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }

    @ViewBuilder
    func artistImageNavigationTransition(id: Int, namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, macOS 15.0, *) {
            self.navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            self
        }
    }
}
