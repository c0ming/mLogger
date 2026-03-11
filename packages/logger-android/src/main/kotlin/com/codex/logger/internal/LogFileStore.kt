package com.codex.logger.internal

import com.codex.logger.LoggerConfig
import java.io.File
import java.io.RandomAccessFile
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

internal class LogFileStore(private val config: LoggerConfig) {
    private val rootDir = File(config.storagePath)
    private val fileNameFormatter = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US)

    init {
        rootDir.mkdirs()
    }

    fun appendLines(lines: List<String>) {
        if (lines.isEmpty()) return

        var current = currentSegment()
        lines.forEach { line ->
            val bytes = (line + "\n").toByteArray(Charsets.UTF_8)
            if (!current.exists()) {
                current.parentFile?.mkdirs()
                current.createNewFile()
            }
            if (current.length() + bytes.size > config.maxSegmentBytes) {
                current = nextSegment()
            }
            RandomAccessFile(current, "rw").use { file ->
                file.seek(file.length())
                file.write(bytes)
            }
        }
        trimToDiskBudget()
    }

    fun readAllSegments(): ByteArray {
        val output = java.io.ByteArrayOutputStream()
        segmentFiles().forEach { file ->
            output.write(file.readBytes())
        }
        return output.toByteArray()
    }

    private fun currentSegment(): File {
        val segments = segmentFiles()
        return segments.lastOrNull() ?: File(rootDir, segmentName(1))
    }

    private fun nextSegment(): File {
        return File(rootDir, nextSegmentName())
    }

    private fun trimToDiskBudget() {
        val segments = segmentFiles().toMutableList()
        var total = segments.sumOf { it.length() }
        while (total > config.maxDiskBytes && segments.size > 1) {
            val file = segments.removeAt(0)
            total -= file.length()
            file.delete()
        }
    }

    private fun segmentFiles(): List<File> =
        rootDir.listFiles { file -> file.isFile && file.name.startsWith("log_") && file.name.endsWith(".log") }
            ?.sortedBy { parseIndex(it.name) }
            ?: emptyList()

    private fun parseIndex(name: String): String = name

    private fun nextSegmentName(): String {
        val base = "log_${fileNameFormatter.format(Date())}"
        var candidate = "$base.log"
        var suffix = 1
        while (File(rootDir, candidate).exists()) {
            candidate = "${base}_$suffix.log"
            suffix += 1
        }
        return candidate
    }
}
