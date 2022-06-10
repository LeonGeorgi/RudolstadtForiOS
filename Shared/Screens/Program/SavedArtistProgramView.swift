import SwiftUI

struct SavedArtistProgramView: View {

    @EnvironmentObject var dataStore: DataStore
    @EnvironmentObject var settings: UserSettings

    func filteredEvents(_ entities: Entities) -> [Event] {
        let ratedArtistIds = settings.ratings.filter { entry in
                    entry.value > 0
                }.map { (entry) in
                    Int(entry.key)!
                }
        return entities.events.filter { event in
            ratedArtistIds.contains(event.artist.id)
        }
    }

    @State var selectedDay: Int = -1

    var eventDays: LoadingEntity<[Int]> {
        dataStore.data.map { entities in
            return Set(entities.events.lazy.map { (event: Event) in
                event.festivalDay
            }).sorted(by: <)
        }
    }

    var body: some View {
        VStack {
            Picker("Date", selection: $selectedDay) {
                switch eventDays {
                case .loading:
                    Text("program.days.loading") // TODO: translate
                case .failure(let reason):
                    Text("Failed to load: " + reason.rawValue)
                case .success(let days):
                    ForEach(days) { (day: Int) in
                        Text(Util.shortWeekDay(day: day)).tag(day)
                    }
                }
            }.padding(.leading, 10)
                    .padding(.trailing, 10)
                    .pickerStyle(SegmentedPickerStyle())
            LoadingListView(noDataMessage: "program.empty", dataMapper: { entities in
                filteredEvents(entities)
            }) { events in
                List(events.filter {
                    $0.festivalDay == selectedDay
                }) { (event: Event) in
                    NavigationLink(destination: ArtistDetailView(
                            artist: event.artist
                    )) {
                        SavedArtistEventCell(event: event)
                    }
                }
            }
            
        }.onAppear {
                    if self.selectedDay == -1 {
                        if case .success(let eventDays) = self.eventDays {
                            self.selectedDay = eventDays.first ?? -1
                        }
                    }
                }

    }
}

struct SavedArtistProgramView_Previews: PreviewProvider {
    static var previews: some View {
        StageProgramView()
    }
}
