import SwiftUI

struct ArtistDetailTheme {
    let pageBackground: Color
    let descriptionSurface: Color
    let actionSurface: Color
    let eventSurface: Color
    let contentSurface: Color
    let separator: Color
    let imageBorder: Color
    let shadow: Color

    static func fallback(for colorScheme: ColorScheme) -> Self {
        let isDark = colorScheme == .dark
        return Self(
            pageBackground: Color(uiColor: .systemBackground),
            descriptionSurface: Color(uiColor: .secondarySystemBackground),
            actionSurface: Color.primary.opacity(isDark ? 0.12 : 0.08),
            eventSurface: Color(uiColor: .secondarySystemBackground),
            contentSurface: Color(uiColor: .secondarySystemBackground),
            separator: Color.primary.opacity(isDark ? 0.22 : 0.12),
            imageBorder: Color.primary.opacity(isDark ? 0.22 : 0.15),
            shadow: .black.opacity(isDark ? 0.35 : 0.18)
        )
    }
}

private struct ArtistDetailThemeKey: EnvironmentKey {
    static let defaultValue = ArtistDetailTheme.fallback(for: .light)
}

extension EnvironmentValues {
    var artistDetailTheme: ArtistDetailTheme {
        get { self[ArtistDetailThemeKey.self] }
        set { self[ArtistDetailThemeKey.self] = newValue }
    }
}

struct ArtistDetailSectionHeader: View {
    let title: LocalizedStringKey

    init(_ title: LocalizedStringKey) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
    }
}

struct ArtistDetailContentBlock<Content: View>: View {
    let content: () -> Content

    @Environment(\.artistDetailTheme) private var theme

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.contentSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(theme.separator, lineWidth: 0.5)
        )
        .shadow(color: theme.shadow, radius: 4, x: 0, y: 1)
    }
}
