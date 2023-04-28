import SwiftUI

struct TableProgramCell: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var settings: UserSettings
    
    let width: CGFloat
    let height: CGFloat
    let event: Event
    
    private var isSaved: Bool {
        return settings.savedEvents.contains(event.id)
    }
    
    var body: some View {
        NavigationLink(destination: ArtistDetailView(
            artist: event.artist
        )) {
            VStack(spacing: 0) {
                if let tag = event.tag {
                    Text(tag.localizedName)
                        //.frame(maxWidth: width)
                        .font(.system(size: 8, weight: .bold))
                    
                        .foregroundColor(isSaved ? .white : .primary.opacity(colorScheme == .light ? 1 : 0.9))
                        .padding(.horizontal, 4)
                        .padding(.top, 2)
                        .textCase(.uppercase)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                    Spacer(minLength: 0)

                }
                Text(event.artist.name)
                    //.frame(maxWidth: width)
                    .font(.system(size: 12))
                    .foregroundColor(isSaved ? .white : .primary.opacity(colorScheme == .light ? 1 : 0.9))
                    .lineLimit(3)
                    //.scaledToFill()
                    .minimumScaleFactor(0.75)
                    .padding(.vertical, 2)
                if event.tag != nil {
                    Spacer(minLength: 0)
                    Spacer(minLength: 0)
                }
            }
            .frame(width: width, height: height)
            .background(getColorForEvent(event))
            .foregroundColor(.black)
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.black, lineWidth: 1)
                    .opacity(0.15)
            )
        }
        .contextMenu {
            SaveEventButton(event: event)
        }
    }
    
    func getColorForEvent(_ event: Event) -> some View {
        switch event.artist.artistType {
        case .stage:
            if (settings.savedEvents.contains(event.id)) {
                return Color.red
                    .brightness(colorScheme == .light ? 0.0 : -0)
                    .saturation(1)
            } else {
                return Color.red
                    .brightness(colorScheme == .light ? 0.5 : -0.18)
                    .saturation(colorScheme == .light ? 0.4 : 0.3)
            }
        case .dance:
            
            if (settings.savedEvents.contains(event.id)) {
                return Color.purple
                    .brightness(colorScheme == .light ? 0 : -0)
                    .saturation(1)
            } else {
                return Color.purple
                    .brightness(colorScheme == .light ? 0.5 : -0.18)
                    .saturation(colorScheme == .light ? 0.4 : 0.3)
            }
        case .street:
            if (settings.savedEvents.contains(event.id)) {
                return Color.orange
                    .brightness(colorScheme == .light ? 0 : -0)
                    .saturation(1)
            } else {
                return Color.orange
                    .brightness(colorScheme == .light ? 0.3 : -0.18)
                    .saturation(colorScheme == .light ? 0.3 : 0.3)
            }
        case .other:
            if (settings.savedEvents.contains(event.id)) {
                return Color.green
                    .brightness(colorScheme == .light ? 0 : -0)
                    .saturation(1)
            } else {
                return Color.green
                    .brightness(colorScheme == .light ? 0.4 : -0.18)
                    .saturation(colorScheme == .light ? 0.4 : 0.3)
            }
        }
    }
}


struct TableProgramCell_Previews: PreviewProvider {
    static func exampleEvent(artistType: ArtistType, id: Int, tag: Tag?) -> Event {
        return Event(
            id: id,
            dayInJuly: 5,
            timeAsString: "17:00",
            stage: .example,
            artist: Artist(
                id: 2,
                artistType: artistType,
                someNumber: 3,
                name: "Michael Jackson",
                countries: "USA",
                url: nil,
                facebookID: nil,
                youtubeID: nil,
                imageName: nil,
                descriptionGerman: nil,
                descriptionEnglish: nil
            ),
            tag: tag
        )
    }
    static func userSettings() -> UserSettings {
        let userSettings = UserSettings()
        userSettings.savedEvents = [2, 4, 6, 8]
        return userSettings
    }
    
    static func generateMainVariants(tag: Tag?) -> some View {
        
        HStack {
            let width = 60.0
            let height = 60.0
            VStack {
                TableProgramCell(width: width, height: height, event: exampleEvent(artistType: .stage, id: 1, tag: tag))
                    .environmentObject(userSettings())
                
                TableProgramCell(width: width, height: height, event: exampleEvent(artistType: .stage, id: 2, tag: tag))
                    .environmentObject(UserSettings())
                
            }
            
            VStack {
                
                
                TableProgramCell(width: width, height: height, event: exampleEvent(artistType: .dance, id: 3, tag: tag))
                    .environmentObject(UserSettings())
                
                
                
                TableProgramCell(width: width, height: height, event: exampleEvent(artistType: .dance, id: 4, tag: tag))
                    .environmentObject(UserSettings())
                
            }
            
            VStack {
                
                
                TableProgramCell(width: width, height: height, event: exampleEvent(artistType: .street, id: 5, tag: tag))
                    .environmentObject(UserSettings())
                
                
                TableProgramCell(width: width, height: height, event: exampleEvent(artistType: .street, id: 6, tag: tag))
                    .environmentObject(UserSettings())
            }
            
            VStack {
                
                
                TableProgramCell(width: width, height: height, event: exampleEvent(artistType: .other, id: 7, tag: tag))
                    .environmentObject(UserSettings())
                
                
                TableProgramCell(width: width, height: height, event: exampleEvent(artistType: .other, id: 8, tag: tag))
                    .environmentObject(UserSettings())
                
            }
        }
    }
    
    static var previews: some View {
        VStack(spacing: 50) {
            generateMainVariants(tag: nil)
            generateMainVariants(tag: .example)
        }
            .previewLayout(PreviewLayout.sizeThatFits)
    }
}

