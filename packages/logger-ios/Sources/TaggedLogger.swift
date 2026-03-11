public protocol TaggedLogger {
    func debug(message: String, error: Error?, fields: [String: Any?]?)
    func info(message: String, error: Error?, fields: [String: Any?]?)
    func warn(message: String, error: Error?, fields: [String: Any?]?)
    func error(message: String, error: Error?, fields: [String: Any?]?)
    func fatal(message: String, error: Error?, fields: [String: Any?]?)
}

public extension TaggedLogger {
    func debug(message: String) {
        debug(message: message, error: nil, fields: nil)
    }

    func debug(message: String, fields: [String: Any?]) {
        debug(message: message, error: nil, fields: fields)
    }

    func debug(message: String, error: Error) {
        debug(message: message, error: error, fields: nil)
    }

    func info(message: String) {
        info(message: message, error: nil, fields: nil)
    }

    func info(message: String, fields: [String: Any?]) {
        info(message: message, error: nil, fields: fields)
    }

    func info(message: String, error: Error) {
        info(message: message, error: error, fields: nil)
    }

    func warn(message: String) {
        warn(message: message, error: nil, fields: nil)
    }

    func warn(message: String, fields: [String: Any?]) {
        warn(message: message, error: nil, fields: fields)
    }

    func warn(message: String, error: Error) {
        warn(message: message, error: error, fields: nil)
    }

    func error(message: String) {
        error(message: message, error: nil, fields: nil)
    }

    func error(message: String, fields: [String: Any?]) {
        error(message: message, error: nil, fields: fields)
    }

    func error(message: String, error: Error) {
        self.error(message: message, error: error, fields: nil)
    }

    func fatal(message: String) {
        fatal(message: message, error: nil, fields: nil)
    }

    func fatal(message: String, fields: [String: Any?]) {
        fatal(message: message, error: nil, fields: fields)
    }

    func fatal(message: String, error: Error) {
        fatal(message: message, error: error, fields: nil)
    }
}
