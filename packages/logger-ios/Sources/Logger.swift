import Foundation

public enum Logger {
    private static var runtime: LoggerRuntime?

    public static func initialize(_ config: LoggerConfig) {
        precondition(!config.storagePath.isEmpty, "storagePath must not be empty")
        runtime = LoggerRuntime(config: config)
        runtime?.taggedLogger(tag: "mLogger").info(
            message: "logger initialized",
            error: nil,
            fields: initializationConfigFields(config: config)
        )
        runtime?.taggedLogger(tag: "mLogger").info(
            message: "logger environment",
            error: nil,
            fields: initializationEnvironmentFields()
        )
    }

    public static func getLogger(_ tag: String) -> TaggedLogger {
        precondition(!tag.isEmpty, "tag must not be empty")
        guard let runtime else {
            preconditionFailure("Logger is not initialized")
        }
        return runtime.taggedLogger(tag: tag)
    }

    public static func setUserId(_ userId: String?) {
        runtime?.setUserId(userId)
    }

    public static func setSessionId(_ sessionId: String) {
        runtime?.setSessionId(sessionId)
    }

    public static func setTraceId(_ traceId: String?) {
        runtime?.setTraceId(traceId)
    }

    public static func setGlobalFields(_ fields: [String: Any?]) {
        runtime?.setGlobalFields(fields)
    }

    public static func addGlobalFields(_ fields: [String: Any?]) {
        runtime?.addGlobalFields(fields)
    }

    public static func removeGlobalFieldKeys(_ keys: Set<String>) {
        runtime?.removeGlobalFieldKeys(keys)
    }

    public static func clearGlobalFields() {
        runtime?.clearGlobalFields()
    }

    public static func flush() {
        runtime?.flush()
    }

    public static func shutdown(timeoutMs: Int = 5_000) {
        runtime?.shutdown(timeoutMs: timeoutMs)
        runtime = nil
    }

    public static func setEnabled(_ enabled: Bool) {
        runtime?.setEnabled(enabled)
    }

    public static func compressLogs(to outputPath: String, algorithm: CompressionAlgorithm = .zlib) -> Bool {
        precondition(!outputPath.isEmpty, "outputPath must not be empty")
        return runtime?.compressLogs(outputPath: outputPath, algorithm: algorithm) ?? false
    }

    public static func debug(tag: String, message: String, error: Error? = nil, fields: [String: Any?]? = nil) {
        getLogger(tag).debug(message: message, error: error, fields: fields)
    }

    public static func info(tag: String, message: String, error: Error? = nil, fields: [String: Any?]? = nil) {
        getLogger(tag).info(message: message, error: error, fields: fields)
    }

    public static func warn(tag: String, message: String, error: Error? = nil, fields: [String: Any?]? = nil) {
        getLogger(tag).warn(message: message, error: error, fields: fields)
    }

    public static func error(tag: String, message: String, error: Error? = nil, fields: [String: Any?]? = nil) {
        getLogger(tag).error(message: message, error: error, fields: fields)
    }

    public static func fatal(tag: String, message: String, error: Error? = nil, fields: [String: Any?]? = nil) {
        getLogger(tag).fatal(message: message, error: error, fields: fields)
    }

    private static func initializationConfigFields(config: LoggerConfig) -> [String: Any?] {
        [
            "storagePath": config.storagePath,
            "minLogLevel": config.minLogLevel.wireName(),
            "maxDiskBytes": config.maxDiskBytes,
            "maxSegmentBytes": config.maxSegmentBytes,
            "flushIntervalMs": config.flushIntervalMs,
            "bufferSize": config.bufferSize,
        ]
    }

    private static func initializationEnvironmentFields() -> [String: Any?] {
        var fields: [String: Any?] = [
            "platform": platformName(),
            "osVersion": ProcessInfo.processInfo.operatingSystemVersionString,
            "locale": Locale.current.identifier,
            "timezone": TimeZone.current.identifier,
        ]
        let processName = ProcessInfo.processInfo.processName
        if !processName.isEmpty {
            fields["process"] = processName
        }

        if let bundleId = Bundle.main.bundleIdentifier, !bundleId.isEmpty {
            fields["bundleId"] = bundleId
        }
        if let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
           !shortVersion.isEmpty {
            fields["appVersion"] = shortVersion
        }
        if let buildVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
           !buildVersion.isEmpty {
            fields["appBuild"] = buildVersion
        }
        if let deviceModel = deviceModelIdentifier(), !deviceModel.isEmpty {
            fields["deviceModel"] = deviceModel
        }

        return fields
    }

    private static func platformName() -> String {
        #if os(iOS)
        return "iOS"
        #elseif os(macOS)
        return "macOS"
        #elseif os(tvOS)
        return "tvOS"
        #elseif os(watchOS)
        return "watchOS"
        #else
        return "Apple"
        #endif
    }

    private static func deviceModelIdentifier() -> String? {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { ptr in
                String(validatingUTF8: ptr)
            }
        }
    }
}
