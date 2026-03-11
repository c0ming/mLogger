package com.codex.logger

enum class LogLevel {
    DEBUG,
    INFO,
    WARN,
    ERROR,
    FATAL;

    fun isEnabled(minimum: LogLevel): Boolean = ordinal >= minimum.ordinal

    fun wireName(): String = when (this) {
        DEBUG -> "D"
        INFO -> "I"
        WARN -> "W"
        ERROR -> "E"
        FATAL -> "F"
    }
}
