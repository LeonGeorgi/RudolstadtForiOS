import SwiftUI

struct ArtistOverviewEmptyMessage: View {
    let emptyMessageKey: LocalizedStringKey

    init(_ emptyMessageKey: LocalizedStringKey) {
        self.emptyMessageKey = emptyMessageKey
    }

    var body: some View {
        Text(emptyMessageKey)
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
