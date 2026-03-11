# Mobile Logger SDK Spec

## 1. Purpose

This document defines the public SDK contract for the mobile logger SDK v1.

The scope of v1 is:

- text-based fault analysis logs
- runtime enrichment
- bounded local disk persistence
- manual and periodic flush to file

This document does not define upload behavior. Upload is intentionally out of scope for v1.

## 2. Log Format

The persisted log format is line-oriented plain text:

```text
[date][level][thread][tag]: message key1=value1, key2=value2, error="..."
```

Rules:

- `date`, `level`, `tag`, and `message` are always present.
- rendered level is a single uppercase letter: `D`, `I`, `W`, `E`, `F`
- `thread` is optional.
- Key-value fields are optional.
- If key-value fields are absent, omit the trailing field list.

Example:

```text
[2026-03-11 12:08:45.123][E][main][Network]: request failed path=/feed, method=GET, code=500, error="timeout"
```

Default on-disk file layout:

```text
{storagePath}/
  log_20260311_154800.log
  log_20260311_154805.log
```

## 3. Shared Concepts

### 3.1 LogLevel

Supported log levels:

- `debug`
- `info`
- `warn`
- `error`
- `fatal`

Severity ordering:

`debug < info < warn < error < fatal`

### 3.2 Fields

`fields` is a shallow key-value map for fault diagnosis.

Allowed value types in v1:

- string
- integer
- long
- double
- boolean
- null

Unsupported values may be stringified or dropped.

### 3.3 Error

`error` is an optional platform-native error object.

It is formatted as a single `error=...` field using platform-native readable text.

Stack trace formatting may be added later, but should not make the main line unreadable.

## 4. Initialization Contract

The SDK must be initialized before use.

### 4.1 Required fields

- `storagePath`

### 4.2 Optional fields

- `minLogLevel`
- `maxDiskBytes`
- `maxSegmentBytes`
- `flushIntervalMs`
- `bufferSize`
- `enableConsoleOutput`
- `enableThreadInfo`
- `redactedKeys`
- `redactionPatterns`

## 5. Kotlin API

### 5.1 Types

```kotlin
enum class LogLevel {
    DEBUG, INFO, WARN, ERROR, FATAL
}

data class LoggerConfig(
    val storagePath: String,
    val minLogLevel: LogLevel = LogLevel.INFO,
    val maxDiskBytes: Long = 20 * 1024 * 1024,
    val maxSegmentBytes: Long = 1 * 1024 * 1024,
    val flushIntervalMs: Long = 5_000,
    val bufferSize: Int = 20,
    val enableConsoleOutput: Boolean = false,
    val enableThreadInfo: Boolean = true,
    val redactedKeys: Set<String> = setOf("password", "token", "authorization"),
    val redactionPatterns: List<Regex> = emptyList()
)
```

### 5.2 Interface

```kotlin
object Logger {
    fun initialize(config: LoggerConfig)
    fun getLogger(tag: String): TaggedLogger
    fun setUserId(userId: String?)
    fun setSessionId(sessionId: String)
    fun setTraceId(traceId: String?)
    fun setGlobalFields(fields: Map<String, Any?>)
    fun addGlobalFields(fields: Map<String, Any?>)
    fun removeGlobalFieldKeys(keys: Set<String>)
    fun clearGlobalFields()
    fun flush()
    fun shutdown(timeoutMs: Long = 5_000)
    fun setEnabled(enabled: Boolean)
    fun compressLogs(outputPath: String, algorithm: CompressionAlgorithm = CompressionAlgorithm.ZLIB): Boolean
}

interface TaggedLogger {
    fun debug(message: String, error: Throwable? = null, fields: Map<String, Any?>? = null)
    fun info(message: String, error: Throwable? = null, fields: Map<String, Any?>? = null)
    fun warn(message: String, error: Throwable? = null, fields: Map<String, Any?>? = null)
    fun error(message: String, error: Throwable? = null, fields: Map<String, Any?>? = null)
    fun fatal(message: String, error: Throwable? = null, fields: Map<String, Any?>? = null)
}
```

## 6. Swift API

### 6.1 Types

```swift
public enum LogLevel: Int, Sendable {
    case debug
    case info
    case warn
    case error
    case fatal
}

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
}
```

### 6.2 Interface

```swift
public enum Logger {
    public static func initialize(_ config: LoggerConfig)
    public static func getLogger(_ tag: String) -> TaggedLogger
    public static func setUserId(_ userId: String?)
    public static func setSessionId(_ sessionId: String)
    public static func setTraceId(_ traceId: String?)
    public static func setGlobalFields(_ fields: [String: Any?])
    public static func addGlobalFields(_ fields: [String: Any?])
    public static func removeGlobalFieldKeys(_ keys: Set<String>)
    public static func clearGlobalFields()
    public static func flush()
    public static func shutdown(timeoutMs: Int = 5_000)
    public static func setEnabled(_ enabled: Bool)
    public static func compressLogs(to outputPath: String, algorithm: CompressionAlgorithm = .zlib) -> Bool
}

public protocol TaggedLogger {
    func debug(message: String, error: Error?, fields: [String: Any?]?)
    func info(message: String, error: Error?, fields: [String: Any?]?)
    func warn(message: String, error: Error?, fields: [String: Any?]?)
    func error(message: String, error: Error?, fields: [String: Any?]?)
    func fatal(message: String, error: Error?, fields: [String: Any?]?)
}
```

## 7. Internal Compression Hook

Compression is available as a local export API.

Public shape:

```text
Logger.compressLogs(outputPath, algorithm)
algorithm -> "zlib" | "none"
```
