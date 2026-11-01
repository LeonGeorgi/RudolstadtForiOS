import SwiftUI

struct FestivalProfileBadgeAvatar: View {
    let badge: FestivalProfileBadge
    var diameter: CGFloat = 44
    var fontScale: CGFloat = 0.34
    var showsShadow = true

    var body: some View {
        let fillColor = Color(festivalProfileHex: badge.colorHex) ?? Color.rudolstadt

        Text(badge.initials)
            .font(.system(size: diameter * fontScale, weight: .semibold, design: .rounded))
            .foregroundStyle(
                fillColor.prefersDarkForeground
                    ? Color.black.opacity(0.78)
                    : .white
            )
            .frame(width: diameter, height: diameter)
            .background(
                Circle()
                    .fill(fillColor.gradient)
            )
            .overlay(
                Circle()
                    .strokeBorder(.white.opacity(0.34), lineWidth: 1)
            )
            .shadow(
                color: showsShadow ? .black.opacity(0.12) : .clear,
                radius: showsShadow ? 8 : 0,
                y: showsShadow ? 4 : 0
            )
            .accessibilityLabel(Text("\(badge.displayName) badge"))
    }
}
