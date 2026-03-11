import Foundation

struct LogRecord {
    let timestamp: Date
    let level: LogLevel
    let tag: String
    let message: String
    let threadLabel: String?
    let fields: [String: String]
}
