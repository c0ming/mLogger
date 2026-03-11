import Foundation
import Testing
@testable import mLogger

@Suite(.serialized)
struct mLoggerTests {
    @Test("formatter writes readable fault-analysis line")
    func formatterWritesReadableLine() {
        let formatter = LogFormatter()
        let timestamp = Date(timeIntervalSince1970: 1_710_000_000)
        let record = LogRecord(
            timestamp: timestamp,
            level: .error,
            tag: "Network",
            message: "request failed",
            threadLabel: "1234",
            fields: [
                "path": "/feed",
                "code": "500",
                "error": "timeout",
            ]
        )

        let line = formatter.format(record)

        #expect(line.contains("[E][1234][Network]: request failed"))
        #expect(line.contains("code=500, error=timeout, path=/feed") || line.contains("code=500, path=/feed, error=timeout"))
        #expect(line.contains("error=timeout"))
    }

    @Test("flush persists text line to segment file")
    func flushPersistsTextLineToSegmentFile() throws {
        let root = try makeTempRoot()
        defer { cleanup(root) }

        initializeLogger(at: root, flushIntervalMs: 60_000, bufferSize: 100, enableThreadInfo: false)

        let logger = Logger.getLogger("Network")
        logger.error(
            message: "request failed",
            error: SampleError.timeout,
            fields: [
                "path": "/feed",
                "code": 500,
            ]
        )
        Logger.flush()
        Logger.shutdown(timeoutMs: 2_000)

        let content = try readSingleSegmentContent(root: root)
        #expect(content.contains("[I][mLogger]: logger initialized"))
        #expect(content.contains("[I][mLogger]: logger environment"))
        #expect(content.contains("[E][Network]: request failed"))
        #expect(content.contains("code=500"))
        #expect(content.contains("path=/feed"))
        #expect(content.contains("error=\"The operation"))
    }

    @Test("initialize writes a visible startup log")
    func initializeWritesVisibleStartupLog() throws {
        let root = try makeTempRoot()
        defer { cleanup(root) }

        initializeLogger(at: root, flushIntervalMs: 60_000, bufferSize: 100, enableThreadInfo: false)
        Logger.flush()
        Logger.shutdown(timeoutMs: 2_000)

        let lines = try allLogLines(root: root)
        #expect(lines.contains { $0.contains("[I][mLogger]: logger initialized") && $0.contains("storagePath=") && $0.contains("minLogLevel=I") && $0.contains("maxDiskBytes=") })
        #expect(lines.contains { $0.contains("[I][mLogger]: logger environment") && $0.contains("platform=") && $0.contains("osVersion=") && $0.contains("locale=") && $0.contains("timezone=") })
    }

    @Test("redactedKeys masks sensitive field values before persistence")
    func redactedKeysMasksSensitiveFieldValuesBeforePersistence() throws {
        let root = try makeTempRoot()
        defer { cleanup(root) }

        initializeLogger(
            at: root,
            flushIntervalMs: 60_000,
            bufferSize: 100,
            enableThreadInfo: false,
            redactedKeys: ["password", "token"]
        )

        let logger = Logger.getLogger("Auth")
        logger.error(
            message: "login failed",
            error: nil,
            fields: [
                "password": "123456",
                "token": "abc123",
                "userId": "u001",
            ]
        )
        Logger.flush()
        Logger.shutdown(timeoutMs: 2_000)

        let content = try readSingleSegmentContent(root: root)
        #expect(content.contains("password=[REDACTED], token=[REDACTED], userId=u001") || content.contains("password=[REDACTED]"))
        #expect(!content.contains("password=123456"))
        #expect(!content.contains("token=abc123"))
    }

    @Test("redactedKeys matches case-insensitively")
    func redactedKeysMatchesCaseInsensitively() throws {
        let root = try makeTempRoot()
        defer { cleanup(root) }

        initializeLogger(
            at: root,
            flushIntervalMs: 60_000,
            bufferSize: 100,
            enableThreadInfo: false,
            redactedKeys: ["authorization"]
        )

        let logger = Logger.getLogger("Auth")
        logger.info(
            message: "auth failed",
            error: nil,
            fields: [
                "Authorization": "Bearer secret-token",
            ]
        )
        Logger.flush()
        Logger.shutdown(timeoutMs: 2_000)

        let content = try readSingleSegmentContent(root: root)
        #expect(content.contains("Authorization=[REDACTED]"))
        #expect(!content.contains("Bearer secret-token"))
    }

