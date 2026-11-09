import SwiftUI
import RudolstadtCore

struct FestivalProfileBadgeAvatar: View {
    let badge: FestivalProfileBadge
    var diameter: CGFloat = 44

    var body: some View {
        let rgb = ProfileColors.shared.rgb(hue: badge.hue)
        let fillColor = Color(.sRGB, red: rgb.r, green: rgb.g, blue: rgb.b, opacity: 1)

        Text(badge.initials)
            .font(.system(size: diameter * 4 / 9, weight: .medium, design: .rounded))
            .foregroundStyle(.white)
            .lineLimit(1)
            .frame(width: diameter, height: diameter)
            .background {
                Circle()
                    .fill(fillColor.gradient)
            }
            .accessibilityLabel(Text("\(badge.displayName) badge"))
    }
}
