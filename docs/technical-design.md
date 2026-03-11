# Mobile Logger SDK Technical Design

## 1. Scope

This document defines the v1 technical design for a mobile logger SDK that supports iOS and Android with aligned behavior.

### 1.1 Goals

- Provide a unified logging API across iOS and Android.
- Optimize for fault analysis rather than analytics events.
- Persist logs locally in a readable line-based format.
- Support bounded disk usage through file rotation.
- Reserve an internal compression extension point for future export flows.

### 1.2 Non-goals

- No network upload in v1.
- No C++ shared runtime.
- No analytics-oriented event schema.

## 2. Architecture

The v1 architecture is `spec-first, per-platform implementation`.

```text
App Code
  -> Logger.initialize(config)
  -> Logger.getLogger(tag)
  -> TaggedLogger
  -> Formatter
  -> Memory Buffer
  -> File Store
```

`logger-core-spec` means shared behavior and schema, not a shared runtime library.

## 3. Log Record Model

The internal model can remain structured, but the persisted format is text:

```text
[2026-03-11 12:08:45.123][E][main][Network]: request failed path=/feed, method=GET, code=500, error="timeout"
```

Internal record fields:

- timestamp
- level
- tag
- message
- thread descriptor
- optional fields map
- optional error

## 4. Formatter Rules

Formatting rules:

- always include date, level, tag, and message
- include `[thread]` before `[tag]` only if thread information is available and enabled
- format fields as `key=value`
- render fields directly after the message, separated by `, `
- render `error` as the last field when present
- escape line breaks in message and field values

## 5. Public API Shape

Global API:

- `Logger.initialize(config)`
- `Logger.getLogger(tag)`
- `Logger.setUserId(...)`
- `Logger.setSessionId(...)`
- `Logger.setTraceId(...)`
- `Logger.setGlobalFields(...)`
- `Logger.addGlobalFields(...)`
- `Logger.removeGlobalFieldKeys(...)`
- `Logger.clearGlobalFields()`
- `Logger.flush()`
- `Logger.shutdown()`
- `Logger.setEnabled(...)`

Tagged logger API:

- `debug(message, error?, fields?)`
- `info(message, error?, fields?)`
- `warn(message, error?, fields?)`
- `error(message, error?, fields?)`
- `fatal(message, error?, fields?)`

Both `error` and `fields` are optional parameters.

## 6. Buffering and Flush

The runtime uses a small in-memory buffer before writing to disk.

Flush triggers:

- buffered record count reaches `bufferSize`
- time since last flush reaches `flushIntervalMs`
- app moves to background
- explicit `flush()`

This reduces write amplification without keeping logs in memory too long.

## 7. File Storage

Use append-only segment files under:

```text
{storagePath}/
  log_20260311_154800.log
  log_20260311_154805.log
```

Rotation rules:

- append to the current segment
- create a new segment when current size exceeds `maxSegmentBytes`
- trim oldest segments when total size exceeds `maxDiskBytes`

## 8. Concurrency

Use one internal serial work queue per SDK instance.

Responsibilities:

- merge global fields
- redact fields
- format lines
- enqueue buffered lines
- flush to disk
- rotate and trim files

Caller-facing log methods should remain non-blocking.

## 9. Redaction

Redaction applies before formatting.

Support:

- exact key match
- case-insensitive key match
- regex-based message replacement

Default keys:

- `password`
- `token`
- `authorization`

## 10. Compression Extension

Compression is exposed as a local export capability in v1.

Suggested public behavior:

```text
Logger.compressLogs(outputPath, algorithm)
```

Current supported algorithms:

- `zlib`
- `none`

The implementation should:

- flush buffered logs first
- read current segment files in order
- concatenate their bytes
- write compressed output to the requested path
