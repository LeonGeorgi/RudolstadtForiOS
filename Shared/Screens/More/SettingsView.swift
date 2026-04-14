import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: UserSettings

    var useFlames: Binding<Bool> {
        Binding(
            get: { settings.likeIcon == "flame.fill" },
            set: { newValue in
                settings.likeIcon = newValue ? "flame.fill" : "heart.fill"
            }
        )
    }

    var showAISummaries: Binding<Bool> {
        Binding(
            get: { settings.aiSummaryEnabled },
            set: { newValue in
                settings.aiSummaryEnabled = newValue
            }
        )
    }

    var body: some View {
        List {
            Toggle(isOn: showAISummaries) {
                Label("settings.show_ai_summaries", systemImage: "sparkles")
            }
            Toggle(isOn: useFlames) {
                Label("settings.use_flames", systemImage: settings.likeIcon)
            }
            if let url = URL(string: UIApplication.openSettingsURLString) {
                Button {
                    UIApplication.shared.open(url)
                } label: {
                    Label("settings.language", systemImage: "globe")
                }
            }

        }
        .font(.body)
        .listStyle(.insetGrouped)
        .navigationBarTitle("settings.title")

    }
}
