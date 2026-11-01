import SwiftUI

/// One day's geometry, including the fixed stage bar.
struct ScheduleTimelineDayLayout {
    let hours: CGFloat
    let headerHeight: CGFloat
    let viewportHeight: CGFloat

    func bodyHeight(heightPerHour: CGFloat) -> CGFloat {
        max(hours * heightPerHour, viewportHeight - headerHeight)
    }

    func contentHeight(heightPerHour: CGFloat) -> CGFloat {
        headerHeight + bodyHeight(heightPerHour: heightPerHour)
    }

    func rescaledY(_ y: CGFloat, from oldHeight: CGFloat, to newHeight: CGFloat) -> CGFloat {
        guard y > headerHeight else { return y }
        let localY = y - headerHeight
        let oldProgram = hours * oldHeight
        if localY <= oldProgram { return headerHeight + localY * newHeight / oldHeight }
        // Empty padding below a short program is not additional concert time.
        return headerHeight
            + min(
                hours * newHeight + localY - oldProgram,
                bodyHeight(heightPerHour: newHeight))
    }
}

struct ScheduleTimelineDayPull {
    static let startDistance: CGFloat = 50
    static let progressStartDistance: CGFloat = 160
    static let activationDistance: CGFloat = 300
    enum Direction { case previous, next }

    struct Hint: Equatable {
        let direction: Direction
        let progress: CGFloat
        let opacity: CGFloat
        var isReady: Bool { progress >= 1 }

        var accessibilityHint: LocalizedStringKey {
            isReady ? "schedule.day.release" : "schedule.day.pull"
        }
    }

    private(set) var hint: Hint?
    private var isDragging = false
    private var touchY: CGFloat?
    private var edgeTouchY: CGFloat?
    private var edgeDirection: Direction?

    mutating func begin() {
        isDragging = true
        hint = nil
        edgeTouchY = nil
        edgeDirection = nil
    }

    mutating func update(
        offset: CGFloat, maximumOffset: CGFloat,
        hasPreviousDay: Bool, hasNextDay: Bool
    ) {
        guard isDragging else { return }
        let direction: Direction? =
            offset < 0 && hasPreviousDay
            ? .previous
            : offset > maximumOffset && hasNextDay ? .next : nil
        if direction != edgeDirection {
            edgeDirection = direction
            edgeTouchY = direction == nil ? nil : touchY
        }
        updateHint()
    }

    mutating func moveTouch(to y: CGFloat) {
        touchY = y
        if edgeDirection != nil, edgeTouchY == nil { edgeTouchY = y }
        updateHint()
    }

    private mutating func updateHint() {
        guard isDragging, let direction = edgeDirection, let edgeTouchY, let touchY else {
            hint = nil
            return
        }
        let distance = direction == .previous ? touchY - edgeTouchY : edgeTouchY - touchY
        let opacity = min(
            max(
                (distance - Self.startDistance) / (Self.progressStartDistance - Self.startDistance),
                0),
            1)
        let progress = min(
            max(
                (distance - Self.progressStartDistance)
                    / (Self.activationDistance - Self.progressStartDistance), 0),
            1)
        hint =
            distance > Self.startDistance
            ? Hint(direction: direction, progress: progress, opacity: opacity) : nil
    }

    mutating func end() -> Direction? {
        let direction = isDragging && hint?.isReady == true ? hint?.direction : nil
        cancel()
        return direction
    }

    mutating func cancel() {
        isDragging = false
        hint = nil
        touchY = nil
        edgeTouchY = nil
        edgeDirection = nil
    }
}

struct ScheduleTimelineDayPullHint: View {
    let hint: ScheduleTimelineDayPull.Hint
    let dayLabel: String

    var body: some View {
        VStack(spacing: 8) {
            if hint.direction == .previous { dateLabel }
            ZStack {
                Circle().stroke(.tint.opacity(0.16), lineWidth: 2.5)
                Circle().trim(from: 0, to: hint.progress)
                    .stroke(.tint, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 28, height: 28)
            .accessibilityHidden(true)
            if hint.direction == .next { dateLabel }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .fixedSize(horizontal: false, vertical: true)
        .background(.background)
        .opacity(Double(hint.opacity))
        .accessibilityElement(children: .combine)
        .accessibilityValue(
            Text(Double(hint.progress), format: .percent.precision(.fractionLength(0)))
        )
        .accessibilityHint(Text(hint.accessibilityHint))
        .allowsHitTesting(false)
    }

    private var dateLabel: some View {
        Text(dayLabel)
            .font(.footnote.weight(.medium))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
    }
}
