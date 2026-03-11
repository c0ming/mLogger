public enum LogLevel: Int, Sendable {
    case debug
    case info
    case warn
    case error
    case fatal

    func isEnabled(minimum: LogLevel) -> Bool {
        rawValue >= minimum.rawValue
    }

    func wireName() -> String {
        switch self {
        case .debug: return "D"
        case .info: return "I"
        case .warn: return "W"
        case .error: return "E"
        case .fatal: return "F"
        }
    }
}
