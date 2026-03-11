import Darwin
import Foundation

final class LoggerRuntime {
    private let config: LoggerConfig
    private let formatter = LogFormatter()
    private let fileStore: LogFileStore
    private let queue = DispatchQueue(label: "com.codex.logger.runtime")
    private var timer: DispatchSourceTimer?
    private var buffer: [String] = []
    private var userId: String?
    private var sessionId: String?
    private var traceId: String?
    private var globalFields: [String: Any?] = [:]
    private var enabled = true

    init(config: LoggerConfig) {
        self.config = config
        self.fileStore = LogFileStore(config: config)
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + .milliseconds(config.flushIntervalMs), repeating: .milliseconds(config.flushIntervalMs))
        timer.setEventHandler { [weak self] in
            self?.flushLocked()
        }
        timer.resume()
        self.timer = timer
    }

    func taggedLogger(tag: String) -> TaggedLogger {
        TaggedLoggerImpl(tag: tag, runtime: self)
    }

    func setUserId(_ value: String?) {
        queue.async { self.userId = value }
    }

    func setSessionId(_ value: String) {
        queue.async { self.sessionId = value }
    }

    func setTraceId(_ value: String?) {
        queue.async { self.traceId = value }
    }

    func setGlobalFields(_ fields: [String: Any?]) {
        queue.async { self.globalFields = fields }
    }

    func addGlobalFields(_ fields: [String: Any?]) {
        queue.async {
            for (key, value) in fields {
                self.globalFields[key] = value
            }
        }
    }

    func removeGlobalFieldKeys(_ keys: Set<String>) {
        queue.async {
            for key in keys {
                self.globalFields.removeValue(forKey: key)
            }
        }
    }

    func clearGlobalFields() {
        queue.async { self.globalFields.removeAll() }
    }

    func flush() {
        queue.async { self.flushLocked() }
    }

    func shutdown(timeoutMs: Int) {
        let semaphore = DispatchSemaphore(value: 0)
        queue.async {
            self.flushLocked()
            self.timer?.cancel()
            self.timer = nil
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + .milliseconds(timeoutMs))
    }

    func setEnabled(_ value: Bool) {
        queue.async { self.enabled = value }
    }

    func compressLogs(outputPath: String, algorithm: CompressionAlgorithm) -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        var result = false
        queue.async {
            self.flushLocked()
            let bytes = self.fileStore.readAllSegments()
            guard !bytes.isEmpty else {
                semaphore.signal()
                return
            }
            let compressor: Compressor = {
                switch algorithm {
                case .none:
                    return NoopCompressor()
                case .zlib:
                    return ZlibCompressor()
                }
            }()
            let url = URL(fileURLWithPath: outputPath)
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            if let compressed = try? compressor.compress(bytes) {
                do {
                    try compressed.write(to: url)
                    result = true
                } catch {
                    result = false
                }
            }
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + .seconds(5))
        return result
    }

    fileprivate func append(level: LogLevel, tag: String, message: String, error: Error?, fields: [String: Any?]?) {
        guard level.isEnabled(minimum: config.minLogLevel) else {
            return
        }

        let threadLabel = resolveThreadLabel()
        queue.async {
            guard self.enabled else { return }
            var mergedFields = self.snapshotFields(self.globalFields)
            for (key, value) in fields ?? [:] {
                if let stringValue = self.stringify(value) {
                    mergedFields[key] = self.redact(key: key, value: stringValue)
                }
            }
            if let userId = self.userId {
                mergedFields["userId"] = self.redact(key: "userId", value: userId)
            }
            if let sessionId = self.sessionId {
                mergedFields["sessionId"] = self.redact(key: "sessionId", value: sessionId)
            }
            if let traceId = self.traceId {
                mergedFields["traceId"] = self.redact(key: "traceId", value: traceId)
            }
            if let error = error {
                let description = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                if !description.isEmpty && description != "(null)" {
                    mergedFields["error"] = self.redact(key: "errorMessage", value: description)
                } else {
                    mergedFields["error"] = String(describing: type(of: error))
                }
            }
            let record = LogRecord(
                timestamp: Date(),
                level: level,
                tag: tag,
                message: self.redactMessage(message),
                threadLabel: threadLabel,
                fields: mergedFields
            )
            let line = self.formatter.format(record)
            self.buffer.append(line)
            if self.config.enableConsoleOutput {
                print(line)
            }
            if self.buffer.count >= self.config.bufferSize {
                self.flushLocked()
            }
        }
    }

    private func flushLocked() {
        guard !buffer.isEmpty else { return }
        let lines = buffer
        buffer.removeAll(keepingCapacity: true)
        fileStore.append(lines: lines)
    }

    private func resolveThreadLabel() -> String? {
        guard config.enableThreadInfo else { return nil }
        if Thread.isMainThread {
            return "main"
        }
        let thread = Thread.current
        if let name = thread.name, !name.isEmpty {
            return name
        }
        return "\(pthread_mach_thread_np(pthread_self()))"
    }

    private func snapshotFields(_ fields: [String: Any?]) -> [String: String] {
        var output: [String: String] = [:]
        for (key, value) in fields {
            if let stringValue = stringify(value) {
                output[key] = redact(key: key, value: stringValue)
            }
        }
        return output
    }

    private func stringify(_ value: Any?) -> String? {
        guard let value else { return "null" }
        switch value {
        case let string as String:
            return string
        case let number as NSNumber:
            return number.stringValue
        case let bool as Bool:
            return bool ? "true" : "false"
        default:
            return String(describing: value)
        }
    }

    private func redact(key: String, value: String) -> String {
        if config.redactedKeys.contains(where: { $0.caseInsensitiveCompare(key) == .orderedSame }) {
            return "[REDACTED]"
        }
        return value
    }

    private func redactMessage(_ value: String) -> String {
        var output = value
        for pattern in config.redactionPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(location: 0, length: output.utf16.count)
                output = regex.stringByReplacingMatches(in: output, options: [], range: range, withTemplate: "[REDACTED]")
            }
        }
        return output
    }

}

private struct TaggedLoggerImpl: TaggedLogger {
    let tag: String
    let runtime: LoggerRuntime

    func debug(message: String, error: Error?, fields: [String: Any?]?) {
        runtime.append(level: .debug, tag: tag, message: message, error: error, fields: fields)
    }

    func info(message: String, error: Error?, fields: [String: Any?]?) {
        runtime.append(level: .info, tag: tag, message: message, error: error, fields: fields)
    }

    func warn(message: String, error: Error?, fields: [String: Any?]?) {
        runtime.append(level: .warn, tag: tag, message: message, error: error, fields: fields)
    }

    func error(message: String, error: Error?, fields: [String: Any?]?) {
        runtime.append(level: .error, tag: tag, message: message, error: error, fields: fields)
    }

    func fatal(message: String, error: Error?, fields: [String: Any?]?) {
        runtime.append(level: .fatal, tag: tag, message: message, error: error, fields: fields)
    }
}
