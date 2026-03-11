package com.codex.logger

interface TaggedLogger {
    fun debug(message: String, error: Throwable? = null, fields: Map<String, Any?>? = null)
    fun info(message: String, error: Throwable? = null, fields: Map<String, Any?>? = null)
    fun warn(message: String, error: Throwable? = null, fields: Map<String, Any?>? = null)
    fun error(message: String, error: Throwable? = null, fields: Map<String, Any?>? = null)
    fun fatal(message: String, error: Throwable? = null, fields: Map<String, Any?>? = null)
}
