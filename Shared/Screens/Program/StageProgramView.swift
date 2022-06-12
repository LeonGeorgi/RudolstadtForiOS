import SwiftUI

struct StageProgramView: View {

    @EnvironmentObject var dataStore: DataStore

    @State private var showingSheet = false
    @State var selectedArtistTypes = Set(ArtistType.allCases)


    func filteredEvents(_ entities: Entities) -> [Event] {
        entities.events.filter { event in
            selectedArtistTypes.contains(event.artist.artistType)
        }
    }

    @State var selectedDay: Int = -1

    var events: LoadingEntity<Dictionary<Int, [StageEvents]>> {
        dataStore.data.map { entities in
            var result: Dictionary<Int, Dictionary<Stage, [Event]>> = Dictionary()
            for event in filteredEvents(entities) {
                if !result.keys.contains(event.festivalDay) {
                    result[event.festivalDay] = Dictionary()
                }
                if !result[event.festivalDay]!.keys.contains(event.stage) {
                    result[event.festivalDay]![event.stage] = []
                }
                result[event.festivalDay]![event.stage]!.append(event)
            }
            return result.mapValues { dictionary in
                sortStages(Array(dictionary.map { stage, events in
                    StageEvents(stage: stage, events: events)
                }))
            }
        }
    }

    var eventDays: LoadingEntity<[Int]> {
        dataStore.data.map { entities in
            return Set(entities.events.lazy.map { (event: Event) in
                event.festivalDay
            }).sorted(by: <)
        }
    }

    func sortStages(_ stages: [StageEvents]) -> [StageEvents] {
        return stages.sorted { (first: StageEvents, second: StageEvents) in
                    first.stage.id < second.stage.id
                }
                .sorted { (first: StageEvents, second: StageEvents) in
                    first.stage.area.id < second.stage.area.id
                }
    }

    var body: some View {
        VStack {
            if case .success(let days) = eventDays {
                Picker("Date", selection: $selectedDay) {
                    ForEach(days) { (day: Int) in
                        Text(Util.shortWeekDay(day: day)).tag(day)

                    }
                }.padding(.leading, 10)
                        .padding(.trailing, 10)
                        .pickerStyle(SegmentedPickerStyle())
            }
            switch events {
                case .loading:
                    Text("events.loading") // TODO: translate
                case .failure(let reason):
                    Text("Failed to load: " + reason.rawValue)
                case .success(let events):
                if events[selectedDay] == nil {
                    Spacer()
                    Text("filter.no_events_available")
                            .foregroundColor(.secondary)
                    Spacer()
                } else {
                    List {
                        ForEach(events[selectedDay] ?? []) { (item: StageEvents) in
                            Section(header: Text("\(item.stage.localizedName)")) {
                                ForEach(item.events) { (event: Event) in
                                    NavigationLink(destination: ArtistDetailView(
                                            artist: event.artist
                                    )) {
                                        StageProgramEventCell(event: event)
                                    }
                                }
                            }
                        }
                    }.listStyle(.grouped)
                }
            }
        }.navigationBarTitle("program_by_stage.short_title", displayMode: .inline)

                .navigationBarItems(trailing: Button(action: {
                    self.showingSheet = true
                }) {
                    Text("filter.button")
                })
                .sheet(isPresented: $showingSheet) {
                    NavigationView {
                        ArtistTypeFilterView(selectedArtistTypes: self.$selectedArtistTypes)
                                .navigationBarItems(trailing: Button(action: { self.showingSheet = false }) {
                                    Text("filter.done")
                                })
                    }
                }
                .onAppear {
                    if case .success(let days) = eventDays {
                        if self.selectedDay == -1 {
                            self.selectedDay = Util.getCurrentFestivalDay(eventDays: days) ?? days.first ?? -1
                        }
                    }
                }

    }
}

struct StageEvents: Identifiable {
    var id: Int {
        stage.id // TODO
    }

    let stage: Stage
    let events: [Event]
}

extension Date: Identifiable {
    public var id: Int {
        self.hashValue
    }
}

struct StageProgramView_Previews: PreviewProvider {
    static var previews: some View {
        StageProgramView()
    }
}
