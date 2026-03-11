package com.codex.logger

import android.os.Build
import com.codex.logger.internal.LoggerRuntime
import java.util.Locale
import java.util.TimeZone

object Logger {
    @Volatile
    private var runtime: LoggerRuntime? = null

    fun initialize(config: LoggerConfig) {
        require(config.storagePath.isNotBlank()) { "storagePath must not be blank" }
        runtime = LoggerRuntime(config).also {
            it.taggedLogger("mLogger").info(
                message = "logger initialized",
                fields = initializationConfigFields(config),
            )
            it.taggedLogger("mLogger").info(
                message = "logger environment",
                fields = initializationEnvironmentFields(),
            )
        }
    }

    fun getLogger(tag: String): TaggedLogger {
        require(tag.isNotBlank()) { "tag must not be blank" }
        return checkNotNull(runtime) { "Logger is not initialized" }.taggedLogger(tag)
    }

    fun setUserId(userId: String?) {
        runtime?.setUserId(userId)
    }

    fun setSessionId(sessionId: String) {
        runtime?.setSessionId(sessionId)
    }

    fun setTraceId(traceId: String?) {
        runtime?.setTraceId(traceId)
    }

    fun setGlobalFields(fields: Map<String, Any?>) {
        runtime?.setGlobalFields(fields)
    }

    fun addGlobalFields(fields: Map<String, Any?>) {
        runtime?.addGlobalFields(fields)
    }

    fun removeGlobalFieldKeys(keys: Set<String>) {
        runtime?.removeGlobalFieldKeys(keys)
    }

    fun clearGlobalFields() {
        runtime?.clearGlobalFields()
    }

    fun flush() {
        runtime?.flush()
    }

    fun shutdown(timeoutMs: Long = 5_000) {
        runtime?.shutdown(timeoutMs)
        runtime = null
    }

    fun setEnabled(enabled: Boolean) {
        runtime?.setEnabled(enabled)
    }

    fun compressLogs(outputPath: String, algorithm: CompressionAlgorithm = CompressionAlgorithm.ZLIB): Boolean {
        require(outputPath.isNotBlank()) { "outputPath must not be blank" }
        return runtime?.compressLogs(outputPath, algorithm) ?: false
    }

    fun debug(tag: String, message: String, error: Throwable? = null, fields: Map<String, Any?>? = null) {
        getLogger(tag).debug(message, error, fields)
    }

    fun info(tag: String, message: String, error: Throwable? = null, fields: Map<String, Any?>? = null) {
        getLogger(tag).info(message, error, fields)
    }

    fun warn(tag: String, message: String, error: Throwable? = null, fields: Map<String, Any?>? = null) {
        getLogger(tag).warn(message, error, fields)
    }

    fun error(tag: String, message: String, error: Throwable? = null, fields: Map<String, Any?>? = null) {
        getLogger(tag).error(message, error, fields)
    }

    fun fatal(tag: String, message: String, error: Throwable? = null, fields: Map<String, Any?>? = null) {
        getLogger(tag).fatal(message, error, fields)
    }

    private fun initializationConfigFields(config: LoggerConfig): Map<String, Any?> = linkedMapOf(
        "storagePath" to config.storagePath,
        "minLogLevel" to config.minLogLevel.wireName(),
        "maxDiskBytes" to config.maxDiskBytes,
        "maxSegmentBytes" to config.maxSegmentBytes,
        "flushIntervalMs" to config.flushIntervalMs,
        "bufferSize" to config.bufferSize,
    )

    private fun initializationEnvironmentFields(): Map<String, Any?> = linkedMapOf(
        "platform" to "Android",
        "osVersion" to Build.VERSION.RELEASE,
        "sdkInt" to Build.VERSION.SDK_INT,
        "deviceManufacturer" to Build.MANUFACTURER,
        "deviceBrand" to Build.BRAND,
        "deviceModel" to Build.MODEL,
        "deviceName" to Build.DEVICE,
        "locale" to Locale.getDefault().toLanguageTag(),
        "timezone" to TimeZone.getDefault().id,
    )
}
