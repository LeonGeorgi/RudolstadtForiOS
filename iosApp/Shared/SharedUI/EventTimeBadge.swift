import SwiftUI

struct EventTimeBadge: View {
    @Environment(\.festivalAccentColor) private var festivalAccentColor
    let event: Event
    var size: CGFloat = 52
    var headerColor: Color? = nil

    @ScaledMetric(relativeTo: .caption2) private var dayFontSize: CGFloat = 11
    @ScaledMetric(relativeTo: .subheadline) private var timeFontSize: CGFloat = 15

    private var scale: CGFloat { size / 52 }
    private var cornerRadius: CGFloat { size / 4 }

    var body: some View {
        VStack(spacing: 0) {
            Text(event.startDate == nil && event.knownDate == nil ? "?" : event.shortWeekDay.uppercased())
                .font(.system(size: dayFontSize * scale, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4 * scale)
                .foregroundStyle(headerColor.map { $0.prefersDarkForeground ? Color.black : .white } ?? .primary)
                .background {
                    if let headerColor {
                        headerColor.overlay(.black.opacity(0.30))
                    } else {
                        festivalAccentColor.opacity(0.18)
                    }
                }

            Group {
                if event.startDate == nil {
                    Image(systemName: "clock.badge.questionmark")
                } else {
                    Text(event.timeAsString)
                }
            }
                .font(.system(size: timeFontSize * scale, weight: .bold, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .foregroundStyle(.primary)
        .frame(width: size, height: size)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(.white.opacity(0.20), lineWidth: 0.5)
        }
        .shadow(
            color: .black.opacity(0.14),
            radius: 2,
            x: 0,
            y: 1
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(event.shortWeekDay) \(event.timeAsString)"))
    }
}

#if DEBUG
struct EventTimeBadge_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 16) {
            EventTimeBadge(event: .example)
            EventTimeBadge(event: previewEvent(dayInJuly: 4, timeAsString: "09:30"))
            EventTimeBadge(event: previewEvent(dayInJuly: 5, timeAsString: "23:45"))
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }

    private static func previewEvent(dayInJuly: Int, timeAsString: String) -> Event {
        Event(
            id: dayInJuly * 100,
            dayInJuly: dayInJuly,
            timeAsString: timeAsString,
            stage: .example,
            artist: .example,
            tag: nil
        )
    }
}
#endif
