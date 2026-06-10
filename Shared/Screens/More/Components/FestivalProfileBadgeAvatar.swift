import SwiftUI

struct FestivalProfileBadgeAvatar: View {
    let badge: FestivalProfileBadge
    var diameter: CGFloat = 44
    var fontScale: CGFloat = 0.34

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
            .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
            .accessibilityLabel(Text("\(badge.displayName) badge"))
    }
}
