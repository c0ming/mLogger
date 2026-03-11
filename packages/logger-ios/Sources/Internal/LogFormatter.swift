import Foundation

final class LogFormatter {
    private let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()

    func format(_ record: LogRecord) -> String {
        var line = "[\(formatter.string(from: record.timestamp))][\(record.level.wireName())]"
        if let threadLabel = record.threadLabel, !threadLabel.isEmpty {
            line += "[\(sanitize(threadLabel))]"
        }
        line += "[\(sanitize(record.tag))]"
        line += ": \(sanitize(record.message))"
        if !record.fields.isEmpty {
            let keys = record.fields.keys.sorted { lhs, rhs in
                if lhs == "error" { return false }
                if rhs == "error" { return true }
                return lhs < rhs
            }
            let suffix = keys.compactMap { key -> String? in
                guard let value = record.fields[key] else { return nil }
                return "\(sanitize(key))=\(formatFieldValue(value))"
            }.joined(separator: ", ")
            line += " \(suffix)"
        }
        return line
    }

    private func sanitize(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

    private func formatFieldValue(_ value: String) -> String {
        let sanitized = sanitize(value)
        if sanitized.contains(" ") {
            return "\"\(sanitized.replacingOccurrences(of: "\"", with: "\\\""))\""
        }
        return sanitized
    }
}
