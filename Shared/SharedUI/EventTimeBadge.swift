import SwiftUI

struct EventTimeBadge: View {
    let event: Event

    var body: some View {
        VStack(spacing: 0) {
            Text(event.shortWeekDay.uppercased())
                .font(.caption2.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .background(.tint.opacity(0.18))

            Text(event.timeAsString)
                .font(.system(.subheadline, design: .monospaced).weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .foregroundStyle(.primary)
        .frame(width: 52, height: 52)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(.white.opacity(0.20), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
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
