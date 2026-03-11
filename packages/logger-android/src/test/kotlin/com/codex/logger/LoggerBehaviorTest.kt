package com.codex.logger

import java.io.File
import java.util.zip.InflaterInputStream
import java.util.UUID
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assert.assertEquals
import org.junit.Test

class LoggerBehaviorTest {
    @Test
    fun redactedKeysMaskSensitiveFieldValuesBeforePersistence() {
        withLoggerRoot { root ->
            initializeLogger(root, redactedKeys = setOf("password", "token"))

            val logger = Logger.getLogger("Auth")
            logger.error(
                message = "login failed",
                fields = mapOf(
                    "password" to "123456",
                    "token" to "abc123",
                    "userId" to "u001",
                ),
            )
            Logger.flush()
            Logger.shutdown()

            val content = readSingleSegmentContent(root)
            assertTrue(content.contains("password=[REDACTED]"))
            assertTrue(content.contains("token=[REDACTED]"))
            assertTrue(content.contains("userId=u001"))
            assertFalse(content.contains("password=123456"))
            assertFalse(content.contains("token=abc123"))
        }
    }

    @Test
    fun redactedKeysMatchCaseInsensitively() {
        withLoggerRoot { root ->
            initializeLogger(root, redactedKeys = setOf("authorization"))

            Logger.getLogger("Auth").info(
                message = "auth failed",
                fields = mapOf("Authorization" to "Bearer secret-token"),
            )
            Logger.flush()
            Logger.shutdown()

            val content = readSingleSegmentContent(root)
            assertTrue(content.contains("Authorization=[REDACTED]"))
            assertFalse(content.contains("Bearer secret-token"))
        }
    }

    @Test
    fun minLogLevelFiltersLowerSeverityLogs() {
        withLoggerRoot { root ->
            initializeLogger(root, minLogLevel = LogLevel.ERROR)

            Logger.getLogger("Network").info(message = "request started")
            Logger.flush()
            Logger.shutdown()

            assertTrue(segmentFiles(root).isEmpty())
        }
    }

    @Test
    fun enableThreadInfoFalseOmitsThreadSegment() {
        withLoggerRoot { root ->
            initializeLogger(root, enableThreadInfo = false)

            Logger.getLogger("Network").info(message = "request started")
            Logger.flush()
            Logger.shutdown()

            val content = readSingleSegmentContent(root)
            assertFalse(content.contains("[thread="))
        }
    }

    @Test
    fun enableThreadInfoTrueIncludesThreadSegment() {
        withLoggerRoot { root ->
            initializeLogger(root, enableThreadInfo = true)

            Logger.getLogger("Network").info(message = "request started")
            Logger.flush()
            Logger.shutdown()

            val content = readSingleSegmentContent(root)
            assertTrue(content.contains("][Network]: request started"))
            assertFalse(content.contains("[thread="))
        }
    }

    @Test
    fun bufferSizeTriggersAutomaticFlush() {
        withLoggerRoot { root ->
            initializeLogger(root, bufferSize = 1, enableThreadInfo = false)

            Logger.getLogger("Storage").info(message = "cache hit")

            val content = waitForSegmentContent(root)
            Logger.shutdown()
            assertTrue(content.contains("[I][Storage]: cache hit"))
        }
    }

    @Test
    fun flushIntervalTriggersAutomaticFlush() {
        withLoggerRoot { root ->
            initializeLogger(root, flushIntervalMs = 50, enableThreadInfo = false)

            Logger.getLogger("Storage").info(message = "scheduled flush")

            val content = waitForSegmentContent(root)
            Logger.shutdown()
            assertTrue(content.contains("[I][Storage]: scheduled flush"))
        }
    }

    @Test
    fun maxSegmentBytesRotatesToMultipleSegmentFiles() {
        withLoggerRoot { root ->
            initializeLogger(root, maxSegmentBytes = 120, enableThreadInfo = false)

            val logger = Logger.getLogger("Rotate")
            repeat(8) { index ->
                logger.info(
                    message = "entry-$index-abcdefghijklmnopqrstuvwxyz",
                    fields = mapOf("index" to index),
                )
            }
            Logger.flush()
            Logger.shutdown()

            assertTrue(segmentFiles(root).size > 1)
        }
    }

