import SwiftUI

struct ScrollableProgramViewContent: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var settings: UserSettings

    @State var scrollOffset: CGPoint
    @State private var currentTime: Date = Date()
    @State private var currentTimeUpdateTask: Task<Void, Never>?

    let timeIntervals: [Date]
    let stages: [(Stage, [EventOrGap])]
    let estimatedEventDurations: [Int: Int]?

    private let columnWidth: CGFloat = CGFloat(70)
    private let timeWidth: CGFloat = CGFloat(55)
    private let stageNameHeight: CGFloat = CGFloat(40)
    private let firstEventPadding: CGFloat = CGFloat(0)
    private let columnSpacing: CGFloat = CGFloat(5)
    private let heightPerHour: Double = 65
    private let stageHeaderCornerRadius: CGFloat = 12

    var body: some View {
        if stages.isEmpty {
            VStack {
                Spacer()

                Text("schedule.empty.description")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 20)

                Spacer()
            }
        } else {
            ZStack {
                Color(.systemBackground)
                .ignoresSafeArea()

                GeometryReader { geo in
                    ScrollView([.horizontal, .vertical]) {
                        HStack(alignment: .top, spacing: columnSpacing) {

                            Spacer()
                                .frame(width: timeWidth)

                            ForEach(stages, id: \.0.id) {
                                (stage, stageEvents) in
                                VStack(alignment: .leading, spacing: 0) {

                                    Spacer()
                                        .frame(
                                            height: stageNameHeight
                                                + firstEventPadding
                                                + heightPerHour * 0.25 + 25
                                        )

                                    renderEvents(stageEvents: stageEvents)

                                    Spacer()
                                }

                            }

                            Spacer()
                        }
                        .frame(
                            minWidth: geo.size.width,
                            minHeight: geo.size.height,
                            alignment: .topLeading
                        )
                        .background(
                            GeometryReader { proxy in
                                Color.clear.preference(
                                    key: PreferenceKey.self,
                                    value: proxy.frame(
                                        in: .named("scrollView")
                                    ).origin
                                )
                            }
                        )

                    }
                    .coordinateSpace(name: "scrollView")
                    .onPreferenceChange(PreferenceKey.self) { position in
                        self.scrollOffset = position
                    }

                    Spacer()
                        .frame(width: timeWidth)
                        .background(Color(.systemBackground))
                        .allowsHitTesting(false)
                        .zIndex(1)

                    Spacer()
                        .frame(height: stageNameHeight + 25)
                        .background(Color(.systemBackground))
                        .allowsHitTesting(false)
                        .zIndex(4)

                    VStack(alignment: .leading, spacing: 0) {
                        Spacer()
                            .frame(
                                height: stageNameHeight + firstEventPadding + 25
                            )

                        ForEach(timeIntervals, id: \.self) { time in
                            Text(dateFormatter.string(from: time))
                                .font(.system(size: 12, weight: .semibold))
                                .monospacedDigit()
                                .padding(.trailing, 8)
                                .padding(.leading, 5)
                                .frame(
                                    width: timeWidth,
                                    height: CGFloat(0.5 * heightPerHour),
                                    alignment: .trailing
                                )
                                .scaledToFill()
                                .minimumScaleFactor(0.83)
                        }
                    }
                    .allowsHitTesting(false)
                    .offset(y: scrollOffset.y)
                    .zIndex(2)

                    VStack(spacing: 0) {

                        ForEach(timeIntervals, id: \.self) { date in
                            Divider()
                                .frame(height: heightPerHour * 0.5)
                                .padding(0)
                        }
                    }
                    .padding(.top, stageNameHeight + firstEventPadding + 25)
                    .zIndex(-1)
                    .offset(y: scrollOffset.y)

                    HStack(alignment: .top, spacing: columnSpacing) {
                        Spacer()
                            .frame(width: timeWidth)
                        ForEach(stages, id: \.0.id) { (stage, _) in
                            NavigationLink(
                                value: AppNavigationRoute.stage(
                                    id: stage.id,
                                    highlightedEventId: nil
                                )
                            ) {
                                renderStage(stage)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button {
                                    StageMapView.openInMaps(stage: stage)
                                } label: {
                                    Text("schedule.context.open_in_maps")
                                    Image(systemName: "map")
                                }
                            } preview: {
                                StagePreview(stage: stage)
                            }

                        }
                        Spacer()
                    }
                    .offset(x: scrollOffset.x)
                    .zIndex(5)

                    currentTimeLinePosition().map { position in
                        HStack(alignment: .center, spacing: 0) {
                            Text(dateFormatter.string(from: currentTime))
                                .font(.system(size: 12, weight: .semibold))
                                .monospacedDigit()
                                .foregroundColor(.red)
                                .padding(.horizontal, 10)
                                .frame(
                                    width: timeWidth,
                                    height: CGFloat(0.5 * heightPerHour),
                                    alignment: .trailing
                                )
                                .scaledToFill()
                                .minimumScaleFactor(0.83)

                            Rectangle()
                                .fill(Color.red)
                                .frame(
                                    width: geo.size.width - timeWidth,
                                    height: 1
                                )
                        }
                        .frame(height: heightPerHour * 0.5)
                        .zIndex(3)
                        .offset(
                            y: position + stageNameHeight + firstEventPadding
                                + 25 + scrollOffset.y
                        )
                    }


                }
            }
            .onAppear {
                startUpdatingCurrentTime()
            }
            .onDisappear {
                currentTimeUpdateTask?.cancel()
                currentTimeUpdateTask = nil
            }
        }
    }

    func renderEvents(stageEvents: [EventOrGap]) -> some View {
        return ForEach(stageEvents.indices, id: \.self) { index in
            let eventOrGap = stageEvents[index]
            switch eventOrGap {
            case .event(let event):
                let eventDuration = estimatedEventDurations?[event.id] ?? 60
                let eventHeight = CGFloat(
                    Double(eventDuration) / 60.0 * heightPerHour
                )
                TableProgramCell(
                    width: columnWidth,
                    height: eventHeight - 2,
                    event: event
                )
                .padding(.vertical, 1)
            case .gap(let gap):
                let gapHeight = CGFloat(
                    Double(gap.duration / (60 * 60)) * heightPerHour
                )
                Spacer()
                    .frame(width: columnWidth, height: gapHeight)
            }
        }
    }

    func renderStage(_ stage: Stage) -> some View {
        return VStack(alignment: .center, spacing: 0) {
            StageNumber(
                stage: stage,
                size: 18,
                font: .system(size: 11, weight: .heavy, design: .rounded)
            )
            .padding(.top, 4)
            .padding(.bottom, 4)
            Text(stage.localizedName)
                .frame(
                    width: columnWidth - 1,
                    height: stageNameHeight,
                    alignment: .top
                )
                .font(.system(size: 10, weight: .semibold))
                .minimumScaleFactor(0.85)
                .lineLimit(3)
                .multilineTextAlignment(.center)
        }
        .frame(width: columnWidth, height: stageNameHeight + 20)
        .background(stageHeaderBackground(for: stage))
        .clipShape(
            RoundedRectangle(
                cornerRadius: stageHeaderCornerRadius,
                style: .continuous
            )
        )
    }

    func currentTimeLinePosition() -> CGFloat? {

        guard let firstTimeInterval = timeIntervals.first else { return nil }
        guard let lastTimeInterval = timeIntervals.last else { return nil }

        if currentTime < firstTimeInterval.addingTimeInterval(-30 * 60)
            || currentTime > lastTimeInterval.addingTimeInterval(30 * 60)
        {
            return nil
        }

        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: currentTime)
        let currentMinute = calendar.component(.minute, from: currentTime)
        let firstIntervalHour = calendar.component(
            .hour,
            from: firstTimeInterval
        )
        let firstIntervalMinute = calendar.component(
            .minute,
            from: firstTimeInterval
        )

        let hourDifference = currentHour - firstIntervalHour
        let minuteDifference = currentMinute - firstIntervalMinute

        let totalMinutesDifference = hourDifference * 60 + minuteDifference
        let position = CGFloat(
            Double(totalMinutesDifference) / 60.0 * heightPerHour
        )
        //print(position)
        return position
    }

    func startUpdatingCurrentTime() {
        guard currentTimeUpdateTask == nil else { return }

        currentTimeUpdateTask = Task {
            while !Task.isCancelled {
                let calendar = Calendar.current
                let components = calendar.dateComponents(
                    [.year, .month, .day, .hour, .minute],
                    from: Date().addingTimeInterval(60)
                )

                guard let nextMinute = calendar.date(from: components) else {
                    return
                }

                let interval = nextMinute.timeIntervalSince(Date())
                let sleepNanoseconds = UInt64(max(interval, 1) * 1_000_000_000)

                try? await Task.sleep(nanoseconds: sleepNanoseconds)
                if Task.isCancelled {
                    return
                }

                await MainActor.run {
                    currentTime = Date()
                }
            }
        }
    }

    func getColorForStage(_ stage: Stage) -> Color {
        switch stage.area.id {
        case 1:
            return Color.areaType1
        case 2:
            return Color.areaType2
        case 3:
            return Color.areaType3
        case 4:
            return Color.areaType4
        case 5:
            return Color.areaType5
        case 6:
            return Color.areaType6
        default:
            return Color.clear

        }
    }

    func getColorForEvent(_ event: Event) -> some View {
        switch event.artist.artistType {
        case .stage:
            if settings.savedEvents.contains(event.id) {
                return Color.artistTypeStageSaved
            } else {
                return Color.artistTypeStage
            }
        case .dance:
            if settings.savedEvents.contains(event.id) {
                return Color.artistTypeDanceSaved
            } else {
                return Color.artistTypeDance
            }
        case .street:
            if settings.savedEvents.contains(event.id) {
                return Color.artistTypeStreetSaved
            } else {
                return Color.artistTypeStreet
            }
        case .other:
            if settings.savedEvents.contains(event.id) {
                return Color.artistTypeOtherSaved
            } else {
                return Color.artistTypeOther
            }
        }
    }
}

private extension ScrollableProgramViewContent {
    @ViewBuilder
    func stageHeaderBackground(for _: Stage) -> some View {
        Rectangle()
            .fill(Color(.secondarySystemBackground))
    }
}

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    return formatter
}()

struct PreferenceKey: SwiftUI.PreferenceKey {
    static var defaultValue: CGPoint { .zero }

    static func reduce(value: inout CGPoint, nextValue: () -> CGPoint) {
        // No-op
    }
}

struct ScrollableProgramViewContent_Previews: PreviewProvider {
    static var previews: some View {
        ScrollableProgramViewContent(
            scrollOffset: .zero,
            timeIntervals: [],
            stages: [],
            estimatedEventDurations: nil
        )
        .environmentObject(UserSettings())
    }
}
