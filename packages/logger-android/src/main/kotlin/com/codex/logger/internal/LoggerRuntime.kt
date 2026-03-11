package com.codex.logger.internal

import com.codex.logger.LogLevel
import com.codex.logger.LoggerConfig
import com.codex.logger.TaggedLogger
import com.codex.logger.CompressionAlgorithm
import android.os.Looper
import java.io.File
import java.util.Locale
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

internal class LoggerRuntime(private val config: LoggerConfig) {
    private val formatter = LogFormatter()
    private val fileStore = LogFileStore(config)
    private val serialExecutor = Executors.newSingleThreadExecutor()
    private val scheduler: ScheduledExecutorService = Executors.newSingleThreadScheduledExecutor()
    private val enabled = AtomicBoolean(true)
    private val buffer = mutableListOf<String>()
    private var userId: String? = null
    private var sessionId: String? = null
    private var traceId: String? = null
    private val globalFields = linkedMapOf<String, Any?>()

    init {
        scheduler.scheduleAtFixedRate(
            { flush() },
            config.flushIntervalMs,
            config.flushIntervalMs,
            TimeUnit.MILLISECONDS,
        )
    }

    fun taggedLogger(tag: String): TaggedLogger = TaggedLoggerImpl(tag)

    fun setUserId(value: String?) {
        serialExecutor.execute { userId = value }
    }

    fun setSessionId(value: String) {
        serialExecutor.execute { sessionId = value }
    }

    fun setTraceId(value: String?) {
        serialExecutor.execute { traceId = value }
    }

    fun setGlobalFields(fields: Map<String, Any?>) {
        serialExecutor.execute {
            globalFields.clear()
            globalFields.putAll(fields)
        }
    }

    fun addGlobalFields(fields: Map<String, Any?>) {
        serialExecutor.execute { globalFields.putAll(fields) }
    }

    fun removeGlobalFieldKeys(keys: Set<String>) {
        serialExecutor.execute { keys.forEach(globalFields::remove) }
    }

    fun clearGlobalFields() {
        serialExecutor.execute { globalFields.clear() }
    }

    fun flush() {
        serialExecutor.execute { flushLocked() }
    }

    fun shutdown(timeoutMs: Long) {
        flush()
        scheduler.shutdown()
        serialExecutor.shutdown()
        serialExecutor.awaitTermination(timeoutMs, TimeUnit.MILLISECONDS)
    }

    fun setEnabled(value: Boolean) {
        enabled.set(value)
    }

    fun compressLogs(outputPath: String, algorithm: CompressionAlgorithm): Boolean {
        val future = java.util.concurrent.CompletableFuture<Boolean>()
        serialExecutor.execute {
            flushLocked()
            val bytes = fileStore.readAllSegments()
            if (bytes.isEmpty()) {
                future.complete(false)
                return@execute
            }
            val compressor = when (algorithm) {
                CompressionAlgorithm.NONE -> NoopCompressor
                CompressionAlgorithm.ZLIB -> ZlibCompressor
            }
            val outputFile = File(outputPath)
            outputFile.parentFile?.mkdirs()
            outputFile.writeBytes(compressor.compress(bytes))
            future.complete(true)
        }
        return future.get(5, TimeUnit.SECONDS)
    }

    private fun append(level: LogLevel, tag: String, message: String, error: Throwable?, fields: Map<String, Any?>?) {
        if (!enabled.get() || !level.isEnabled(config.minLogLevel)) {
            return
        }

        val now = System.currentTimeMillis()
        val threadLabel = resolveThreadLabel()

        serialExecutor.execute {
            val mergedFields = linkedMapOf<String, String>()
            snapshotFields(globalFields).forEach { (key, value) -> mergedFields[key] = value }
            fields.orEmpty().forEach { (key, value) ->
                stringifyValue(value)?.let { mergedFields[key] = redact(key, it) }
            }
            userId?.let { mergedFields["userId"] = redact("userId", it) }
            sessionId?.let { mergedFields["sessionId"] = redact("sessionId", it) }
            traceId?.let { mergedFields["traceId"] = redact("traceId", it) }
            error?.let {
                val messageValue = it.message?.trim()?.takeIf(String::isNotBlank)
                mergedFields["error"] = if (messageValue != null && messageValue != "(null)") {
                    redact("errorMessage", messageValue)
                } else {
                    it::class.java.simpleName.ifBlank { "Throwable" }
                }
            }

            val record = LogRecord(
                timestampMs = now,
                level = level,
                tag = tag,
                message = redactMessage(message),
                threadLabel = threadLabel,
                fields = mergedFields,
            )
            val line = formatter.format(record)
            buffer.add(line)
            if (config.enableConsoleOutput) {
                println(line)
            }
            if (buffer.size >= config.bufferSize) {
                flushLocked()
            }
        }
    }

    private fun flushLocked() {
        if (buffer.isEmpty()) return
        val lines = buffer.toList()
        buffer.clear()
        fileStore.appendLines(lines)
    }

    private fun resolveThreadLabel(): String? {
        if (!config.enableThreadInfo) {
            return null
        }
        if (Looper.getMainLooper().thread === Thread.currentThread()) {
            return "main"
        }
        val thread = Thread.currentThread()
        return thread.name.takeIf { it.isNotBlank() } ?: thread.id.toString()
    }

    private fun snapshotFields(input: Map<String, Any?>): Map<String, String> {
        val output = linkedMapOf<String, String>()
        input.forEach { (key, value) ->
            stringifyValue(value)?.let { output[key] = redact(key, it) }
        }
        return output
    }

    private fun stringifyValue(value: Any?): String? = when (value) {
        null -> "null"
        is String -> value
        is Number -> value.toString()
        is Boolean -> value.toString()
        else -> value.toString()
    }

    private fun redact(key: String, value: String): String {
        val lower = key.lowercase(Locale.ROOT)
        if (config.redactedKeys.any { it.lowercase(Locale.ROOT) == lower }) {
            return "[REDACTED]"
        }
        return value
    }

    private fun redactMessage(value: String): String {
        var output = value
        config.redactionPatterns.forEach { regex ->
            output = regex.replace(output, "[REDACTED]")
        }
        return output
    }

    private inner class TaggedLoggerImpl(private val tag: String) : TaggedLogger {
        override fun debug(message: String, error: Throwable?, fields: Map<String, Any?>?) =
            append(LogLevel.DEBUG, tag, message, error, fields)

        override fun info(message: String, error: Throwable?, fields: Map<String, Any?>?) =
            append(LogLevel.INFO, tag, message, error, fields)

        override fun warn(message: String, error: Throwable?, fields: Map<String, Any?>?) =
            append(LogLevel.WARN, tag, message, error, fields)

        override fun error(message: String, error: Throwable?, fields: Map<String, Any?>?) =
            append(LogLevel.ERROR, tag, message, error, fields)

        override fun fatal(message: String, error: Throwable?, fields: Map<String, Any?>?) =
            append(LogLevel.FATAL, tag, message, error, fields)
    }
}