    @Test
    fun maxDiskBytesTrimsOldestSegmentFiles() {
        withLoggerRoot { root ->
            val maxDiskBytes = 260L
            initializeLogger(root, maxDiskBytes = maxDiskBytes, maxSegmentBytes = 120, enableThreadInfo = false)

            val logger = Logger.getLogger("Trim")
            repeat(12) { index ->
                logger.info(
                    message = "entry-$index-abcdefghijklmnopqrstuvwxyz",
                    fields = mapOf("index" to index),
                )
            }
            Logger.flush()
            Logger.shutdown()

            val files = segmentFiles(root)
            val totalBytes = files.sumOf { it.length() }
            assertTrue(totalBytes <= maxDiskBytes)
            assertFalse(files.any { it.name == "log_19700101_000000.log" })
        }
    }

    @Test
    fun setEnabledFalseStopsPersistence() {
        withLoggerRoot { root ->
            initializeLogger(root, enableThreadInfo = false)

            Logger.setEnabled(false)
            Logger.getLogger("Network").error(message = "should drop")
            Logger.flush()
            Logger.shutdown()

            val lines = allLogLines(root)
            assertEquals(2, lines.size)
            assertTrue(lines.all { it.contains("[I][mLogger]: logger ") })
        }
    }

    @Test
    fun globalAndRuntimeFieldsAreMergedIntoPersistedLine() {
        withLoggerRoot { root ->
            initializeLogger(root, enableThreadInfo = false)

            Logger.setUserId("u123")
            Logger.setSessionId("s456")
            Logger.setTraceId("t789")
            Logger.setGlobalFields(mapOf("build" to "release"))
            Logger.addGlobalFields(mapOf("deviceState" to "foreground"))
            Logger.getLogger("Runtime").warn(message = "merged fields", fields = mapOf("path" to "/feed"))
            Logger.flush()
            Logger.shutdown()

            val content = readSingleSegmentContent(root)
            assertTrue(content.contains("userId=u123"))
            assertTrue(content.contains("sessionId=s456"))
            assertTrue(content.contains("traceId=t789"))
            assertTrue(content.contains("build=release"))
            assertTrue(content.contains("deviceState=foreground"))
            assertTrue(content.contains("path=/feed"))
        }
    }

    @Test
    fun removingAndClearingGlobalFieldsUpdatesSubsequentLogs() {
        withLoggerRoot { root ->
            initializeLogger(root, enableThreadInfo = false)

            Logger.setGlobalFields(mapOf("keep" to "yes", "remove" to "soon"))
            Logger.removeGlobalFieldKeys(setOf("remove"))
            Logger.clearGlobalFields()
            Logger.getLogger("Runtime").info(message = "no globals")
            Logger.flush()
            Logger.shutdown()

            val content = readSingleSegmentContent(root)
            assertFalse(content.contains("keep=yes"))
            assertFalse(content.contains("remove=soon"))
        }
    }

    @Test
    fun compressLogsWritesZlibCompressedExportOfSegmentContent() {
        withLoggerRoot { root ->
            initializeLogger(root, enableThreadInfo = false)

            Logger.getLogger("Export").error(message = "compress this", fields = mapOf("path" to "/export"))
            val output = File(root, "archive/export.zlib")
            val success = Logger.compressLogs(output.absolutePath)
            Logger.shutdown()

            assertTrue(success)
            val restored = InflaterInputStream(output.inputStream()).bufferedReader().readText()
            assertTrue(restored.contains("[E][Export]: compress this"))
            assertTrue(restored.contains("path=/export"))
        }
    }

    @Test
    fun concurrentWritesFromMultipleThreadsPreserveAllLogLines() {
        withLoggerRoot { root ->
            initializeLogger(
                root,
                maxDiskBytes = 8L * 1024L * 1024L,
                maxSegmentBytes = 8L * 1024L * 1024L,
                flushIntervalMs = 60_000L,
                bufferSize = 500,
                enableThreadInfo = false,
            )

            val workerCount = 6
            val logsPerWorker = 120
            val executor = Executors.newFixedThreadPool(workerCount)
            val latch = CountDownLatch(workerCount)

            repeat(workerCount) { worker ->
                executor.execute {
                    val logger = Logger.getLogger("Concurrent$worker")
                    repeat(logsPerWorker) { index ->
                        logger.info(
                            message = "worker message $index",
                            fields = mapOf(
                                "worker" to worker,
                                "index" to index,
                            ),
                        )
                    }
                    latch.countDown()
                }
            }

            latch.await()
            executor.shutdown()
            Logger.flush()
            Logger.shutdown()

            val lines = allLogLines(root)
            val userLines = lines.filterNot { it.contains("[mLogger]: logger initialized") || it.contains("[mLogger]: logger environment") }
            assertEquals(workerCount * logsPerWorker, userLines.size)
            assertTrue(userLines.all { it.contains(": worker message ") })
        }
    }

