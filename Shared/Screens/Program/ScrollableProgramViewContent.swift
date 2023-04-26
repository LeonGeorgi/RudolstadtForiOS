import SwiftUI

struct ScrollableProgramViewContent: View {
    @State var scrollOffset: CGPoint
    let timeIntervals: [Date]
    let stages: [(Stage, [EventOrGap])]
    
    private let columnWidth: CGFloat = CGFloat(80)
    private let timeWidth: CGFloat = CGFloat(55)
    private let stageNameHeight: CGFloat = CGFloat(35)
    private let firstEventPadding: CGFloat = CGFloat(0)
    private let columnSpacing: CGFloat = CGFloat(10)
    private let heightPerHour: Double = 80
    
    
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
                                    .frame(height: stageNameHeight + firstEventPadding + heightPerHour * 0.25 + 35)
                                
                                renderEvents(stageEvents: stageEvents)
                                
                                Spacer()
                            }
                            
                        }
                        
                        Spacer()
                    }
                    .frame(minWidth: geo.size.width, minHeight: geo.size.height)
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
                    .frame(height: stageNameHeight + 35)
                    .background(.ultraThinMaterial)
                    .zIndex(3)
                
                
                VStack(alignment: .leading, spacing: 0) {
                    Spacer()
                        .frame(height: stageNameHeight + firstEventPadding + 35)
                    
                    ForEach(timeIntervals, id: \.self) { time in
                        Text(dateFormatter.string(from: time))
                            .font(.system(size: 12, weight: .semibold))
                            .frame(width: timeWidth, height: CGFloat(0.5 * heightPerHour), alignment: .leading)
                            .padding(.horizontal, 10)
                    }
                }
                .offset(y: scrollOffset.y)
                .zIndex(2)
                
                VStack(spacing: 0) {
                
                    ForEach(timeIntervals) { date in
                        Divider()
                            .frame(height: heightPerHour * 0.5)
                            .padding(0)
                    
                    /*Spacer()
                        .frame(height: heightPerHour * 0.25)
                    ForEach(timeIntervals.lazy.enumerated().filter { $0.offset % 4 == 0 }.map { $0.element }, id: \.self) { date in
                        Spacer()
                            .frame(height: heightPerHour * 1)
                            .frame(minWidth: geo.size.width)
                            .background(Color.gray)
                            .opacity(0.15)
                        
                        Spacer()
                            .frame(height: heightPerHour * 1) */
                    }
                }
                .padding(.top, stageNameHeight + firstEventPadding + 35)
                .zIndex(-1)
                .offset(y: scrollOffset.y)
                
                HStack(alignment: .top, spacing: columnSpacing) {
                    Spacer()
                        .frame(width: timeWidth)
                    ForEach(stages, id: \.0.id) { (stage, _) in
                        NavigationLink(destination: StageDetailView(stage: stage)) {
                            VStack(alignment: .center, spacing: 0) {
                                StageNumber(stage: stage, size: 20)
                                    .padding(.top, 10)
                                    .padding(.bottom, 5)
                                Text(stage.localizedName)
                                    .frame(width: columnWidth, height: stageNameHeight, alignment: .top)
                                    .font(.system(size: 12, weight: .semibold))
                                    .scaledToFill()
                                    .minimumScaleFactor(0.85)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
                .offset(x: scrollOffset.x)
                .zIndex(4)
                
            }
        }
    }
    
    
    func renderEvents(stageEvents: [EventOrGap]) -> some View {
        return ForEach(stageEvents.indices, id: \.self) { index in
            let eventOrGap = stageEvents[index]
            switch eventOrGap {
            case .event(let event):
                let eventHeight = CGFloat(Double(event.durationInMinutes / 60) * heightPerHour)
                NavigationLink(destination: ArtistDetailView(
                    artist: event.artist
                )) {
                    Text(event.artist.name)
                        .frame(width: 80, height: eventHeight)
                        .font(.system(size: 12, weight: .semibold))
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.gray, lineWidth: 1)
                                .opacity(0.3)
                        )
                }
                .contextMenu {
                    SaveEventButton(event: event)
                }
            case .gap(let gap):
                let gapHeight = CGFloat(Double(gap.duration / (60 * 60)) * heightPerHour)
                Spacer()
                    .frame(width: 80, height: gapHeight)
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
        ScrollableProgramView(events: [Event.example])
    }
}

