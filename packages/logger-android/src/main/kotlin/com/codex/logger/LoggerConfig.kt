package com.codex.logger

data class LoggerConfig(
    val storagePath: String,
    val minLogLevel: LogLevel = LogLevel.INFO,
    val maxDiskBytes: Long = 20L * 1024L * 1024L,
    val maxSegmentBytes: Long = 1L * 1024L * 1024L,
    val flushIntervalMs: Long = 5_000L,
    val bufferSize: Int = 20,
    val enableConsoleOutput: Boolean = false,
    val enableThreadInfo: Boolean = true,
    val redactedKeys: Set<String> = setOf("password", "token", "authorization"),
    val redactionPatterns: List<Regex> = emptyList(),
)