    @Test
    fun concurrentWritesStillRotateAndTrimWithinDiskBudget() {
        withLoggerRoot { root ->
            val maxDiskBytes = 12L * 1024L
            initializeLogger(
                root,
                maxDiskBytes = maxDiskBytes,
                maxSegmentBytes = 1024,
                flushIntervalMs = 60_000L,
                bufferSize = 200,
                enableThreadInfo = false,
            )

            val workerCount = 4
            val logsPerWorker = 150
            val executor = Executors.newFixedThreadPool(workerCount)
            val latch = CountDownLatch(workerCount)

            repeat(workerCount) { worker ->
                executor.execute {
                    val logger = Logger.getLogger("Rotate$worker")
                    repeat(logsPerWorker) { index ->
                        logger.warn(
                            message = "pressure message $index ${"x".repeat(60)}",
                            fields = mapOf(
                                "worker" to worker,
                                "index" to index,
                            ),
                        )
                    }
                    latch.countDown()
                }
            }

            latch.await()
            executor.shutdown()
            Logger.flush()
            Logger.shutdown()

            val files = segmentFiles(root)
            val totalBytes = files.sumOf { it.length() }
            val lines = allLogLines(root).filterNot {
                it.contains("[mLogger]: logger initialized") || it.contains("[mLogger]: logger environment")
            }

            assertTrue(files.size > 1)
            assertTrue(totalBytes <= maxDiskBytes)
            assertTrue(lines.isNotEmpty())
            assertTrue(lines.all { it.contains("[W][Rotate") })
        }
    }
}

private fun initializeLogger(
    root: File,
    minLogLevel: LogLevel = LogLevel.INFO,
    maxDiskBytes: Long = 20L * 1024L * 1024L,
    maxSegmentBytes: Long = 1L * 1024L * 1024L,
    flushIntervalMs: Long = 60_000L,
    bufferSize: Int = 100,
    enableThreadInfo: Boolean = true,
    redactedKeys: Set<String> = setOf("password", "token", "authorization"),
) {
    Logger.initialize(
        LoggerConfig(
            storagePath = root.absolutePath,
            minLogLevel = minLogLevel,
            maxDiskBytes = maxDiskBytes,
            maxSegmentBytes = maxSegmentBytes,
            flushIntervalMs = flushIntervalMs,
            bufferSize = bufferSize,
            enableConsoleOutput = false,
            enableThreadInfo = enableThreadInfo,
            redactedKeys = redactedKeys,
            redactionPatterns = emptyList(),
        )
    )
}

private fun withLoggerRoot(block: (File) -> Unit) {
    val root = File(System.getProperty("java.io.tmpdir"), "logger-android-tests-${UUID.randomUUID()}")
    root.mkdirs()
    try {
        block(root)
    } finally {
        Logger.shutdown()
        root.deleteRecursively()
    }
}

private fun segmentFiles(root: File): List<File> =
    root
        .listFiles()
        .orEmpty()
        .filter { it.name.startsWith("log_") && it.name.endsWith(".log") }
        .sortedBy { it.name }

private fun readSingleSegmentContent(root: File): String {
    val files = segmentFiles(root)
    assertTrue(files.size == 1)
    return files.first().readText()
}

private fun waitForSegmentContent(root: File, timeoutMs: Long = 2_000L): String {
    val deadline = System.currentTimeMillis() + timeoutMs
    while (System.currentTimeMillis() < deadline) {
        val file = segmentFiles(root).firstOrNull()
        if (file != null) {
            val content = file.readText()
            if (content.isNotEmpty()) {
                return content
            }
        }
        Thread.sleep(20)
    }
    throw AssertionError("Timed out waiting for segment content")
}

private fun allLogLines(root: File): List<String> =
    segmentFiles(root)
        .flatMap { file ->
            file.readLines().filter { it.isNotBlank() }
        }
