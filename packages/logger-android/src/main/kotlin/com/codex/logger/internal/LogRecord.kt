package com.codex.logger.internal

import com.codex.logger.LogLevel

internal data class LogRecord(
    val timestampMs: Long,
    val level: LogLevel,
    val tag: String,
    val message: String,
    val threadLabel: String?,
    val fields: Map<String, String>,
)
