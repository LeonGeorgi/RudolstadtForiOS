import SwiftUI

struct StageDetailInteractiveMap: View {
    let stage: Stage

    @Environment(\.dismiss) private var dismiss
    @State private var recenterTrigger = 0

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                StageMapView(
                    stage: stage,
                    isInteractive: true,
                    recenterTrigger: recenterTrigger
                )
                .ignoresSafeArea()

                recenterButton
            }
            .navigationTitle(stage.localizedName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel(Text("Close map"))
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        StageMapView.openInMaps(stage: stage)
                    } label: {
                        Label("Open in Maps", systemImage: "map")
                    }
                }
            }
        }
    }

    private var recenterButton: some View {
        Button {
            recenterTrigger += 1
        } label: {
            Label("Locate me", systemImage: "location")
                .labelStyle(.iconOnly)
        }
        .modifier(MapLocateButtonStyle())
        .padding(.trailing, 16)
        .padding(.bottom, 24)
        .accessibilityLabel(Text("Show my location"))
    }
}

private struct MapLocateButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .buttonBorderShape(.circle)
                .buttonStyle(.glass)
                .controlSize(.large)
        } else {
            content
                .frame(width: 36, height: 36)
                .background(.ultraThinMaterial, in: Circle())
                .clipShape(Circle())
        }
    }
}
