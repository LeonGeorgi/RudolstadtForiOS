import SwiftUI
import SDWebImage

struct SettingsView: View {
    @EnvironmentObject var settings: UserSettings
    @State private var isShowingClearCacheAlert = false
    @State private var isClearingCache = false
    @State private var isShowingCacheClearedAlert = false

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
            Button(role: .destructive) {
                isShowingClearCacheAlert = true
            } label: {
                Label("settings.clear_cache.button", systemImage: "trash")
            }
            .disabled(isClearingCache)

        }
        .font(.body)
        .listStyle(.insetGrouped)
        .navigationBarTitle("settings.title")
        .alert("settings.clear_cache.title", isPresented: $isShowingClearCacheAlert) {
            Button("settings.clear_cache.cancel", role: .cancel) {}
            Button("settings.clear_cache.confirm", role: .destructive) {
                clearCachedData()
            }
        } message: {
            Text("settings.clear_cache.message")
        }
        .alert("settings.clear_cache.done_title", isPresented: $isShowingCacheClearedAlert) {
            Button("settings.clear_cache.ok", role: .cancel) {}
        } message: {
            Text("settings.clear_cache.done_message")
        }

    }

    private func clearCachedData() {
        isClearingCache = true

        ArtistImageColorCache.shared.clearCache()
        URLCache.shared.removeAllCachedResponses()
        SDImageCache.shared.clearMemory()
        SDImageCache.shared.clearDisk {
            DispatchQueue.main.async {
                isClearingCache = false
                isShowingCacheClearedAlert = true
            }
        }
    }
}
