public struct LoggerConfig: Sendable {
    public let storagePath: String
    public let minLogLevel: LogLevel
    public let maxDiskBytes: Int64
    public let maxSegmentBytes: Int64
    public let flushIntervalMs: Int
    public let bufferSize: Int
    public let enableConsoleOutput: Bool
    public let enableThreadInfo: Bool
    public let redactedKeys: Set<String>
    public let redactionPatterns: [String]

    public init(
        storagePath: String,
        minLogLevel: LogLevel = .info,
        maxDiskBytes: Int64 = 20 * 1024 * 1024,
        maxSegmentBytes: Int64 = 1 * 1024 * 1024,
        flushIntervalMs: Int = 5_000,
        bufferSize: Int = 20,
        enableConsoleOutput: Bool = false,
        enableThreadInfo: Bool = true,
        redactedKeys: Set<String> = ["password", "token", "authorization"],
        redactionPatterns: [String] = []
    ) {
        self.storagePath = storagePath
        self.minLogLevel = minLogLevel
        self.maxDiskBytes = maxDiskBytes
        self.maxSegmentBytes = maxSegmentBytes
        self.flushIntervalMs = flushIntervalMs
        self.bufferSize = bufferSize
        self.enableConsoleOutput = enableConsoleOutput
        self.enableThreadInfo = enableThreadInfo
        self.redactedKeys = redactedKeys
        self.redactionPatterns = redactionPatterns
    }
}
