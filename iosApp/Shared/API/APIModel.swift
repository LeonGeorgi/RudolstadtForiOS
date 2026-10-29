import Foundation
import RudolstadtCore

typealias APITime = NewsTime
typealias APINewsItem = NewsRecord
extension NewsTime {
    func getDate() -> Date? { timestamp?.date }
    func getDateAsGermanString() -> String? { dateText }
    func getTimeAsGermanString() -> String? { timeText }
}
extension NewsRecord {
    var id: Int { Int(recordID) }
    convenience init(
        id: Int, title: String, language: String, teaser: String, text: String, time: APITime
    ) {
        self.init(
            recordID: Int64(id), title: title, language: language, teaser: teaser, text: text,
            time: time)
    }
}
