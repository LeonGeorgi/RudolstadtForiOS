import SwiftUI

struct DetailHeroHeader<Tags: View>: View {
    let title: String
    let onTitleVisibilityChange: (Bool) -> Void
    let tags: Tags

    init(
        title: String,
        onTitleVisibilityChange: @escaping (Bool) -> Void,
        @ViewBuilder tags: () -> Tags
    ) {
        self.title = title
        self.onTitleVisibilityChange = onTitleVisibilityChange
        self.tags = tags()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            tags
            Text(title)
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
                .lineLimit(3)
                .accessibilityHeading(.h1)
                .onScrollVisibilityChange(threshold: 0.1) { onTitleVisibilityChange($0) }
                .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct DetailHeroScrim: View {
    var body: some View {
        LinearGradient(
            colors: [.clear, .black.opacity(0.68)], startPoint: .center, endPoint: .bottom
        )
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

struct DetailHeroIdentityFade: ViewModifier {
    let scrollOffset: CGFloat
    let heroHeight: CGFloat

    private var opacity: Double {
        guard heroHeight > 0 else { return 1 }
        let fadeStart = heroHeight * 0.25
        let fadeEnd = heroHeight * 0.70
        let progress = (scrollOffset - fadeStart) / (fadeEnd - fadeStart)
        return Double(1 - min(max(progress, 0), 1))
    }

    func body(content: Content) -> some View {
        let opacity = self.opacity
        return content
            .opacity(opacity)
            .allowsHitTesting(opacity > 0.01)
            .accessibilityHidden(opacity <= 0.01)
    }
}

struct DetailTopScrollEdgeEffect: ViewModifier {
    let isHidden: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.scrollEdgeEffectHidden(isHidden, for: .top)
        } else {
            content
        }
    }
}
