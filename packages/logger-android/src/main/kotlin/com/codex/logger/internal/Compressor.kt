package com.codex.logger.internal

internal interface Compressor {
    val algorithm: String
    fun compress(input: ByteArray): ByteArray
}

internal object NoopCompressor : Compressor {
    override val algorithm: String = "none"

    override fun compress(input: ByteArray): ByteArray = input
}

internal object ZlibCompressor : Compressor {
    override val algorithm: String = "zlib"

    override fun compress(input: ByteArray): ByteArray {
        val output = java.io.ByteArrayOutputStream()
        java.util.zip.DeflaterOutputStream(output).use { stream ->
            stream.write(input)
        }
        return output.toByteArray()
    }
}
