package com.codex.logger.internal

import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

internal class LogFormatter {
    private val dateFormat = SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", Locale.US).apply {
        timeZone = TimeZone.getDefault()
    }

    fun format(record: LogRecord): String {
        val builder = StringBuilder()
        builder.append('[')
            .append(dateFormat.format(Date(record.timestampMs)))
            .append("][")
            .append(record.level.wireName())
            .append(']')

        record.threadLabel?.takeIf { it.isNotBlank() }?.let {
            builder.append('[').append(sanitize(it)).append(']')
        }

        builder.append("[")
            .append(sanitize(record.tag))
            .append(']')

        builder.append(": ").append(sanitize(record.message))

        if (record.fields.isNotEmpty()) {
            builder.append(' ')
            record.fields.entries.sortedWith(compareBy<Map.Entry<String, String>> {
                if (it.key == "error") 1 else 0
            }.thenBy { it.key }).forEachIndexed { index, entry ->
                if (index > 0) {
                    builder.append(", ")
                }
                builder.append(sanitize(entry.key))
                    .append('=')
                    .append(formatFieldValue(entry.value))
            }
        }

        return builder.toString()
    }

    private fun sanitize(value: String): String = value
        .replace("\r", "\\r")
        .replace("\n", "\\n")

    private fun formatFieldValue(value: String): String {
        val sanitized = sanitize(value)
        if (sanitized.contains(" ")) {
            return "\"${sanitized.replace("\"", "\\\"")}\""
        }
        return sanitized
    }
}
