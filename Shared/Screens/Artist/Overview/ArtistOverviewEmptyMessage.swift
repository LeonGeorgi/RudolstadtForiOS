import SwiftUI

struct ArtistOverviewEmptyMessage: View {
    let emptyMessageKey: LocalizedStringKey

    init(_ emptyMessageKey: LocalizedStringKey) {
        self.emptyMessageKey = emptyMessageKey
    }

    var body: some View {
        VStack {
            Spacer()
            Text(emptyMessageKey)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 24)
            Spacer()
        }
    }
}
