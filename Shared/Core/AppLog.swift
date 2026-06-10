import OSLog

enum AppLog {
    private static let subsystem =
        Bundle.main.bundleIdentifier ?? "de.leongeorgi.RudolstadtForiOS"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let data = Logger(subsystem: subsystem, category: "data")
    static let news = Logger(subsystem: subsystem, category: "news")
    static let sync = Logger(subsystem: subsystem, category: "sync")
    static let commerce = Logger(subsystem: subsystem, category: "commerce")
    static let performance = Logger(subsystem: subsystem, category: "performance")
}
