# iOS Packaging

## Build XCFramework

The iOS SDK currently lives as a Swift Package at [packages/logger-ios](/Users/c0ming/codex/logger/packages/logger-ios).

To package it as an `.xcframework`, run:

```bash
./scripts/build_ios_xcframework.sh
```

Output:

```text
dist/mLogger.xcframework
```

## Integration

After packaging, drag `dist/mLogger.xcframework` into your Xcode project and link it to the app target.

Then use it like:

```swift
import mLogger

let logRoot = FileManager.default
    .urls(for: .cachesDirectory, in: .userDomainMask)
    .first!
    .appendingPathComponent("logger")
    .path

Logger.initialize(
    LoggerConfig(
        storagePath: logRoot,
        minLogLevel: .info,
        maxDiskBytes: 20 * 1024 * 1024,
        maxSegmentBytes: 1 * 1024 * 1024,
        flushIntervalMs: 5_000,
        bufferSize: 20,
        enableConsoleOutput: false,
        enableThreadInfo: true
    )
)

let networkLogger = Logger.getLogger("Network")
networkLogger.error(
    message: "request failed",
    error: nil,
    fields: [
        "path": "/feed",
        "code": 500,
    ]
)
```

## Notes

- The script archives both device and simulator variants.
- The package scheme is `mLogger`.
- The script assumes Xcode command line tools are available.
