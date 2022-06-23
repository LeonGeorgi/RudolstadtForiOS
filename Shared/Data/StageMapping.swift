//
//  StageMapping.swift
//  RudolstadtForiOS (iOS)
//
//  Created by Leon Georgi on 23.06.22.
//

import Foundation

class StageMapping {

    static let numberMapping: Dictionary<String, Int> = [
        "Große Bühne Heinepark": 1,
        "Konzertbühne": 2,
        "Tanzzelt": 3,
        "Bühne Bauernhäuser": 4,
        "Kinderfest": 5,
        "Große Bühne Markt": 6,
        "Marktplatz": 7,
        "Hof Markt 8": 8,
        "Podium Neumarkt": 9,
        "Handwerkerhof": 10,
        "Am Güntherbrunnen": 11,
        "Schillerhaus": 12,
        "Weinbergstraße 4": 13,
        "Weinbergstraße 6": 14,
        "Schlossstraße 25": 15,
        "Freiligrathstraße": 16,
        "Schulplatz": 17,
        "Hof der Superintendentur": 18,
        "Stadtkirche": 19,
        "Gemeindesaal": 20,
        "Bibliothek": 21,
        "Altes Rathaus": 22,
        "Löwensaal": 23,
        "Theater im Stadthaus": 24,
        "Schminkkasten": 25,
        "saalgärten": 26,
        "Schallhaus": 27,
        "Burgterrasse": 28,
        "Große Bühne Heidecksburg": 29,
        "Instrumentenbauzentrum": 30,
        "KulTourDiele": 31,
        "Folkbude": 32,
        "Tourist-Information": 33,
        // "Gewölbehalle in der Heidecksburg": nil,
        // "Säulensäle": nil,
        // "Rast im Park": nil,
    ]

    static let areaMapping: Dictionary<String, [Int]> = [
        "Heinepark (City Park)": [1, 2, 3, 4, 5],
        "Innenstadt (Inner City)": [6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18],
        "Drinnen (Indoor)": [19, 20, 21, 22, 23, 24, 25, 26],
        "Heidecksburg (Castle)": [27, 28, 29],
        "Sonstige (Others)": [30, 31, 32, 33],
    ]
}