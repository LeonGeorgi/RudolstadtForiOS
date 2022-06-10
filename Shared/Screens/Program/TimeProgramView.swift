import SwiftUI

struct TimeProgramView: View { // TODO: rename

    @EnvironmentObject var dataStore: DataStore
    @State private var showingSheet = false
    @State var selectedArtistTypes = Set(ArtistType.allCases)


    @State var selectedDay: Int = -1

    var eventDays: LoadingEntity<[Int]> {
        dataStore.data.map { entities in
            Set(entities.events.lazy.map { (event: Event) in
                event.festivalDay
            }).sorted(by: <)
        }
    }

    func filteredEvents(_ entities: Entities) -> [Event] {
        return entities.events.filter { event in
            selectedArtistTypes.contains(event.artist.artistType)
        }
    }

    var body: some View {
        VStack {
            if case .success(let days) = eventDays {
                Picker("Date", selection: $selectedDay) {
                    ForEach(days) { (day: Int) in
                        Text(Util.shortWeekDay(day: day)).tag(day)

                    }
                }
                        .padding(.leading, 10)
                        .padding(.trailing, 10)
                        .pickerStyle(SegmentedPickerStyle())
            }
            LoadingListView(noDataMessage: "events.empty", dataMapper: { entities in
                filteredEvents(entities)
            }) { events in
                List(events.filter {
                    $0.festivalDay == selectedDay
                }) { (event: Event) in
                    NavigationLink(destination: ArtistDetailView(
                            artist: event.artist
                    )) {
                        TimeProgramEventCell(event: event)
                    }
                }
            }
        }
                .navigationBarTitle("program_by_time.short_title", displayMode: .inline)
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
                            self.selectedDay = days.first ?? -1
                        }
                    }
                }

    }
}

struct TimeProgramView_Previews: PreviewProvider {
    static var previews: some View {
        ProgramView()
    }
}