    @Test("minLogLevel filters lower severity logs")
    func minLogLevelFiltersLowerSeverityLogs() throws {
        let root = try makeTempRoot()
        defer { cleanup(root) }

        initializeLogger(
            at: root,
            minLogLevel: .error,
            flushIntervalMs: 60_000,
            bufferSize: 100,
            enableThreadInfo: false
        )

        let logger = Logger.getLogger("Network")
        logger.info(message: "request started", error: nil, fields: nil)
        Logger.flush()
        Logger.shutdown(timeoutMs: 2_000)

        #expect(segmentFiles(root: root).isEmpty)
    }

    @Test("thread info is not rendered when disabled")
    func threadInfoIsNotRenderedWhenDisabled() throws {
        let root = try makeTempRoot()
        defer { cleanup(root) }

        initializeLogger(at: root, flushIntervalMs: 60_000, bufferSize: 100, enableThreadInfo: false)

        Logger.getLogger("Network").info(message: "request started", error: nil, fields: nil)
        Logger.flush()
        Logger.shutdown(timeoutMs: 2_000)

        let content = try readSingleSegmentContent(root: root)
        #expect(!content.contains("[thread="))
    }

    @Test("thread info is rendered when enabled")
    func threadInfoIsRenderedWhenEnabled() throws {
        let root = try makeTempRoot()
        defer { cleanup(root) }

        initializeLogger(at: root, flushIntervalMs: 60_000, bufferSize: 100, enableThreadInfo: true)

        Logger.getLogger("Network").info(message: "request started", error: nil, fields: nil)
        Logger.flush()
        Logger.shutdown(timeoutMs: 2_000)

        let content = try readSingleSegmentContent(root: root)
        #expect(content.contains("["))
        #expect(content.contains("][Network]: request started"))
        #expect(!content.contains("[thread="))
    }

    @Test("main thread label is rendered without thread prefix")
    func mainThreadLabelIsRenderedWithoutThreadPrefix() throws {
        let root = try makeTempRoot()
        defer { cleanup(root) }

        initializeLogger(at: root, flushIntervalMs: 60_000, bufferSize: 100, enableThreadInfo: true)

        DispatchQueue.main.sync {
        Logger.getLogger("Thread").info(message: "main thread log")
        }
        Logger.flush()
        Logger.shutdown(timeoutMs: 2_000)

        let content = try readSingleSegmentContent(root: root)
        #expect(content.contains("[I][main][Thread]: main thread log"))
        #expect(!content.contains("[thread="))
    }

    @Test("error is formatted as a single compact field")
    func errorIsFormattedAsSingleCompactField() throws {
        let root = try makeTempRoot()
        defer { cleanup(root) }

        initializeLogger(at: root, flushIntervalMs: 60_000, bufferSize: 100, enableThreadInfo: false)

        Logger.getLogger("ViewController").info(
            message: "viewDidLoad",
            error: NSError(domain: "jdjd", code: 323),
            fields: ["sksks": "dkdk"]
        )
        Logger.flush()
        Logger.shutdown(timeoutMs: 2_000)

        let content = try readSingleSegmentContent(root: root)
        #expect(content.contains("sksks=dkdk, error=\"The operation") || content.contains("error=\"The operation"))
        #expect(content.contains("(jdjd error 323.)"))
        #expect(!content.contains("errorType="))
        #expect(!content.contains("errorMessage="))
    }

    @Test("bufferSize triggers automatic flush")
    func bufferSizeTriggersAutomaticFlush() throws {
        let root = try makeTempRoot()
        defer { cleanup(root) }

        initializeLogger(at: root, flushIntervalMs: 60_000, bufferSize: 1, enableThreadInfo: false)

        Logger.getLogger("Storage").info(message: "cache hit", error: nil, fields: nil)

        let content = try waitForSegmentContent(root: root)
        Logger.shutdown(timeoutMs: 2_000)
        #expect(content.contains("[I][Storage]: cache hit"))
    }

