import Foundation

final class LogFileStore {
    private let config: LoggerConfig
    private let fileManager = FileManager.default
    private let rootDirectory: URL
    private let fileNameFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter
    }()

    init(config: LoggerConfig) {
        self.config = config
        self.rootDirectory = URL(fileURLWithPath: config.storagePath, isDirectory: true)
        try? fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
    }

    func append(lines: [String]) {
        guard !lines.isEmpty else { return }
        var current = currentSegmentURL()
        for line in lines {
            let data = Data((line + "\n").utf8)
            if !fileManager.fileExists(atPath: current.path) {
                fileManager.createFile(atPath: current.path, contents: nil)
            }
            let currentSize = (try? fileManager.attributesOfItem(atPath: current.path)[.size] as? NSNumber)?.int64Value ?? 0
            if currentSize + Int64(data.count) > config.maxSegmentBytes {
                current = nextSegmentURL()
                fileManager.createFile(atPath: current.path, contents: nil)
            }
            if let handle = try? FileHandle(forWritingTo: current) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            }
        }
        trim()
    }

    func readAllSegments() -> Data {
        let data = NSMutableData()
        for url in segmentURLs() {
            if let segmentData = try? Data(contentsOf: url) {
                data.append(segmentData)
            }
        }
        return data as Data
    }

    private func currentSegmentURL() -> URL {
        segmentURLs().last ?? rootDirectory.appendingPathComponent(nextSegmentName())
    }

    private func nextSegmentURL() -> URL {
        rootDirectory.appendingPathComponent(nextSegmentName())
    }

    private func trim() {
        var segments = segmentURLs()
        var total = segments.reduce(Int64(0)) { partial, url in
            partial + ((try? fileManager.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value ?? 0)
        }
        while total > config.maxDiskBytes && segments.count > 1 {
            let first = segments.removeFirst()
            let size = (try? fileManager.attributesOfItem(atPath: first.path)[.size] as? NSNumber)?.int64Value ?? 0
            total -= size
            try? fileManager.removeItem(at: first)
        }
    }

    private func segmentURLs() -> [URL] {
        let urls = (try? fileManager.contentsOfDirectory(at: rootDirectory, includingPropertiesForKeys: nil)) ?? []
        return urls
            .filter { $0.lastPathComponent.hasPrefix("log_") && $0.pathExtension == "log" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private func nextSegmentName() -> String {
        var candidate = "log_\(fileNameFormatter.string(from: Date())).log"
        var suffix = 1
        while fileManager.fileExists(atPath: rootDirectory.appendingPathComponent(candidate).path) {
            candidate = "log_\(fileNameFormatter.string(from: Date()))_\(suffix).log"
            suffix += 1
        }
        return candidate
    }
}
