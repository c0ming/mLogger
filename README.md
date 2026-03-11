# mLogger

`mLogger` is a mobile fault-analysis logger SDK for iOS and Android. It focuses on readable local log files, small API surface, log rotation, disk budget trimming, redaction, and optional console output.

## Features

- Unified logger API on iOS and Android
- Text log format for troubleshooting, for example:
  - `[2026-03-11 16:38:43.123][I][main][ViewController]: viewDidLoad path=/feed, error="request timeout"`
- Local persistence with timestamp-based files such as `log_20260311_155337.log`
- Rotation by `maxSegmentBytes`
- Old log trimming by `maxDiskBytes`
- `redactedKeys` support for sensitive fields
- Optional compression export interface

## Repository Layout

- `packages/logger-ios`: Swift Package and tests
- `packages/logger-android`: Android library, Gradle wrapper, and tests
- `docs`: design and packaging notes
- `scripts`: packaging scripts for `xcframework` and `aar`

## Quick Start

### iOS

```swift
import Foundation
import mLogger

let logRoot = FileManager.default
    .urls(for: .cachesDirectory, in: .userDomainMask)
    .first!
    .appendingPathComponent("mLogger", isDirectory: true)
    .path

Logger.initialize(LoggerConfig(storagePath: logRoot))

let logger = Logger.getLogger("Network")
logger.info(message: "request started", fields: ["path": "/feed"])
```

### Android

```kotlin
Logger.initialize(
    LoggerConfig(storagePath = context.filesDir.resolve("logs").absolutePath)
)

val logger = Logger.getLogger("Network")
logger.info(message = "request started", fields = mapOf("path" to "/feed"))
```

## Build and Test

- iOS test: `cd packages/logger-ios && swift test`
- iOS build: `cd packages/logger-ios && swift build`
- Android test: `cd packages/logger-android && ./gradlew testDebugUnitTest --rerun-tasks`
- Android AAR: `cd packages/logger-android && ./gradlew assembleRelease`
- Pack iOS framework: `./scripts/build_ios_xcframework.sh`
- Pack Android AAR: `./scripts/build_android_aar.sh`

## Artifacts

- iOS output: `dist/mLogger.xcframework`
- Android output: `dist/logger-android-release.aar`

See also:
- `docs/sdk-spec.md`
- `docs/technical-design.md`
- `docs/ios-packaging.md`