    @Test("flushIntervalMs triggers automatic flush")
    func flushIntervalTriggersAutomaticFlush() throws {
        let root = try makeTempRoot()
        defer { cleanup(root) }

        initializeLogger(at: root, flushIntervalMs: 50, bufferSize: 100, enableThreadInfo: false)

        Logger.getLogger("Storage").info(message: "scheduled flush", error: nil, fields: nil)

        let content = try waitForSegmentContent(root: root, timeout: 2.0)
        Logger.shutdown(timeoutMs: 2_000)
        #expect(content.contains("[I][Storage]: scheduled flush"))
    }

    @Test("maxSegmentBytes rotates to multiple segment files")
    func maxSegmentBytesRotatesToMultipleSegmentFiles() throws {
        let root = try makeTempRoot()
        defer { cleanup(root) }

        initializeLogger(
            at: root,
            maxSegmentBytes: 120,
            flushIntervalMs: 60_000,
            bufferSize: 100,
            enableThreadInfo: false
        )

        let logger = Logger.getLogger("Rotate")
        for index in 0..<8 {
            logger.info(message: "entry-\(index)-abcdefghijklmnopqrstuvwxyz", error: nil, fields: ["index": index])
        }
        Logger.flush()
        Logger.shutdown(timeoutMs: 2_000)

        #expect(segmentFiles(root: root).count > 1)
    }

