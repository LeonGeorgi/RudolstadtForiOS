import SwiftUI

struct ScrollableProgramViewContent: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var settings: UserSettings
    
    @State var scrollOffset: CGPoint
    @State private var currentTime: Date = Date()
    
    let timeIntervals: [Date]
    let stages: [(Stage, [EventOrGap])]
    let estimatedEventDurations: Dictionary<Int, Int>?
    
    private let columnWidth: CGFloat = CGFloat(65)
    private let timeWidth: CGFloat = CGFloat(55)
    private let stageNameHeight: CGFloat = CGFloat(40)
    private let firstEventPadding: CGFloat = CGFloat(0)
    private let columnSpacing: CGFloat = CGFloat(10)
    private let heightPerHour: Double = 65
    
    
    
    var body: some View {
        ZStack {
            GeometryReader { geo in
                ScrollView([.horizontal, .vertical]) {
                    HStack(alignment: .top, spacing: columnSpacing) {
                        
                        Spacer()
                            .frame(width: timeWidth)
                        
                        ForEach(stages, id: \.0.id) { (stage, stageEvents) in
                            VStack(alignment: .leading, spacing: 0) {
                                
                                Spacer()
                                    .frame(height: stageNameHeight + firstEventPadding + heightPerHour * 0.25 + 25)
                                
                                renderEvents(stageEvents: stageEvents)
                                
                                Spacer()
                            }
                            
                        }
                        
                        Spacer()
                    }
                    .frame(minWidth: geo.size.width, minHeight: geo.size.height, alignment: .topLeading)
                    .background(GeometryReader { proxy in
                        Color.clear.preference(
                            key: PreferenceKey.self,
                            value: proxy.frame(
                                in: .named("scrollView")
                            ).origin
                        )
                    })
                    
                }
                .coordinateSpace(name: "scrollView")
                .onPreferenceChange(PreferenceKey.self) { position in
                    self.scrollOffset = position
                }
                
                
                Spacer()
                    .frame(width: timeWidth)
                    .background(.ultraThinMaterial)
                    .zIndex(1)
                
                Spacer()
                    .frame(height: stageNameHeight + 25)
                    .background(.ultraThinMaterial)
                    .zIndex(4)
                
                
                VStack(alignment: .leading, spacing: 0) {
                    Spacer()
                        .frame(height: stageNameHeight + firstEventPadding + 25)
                    
                    ForEach(timeIntervals, id: \.self) { time in
                        Text(dateFormatter.string(from: time))
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.trailing, 8)
                            .padding(.leading, 5)
                            .frame(width: timeWidth, height: CGFloat(0.5 * heightPerHour), alignment: .trailing)
                            .scaledToFill()
                            .minimumScaleFactor(0.83)
                    }
                }
                .offset(y: scrollOffset.y)
                .zIndex(2)
                
                VStack(spacing: 0) {
                    
                    ForEach(timeIntervals) { date in
                        Divider()
                            .frame(height: heightPerHour * 0.5)
                            .padding(0)
                    }
                }
                .padding(.top, stageNameHeight + firstEventPadding + 25)
                .zIndex(-1)
                .offset(y: scrollOffset.y)
                
                HStack(alignment: .top, spacing: columnSpacing / 2) {
                    Spacer()
                        .frame(width: timeWidth + columnSpacing / 2)
                    ForEach(stages, id: \.0.id) { (stage, _) in
                        NavigationLink(destination: StageDetailView(stage: stage)) {
                            VStack(alignment: .center, spacing: 0) {
                                StageNumber(stage: stage, size: 15, font: .system(size: 10, weight: .bold))
                                    .padding(.top, 5)
                                    .padding(.bottom, 5)
                                Text(stage.localizedName)
                                    .padding(.bottom, 4)
                                    .frame(width: columnWidth - 1, height: stageNameHeight, alignment: .top)
                                    .font(.system(size: 10, weight: .semibold))
                                    .minimumScaleFactor(0.85)
                                    .lineLimit(3)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .buttonStyle(.plain)
                        Divider()
                            .frame(width: 1, height: stageNameHeight + 15)
                            .padding(.vertical, 4)
                    }
                    Spacer()
                }
                .offset(x: scrollOffset.x)
                .zIndex(5)
                
                currentTimeLinePosition().map { position in
                    HStack(alignment: .center, spacing: 0) {
                        Text(dateFormatter.string(from: currentTime))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.red)
                            .padding(.horizontal, 10)
                            .frame(width: timeWidth, height: CGFloat(0.5 * heightPerHour), alignment: .trailing)
                            .scaledToFill()
                            .minimumScaleFactor(0.83)
                    
                        Rectangle()
                            .fill(Color.red)
                            .frame(width: geo.size.width - timeWidth, height: 1)
                    }
                    .frame(height: heightPerHour * 0.5)
                    .zIndex(3)
                    .offset(y: position + stageNameHeight + firstEventPadding + 25 + scrollOffset.y)
                }
                
                
                Spacer()
                    .background(Color(UIColor.systemBackground))
                    .frame(width: geo.size.width, height: geo.size.height)
                    .offset(y: geo.size.height)
                    .zIndex(6)
                
                
                
            }
        }
        .onAppear {
            startUpdatingCurrentTime()
        }
    }
    
    
    func renderEvents(stageEvents: [EventOrGap]) -> some View {
        return ForEach(stageEvents.indices, id: \.self) { index in
            let eventOrGap = stageEvents[index]
            switch eventOrGap {
            case .event(let event):
                let eventDuration = estimatedEventDurations?[event.id] ?? 60
                let eventHeight = CGFloat(Double(eventDuration) / 60.0 * heightPerHour)
                TableProgramCell(width: columnWidth, height: eventHeight, event: event)
            case .gap(let gap):
                let gapHeight = CGFloat(Double(gap.duration / (60 * 60)) * heightPerHour)
                Spacer()
                    .frame(width: columnWidth, height: gapHeight)
            }
        }
    }
    
    func currentTimeLinePosition() -> CGFloat? {
        
        guard let firstTimeInterval = timeIntervals.first else { return nil }
        guard let lastTimeInterval = timeIntervals.last else { return nil }
        
        if currentTime < firstTimeInterval.addingTimeInterval(-30 * 60) || currentTime > lastTimeInterval.addingTimeInterval(30 * 60) {
            return nil
        }
        
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: currentTime)
        let currentMinute = calendar.component(.minute, from: currentTime)
        let firstIntervalHour = calendar.component(.hour, from: firstTimeInterval)
        let firstIntervalMinute = calendar.component(.minute, from: firstTimeInterval)
        
        let hourDifference = currentHour - firstIntervalHour
        let minuteDifference = currentMinute - firstIntervalMinute
        
        let totalMinutesDifference = hourDifference * 60 + minuteDifference
        let position = CGFloat(Double(totalMinutesDifference) / 60.0 * heightPerHour)
        //print(position)
        return position
    }
    
    func startUpdatingCurrentTime() {
        let calendar = Calendar.current
        
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: Date().addingTimeInterval(60))
        let nextMinute = calendar.date(from: components)!
        let interval = nextMinute.timeIntervalSince(Date())
        DispatchQueue.main.asyncAfter(deadline: .now() + interval) {
            self.currentTime = Date()
            startUpdatingCurrentTime()
        }
    }
    
    func getColorForEvent(_ event: Event) -> some View {
        switch event.artist.artistType {
        case .stage:
            if (settings.savedEvents.contains(event.id)) {
                return Color.red
                    .brightness(colorScheme == .light ? 0.2 : -0.2)
                    .saturation(0.8)
            } else {
                return Color.red
                    .brightness(colorScheme == .light ? 0.5 : -0.5)
                    .saturation(0.4)
            }
        case .dance:
            
                if (settings.savedEvents.contains(event.id)) {
                    return Color.purple
                        .brightness(colorScheme == .light ? 0.2 : -0.2)
                        .saturation(0.6)
                } else {
                    return Color.purple
                        .brightness(colorScheme == .light ? 0.5 : -0.5)
                        .saturation(0.4)
                }
        case .street:
                if (settings.savedEvents.contains(event.id)) {
                    return Color.orange
                        .brightness(colorScheme == .light ? 0.2 : -0.2)
                        .saturation(0.6)
                } else {
                    return Color.orange
                        .brightness(colorScheme == .light ? 0.4 : -0.4)
                        .saturation(0.4)
                }
        case .other:
                if (settings.savedEvents.contains(event.id)) {
                    return Color.green
                        .brightness(colorScheme == .light ? 0.2 : -0.2)
                        .saturation(0.6)
                } else {
                    return Color.green
                        .brightness(colorScheme == .light ? 0.4 : -0.4)
                        .saturation(0.4)
                }
        }
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
        ScrollableProgramViewContent(scrollOffset: .zero, timeIntervals: [], stages: [], estimatedEventDurations: nil)
            .environmentObject(UserSettings())
    }
}

