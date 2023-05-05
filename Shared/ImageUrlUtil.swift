//
// Created by Leon Georgi on 12.06.22.
//

import Foundation

class ImageUrlUtil {
    static let useApiImageUrl = false
    static let year = DataStore.year
    static let thumbUrl = getThumbUrl(year: year)
    static let fullImageUrl = getFullUrl(year: year)
    static let streetMusicThumbUrl = getStreetMusicThumbUrl(year: year)
    static let streetMusicFullUrl = getStreetMusicFullUrl(year: year)
    
    
    static func getThumbUrl(year: Int) -> String {
        
        if year >= 2023 && !useApiImageUrl {
            return "https://www.rudolstadt-festival.de/files/Bilder/\(year)/Artists/thumbs"
        }
        if year >= 2022 && !useApiImageUrl {
            return "https://www.rudolstadt-festival.de/files/Bilder/\(year)/Artists/Thumbs"
        }
        return "https://rudolstadt-festival.de/data/\(year)/images/thumbs"
    }
    
    static func getFullUrl(year: Int) -> String {
        
        if year >= 2023 && !useApiImageUrl {
            return "https://www.rudolstadt-festival.de/files/Bilder/\(year)/Artists"
        }
        if year >= 2022 && !useApiImageUrl {
            return "https://www.rudolstadt-festival.de/files/Bilder/\(year)/Artists/Thumbs"
        }
        return "https://rudolstadt-festival.de/data/\(year)/images/full"
    }
    
    static func getStreetMusicThumbUrl(year: Int) -> String {
        
        if year >= 2023 && !useApiImageUrl {
            return "https://www.rudolstadt-festival.de/files/Bilder/\(year)/Stramu/thumbs-stramu"
        }
        if year >= 2022 && !useApiImageUrl {
            return "https://www.rudolstadt-festival.de/files/Bilder/\(year)/Stramu"
        }
        return "https://rudolstadt-festival.de/data/\(year)/images/full"
    }
    
    static func getStreetMusicFullUrl(year: Int) -> String {
        
        if year >= 2023 && !useApiImageUrl {
            return "https://www.rudolstadt-festival.de/files/Bilder/\(year)/Stramu"
        }
        if year >= 2022 && !useApiImageUrl {
            return "https://www.rudolstadt-festival.de/files/Bilder/\(year)/Stramu"
        }
        return "https://rudolstadt-festival.de/data/\(year)/images/full"
    }
}