    @Test("maxDiskBytes trims oldest segment files")
    func maxDiskBytesTrimsOldestSegmentFiles() throws {
        let root = try makeTempRoot()
        defer { cleanup(root) }

        let maxDiskBytes: Int64 = 260
        initializeLogger(
            at: root,
            maxDiskBytes: maxDiskBytes,
            maxSegmentBytes: 120,
            flushIntervalMs: 60_000,
            bufferSize: 100,
            enableThreadInfo: false
        )

        let logger = Logger.getLogger("Trim")
        for index in 0..<12 {
            logger.info(message: "entry-\(index)-abcdefghijklmnopqrstuvwxyz", error: nil, fields: ["index": index])
        }
        Logger.flush()
        Logger.shutdown(timeoutMs: 2_000)

        let files = segmentFiles(root: root)
        let totalBytes = files.reduce(Int64(0)) { partial, file in
            partial + ((try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0)
        }
        #expect(totalBytes <= maxDiskBytes)
        #expect(!files.contains { $0.lastPathComponent == "log_19700101_000000.log" })
    }

    @Test("setEnabled false stops persistence")
    func setEnabledFalseStopsPersistence() throws {
        let root = try makeTempRoot()
        defer { cleanup(root) }

        initializeLogger(at: root, flushIntervalMs: 60_000, bufferSize: 100, enableThreadInfo: false)

        Logger.setEnabled(false)
        Logger.getLogger("Network").error(message: "should drop", error: nil, fields: nil)
        Logger.flush()
        Logger.shutdown(timeoutMs: 2_000)

        let lines = try allLogLines(root: root)
        #expect(lines.count == 2)
        #expect(lines.contains { $0.contains("[I][mLogger]: logger initialized") })
        #expect(lines.contains { $0.contains("[I][mLogger]: logger environment") })
        #expect(!lines.contains { $0.contains("should drop") })
    }

    @Test("global and runtime fields are merged into persisted line")
    func globalAndRuntimeFieldsAreMergedIntoPersistedLine() throws {
        let root = try makeTempRoot()
        defer { cleanup(root) }

        initializeLogger(at: root, flushIntervalMs: 60_000, bufferSize: 100, enableThreadInfo: false)

        Logger.setUserId("u123")
        Logger.setSessionId("s456")
        Logger.setTraceId("t789")
        Logger.setGlobalFields(["build": "release"])
        Logger.addGlobalFields(["deviceState": "foreground"])
        Logger.getLogger("Runtime").warn(message: "merged fields", error: nil, fields: ["path": "/feed"])
        Logger.flush()
        Logger.shutdown(timeoutMs: 2_000)

        let content = try readSingleSegmentContent(root: root)
        #expect(content.contains("userId=u123"))
        #expect(content.contains("sessionId=s456"))
        #expect(content.contains("traceId=t789"))
        #expect(content.contains("build=release"))
        #expect(content.contains("deviceState=foreground"))
        #expect(content.contains("path=/feed"))
    }

    @Test("removing and clearing global fields updates subsequent logs")
    func removingAndClearingGlobalFieldsUpdatesSubsequentLogs() throws {
        let root = try makeTempRoot()
        defer { cleanup(root) }

        initializeLogger(at: root, flushIntervalMs: 60_000, bufferSize: 100, enableThreadInfo: false)

        Logger.setGlobalFields(["keep": "yes", "remove": "soon"])
        Logger.removeGlobalFieldKeys(["remove"])
        Logger.clearGlobalFields()
        Logger.getLogger("Runtime").info(message: "no globals", error: nil, fields: nil)
        Logger.flush()
        Logger.shutdown(timeoutMs: 2_000)

        let content = try readSingleSegmentContent(root: root)
        #expect(!content.contains("keep=yes"))
        #expect(!content.contains("remove=soon"))
    }

    @Test("compressLogs writes zlib-compressed export of segment content")
    func compressLogsWritesZlibCompressedExportOfSegmentContent() throws {
        let root = try makeTempRoot()
        defer { cleanup(root) }

        initializeLogger(at: root, flushIntervalMs: 60_000, bufferSize: 100, enableThreadInfo: false)

        Logger.getLogger("Export").error(
            message: "compress this",
            error: nil,
            fields: ["path": "/export"]
        )
        let output = root.appendingPathComponent("archive/export.zlib")
        let success = Logger.compressLogs(to: output.path)
        Logger.shutdown(timeoutMs: 2_000)

        #expect(success)
        let compressed = try Data(contentsOf: output)
        let restored = try decompressedZlibData(compressed)
        let content = String(decoding: restored, as: UTF8.self)
        #expect(content.contains("[E][Export]: compress this"))
        #expect(content.contains("path=/export"))
    }

    @Test("convenience static and tagged methods reduce boilerplate")
    func convenienceStaticAndTaggedMethodsReduceBoilerplate() throws {
        let root = try makeTempRoot()
        defer { cleanup(root) }

        initializeLogger(at: root, flushIntervalMs: 60_000, bufferSize: 100, enableThreadInfo: false)

        let network = Logger.getLogger("Network")
        network.info(message: "tagged convenience")
        network.error(message: "tagged fields", fields: ["path": "/feed"])
        Logger.warn(tag: "Static", message: "static convenience")
        Logger.error(tag: "Static", message: "static fields", fields: ["code": 500])
        Logger.flush()
        Logger.shutdown(timeoutMs: 2_000)

        let files = segmentFiles(root: root)
        let content = try files.reduce(into: "") { partial, file in
            partial += try String(contentsOf: file, encoding: .utf8)
        }
        #expect(content.contains("[I][Network]: tagged convenience"))
        #expect(content.contains("[E][Network]: tagged fields path=/feed"))
        #expect(content.contains("[W][Static]: static convenience"))
        #expect(content.contains("[E][Static]: static fields code=500"))
    }

    @Test("concurrent writes from multiple threads preserve all log lines")
    func concurrentWritesFromMultipleThreadsPreserveAllLogLines() throws {
        let root = try makeTempRoot()
        defer { cleanup(root) }

        initializeLogger(
            at: root,
            maxDiskBytes: 8 * 1024 * 1024,
            maxSegmentBytes: 8 * 1024 * 1024,
            flushIntervalMs: 60_000,
            bufferSize: 500,
            enableThreadInfo: false
        )

        let workerCount = 6
        let logsPerWorker = 120
        let group = DispatchGroup()
        let queue = DispatchQueue.global(qos: .userInitiated)

        for worker in 0..<workerCount {
            group.enter()
            queue.async {
                let logger = Logger.getLogger("Concurrent\(worker)")
                for index in 0..<logsPerWorker {
                    logger.info(
                        message: "worker message \(index)",
                        fields: [
                            "worker": worker,
                            "index": index,
                        ]
                    )
                }
                group.leave()
            }
        }

        group.wait()
        Logger.flush()
        Logger.shutdown(timeoutMs: 2_000)

        let lines = try allLogLines(root: root)
        let userLines = lines.filter { !$0.contains("[I][mLogger]: logger initialized") && !$0.contains("[I][mLogger]: logger environment") }
        #expect(userLines.count == workerCount * logsPerWorker)
        #expect(userLines.allSatisfy { $0.contains(": worker message ") })
        #expect(lines.allSatisfy { !$0.contains("\n") })
    }

    @Test("concurrent writes still rotate and trim within disk budget")
    func concurrentWritesStillRotateAndTrimWithinDiskBudget() throws {
        let root = try makeTempRoot()
        defer { cleanup(root) }

        let maxDiskBytes: Int64 = 12 * 1024
        initializeLogger(
            at: root,
            maxDiskBytes: maxDiskBytes,
            maxSegmentBytes: 1024,
            flushIntervalMs: 60_000,
            bufferSize: 200,
            enableThreadInfo: false
        )

        let workerCount = 4
        let logsPerWorker = 150
        let group = DispatchGroup()
        let queue = DispatchQueue.global(qos: .userInitiated)

        for worker in 0..<workerCount {
            group.enter()
            queue.async {
                let logger = Logger.getLogger("Rotate\(worker)")
                for index in 0..<logsPerWorker {
                    logger.warn(
                        message: "pressure message \(index) \(String(repeating: "x", count: 60))",
                        fields: [
                            "worker": worker,
                            "index": index,
                        ]
                    )
                }
                group.leave()
            }
        }

        group.wait()
        Logger.flush()
        Logger.shutdown(timeoutMs: 2_000)

        let files = segmentFiles(root: root)
        let totalBytes = files.reduce(Int64(0)) { partial, file in
            partial + ((try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0)
        }
        let lines = try allLogLines(root: root)

        #expect(files.count > 1)
        #expect(totalBytes <= maxDiskBytes)
        #expect(!lines.isEmpty)
        #expect(lines.allSatisfy { $0.contains("[W][Rotate") })
    }
}

private enum SampleError: Error {
    case timeout
}

private func initializeLogger(
    at root: URL,
    minLogLevel: LogLevel = .info,
    maxDiskBytes: Int64 = 20 * 1024 * 1024,
    maxSegmentBytes: Int64 = 1 * 1024 * 1024,
    flushIntervalMs: Int = 5_000,
    bufferSize: Int = 20,
    enableThreadInfo: Bool = true,
    redactedKeys: Set<String> = ["password", "token", "authorization"]
) {
    Logger.initialize(
        LoggerConfig(
            storagePath: root.path,
            minLogLevel: minLogLevel,
            maxDiskBytes: maxDiskBytes,
            maxSegmentBytes: maxSegmentBytes,
            flushIntervalMs: flushIntervalMs,
            bufferSize: bufferSize,
            enableConsoleOutput: false,
            enableThreadInfo: enableThreadInfo,
            redactedKeys: redactedKeys,
            redactionPatterns: []
        )
    )
}

private func makeTempRoot() throws -> URL {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("logger-ios-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}

private func cleanup(_ root: URL) {
    Logger.shutdown(timeoutMs: 2_000)
    try? FileManager.default.removeItem(at: root)
}

private func segmentFiles(root: URL) -> [URL] {
    let files = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
    return files
        .filter { $0.lastPathComponent.hasPrefix("log_") && $0.pathExtension == "log" }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
}

private func readSingleSegmentContent(root: URL) throws -> String {
    let files = segmentFiles(root: root)
    #expect(files.count == 1)
    return try String(contentsOf: files[0], encoding: .utf8)
}

private func waitForSegmentContent(root: URL, timeout: TimeInterval = 1.0) throws -> String {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        let files = segmentFiles(root: root)
        if let file = files.first,
           let content = try? String(contentsOf: file, encoding: .utf8),
           !content.isEmpty {
            return content
        }
        Thread.sleep(forTimeInterval: 0.02)
    }
    Issue.record("Timed out waiting for segment content")
    throw WaitTimeoutError()
}

private struct WaitTimeoutError: Error {}

private func decompressedZlibData(_ data: Data) throws -> Data {
    if #available(macOS 10.15, iOS 13.0, *) {
        return try (data as NSData).decompressed(using: .zlib) as Data
    }
    throw WaitTimeoutError()
}

private func allLogLines(root: URL) throws -> [String] {
    try segmentFiles(root: root).flatMap { file in
        let content = try String(contentsOf: file, encoding: .utf8)
        return content
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init)
    }
}
