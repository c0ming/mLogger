# Repository Guidelines

## Project Structure & Module Organization

This repository contains a cross-platform mobile logger SDK.

- `packages/logger-ios`: Swift Package for iOS (`Sources/`, `Tests/`).
- `packages/logger-android`: Android library module with Gradle wrapper, Kotlin sources in `src/main/kotlin`, and unit tests in `src/test/kotlin`.
- `docs`: SDK design and packaging notes.
- `scripts`: release packaging helpers, including iOS `xcframework` and Android `aar` build scripts.
- `dist`: generated distribution artifacts. Do not commit build outputs.

Log files use timestamp-based names such as `log_20260311_155337.log`.

## Build, Test, and Development Commands

- `cd packages/logger-ios && swift test`: run all iOS unit tests.
- `cd packages/logger-ios && swift build`: verify the iOS package builds.
- `cd packages/logger-android && ./gradlew testDebugUnitTest --rerun-tasks`: run Android JVM unit tests with per-test output.
- `cd packages/logger-android && ./gradlew assembleRelease`: build the Android release AAR locally.
- `./scripts/build_ios_xcframework.sh`: build `dist/mLogger.xcframework`.
- `./scripts/build_android_aar.sh`: build `dist/logger-android-release.aar`.

## Coding Style & Naming Conventions

- Use 4 spaces for Swift and Kotlin indentation.
- Keep public iOS and Android APIs aligned in naming and behavior.
- Prefer full method names: `debug`, `info`, `warn`, `error`, `fatal`.
- Use `UpperCamelCase` for types, `lowerCamelCase` for methods and properties.
- Keep log formatting changes synchronized across both platforms.

## Testing Guidelines

- iOS tests use Swift Testing in `packages/logger-ios/Tests`.
- Android tests use JUnit in `packages/logger-android/src/test/kotlin`.
- Add tests for every behavior change on both platforms when applicable.
- Favor descriptive test names such as `maxDiskBytesTrimsOldestSegmentFiles`.
- When changing log format, update formatter assertions and concurrency tests together.

## Commit & Pull Request Guidelines

- Follow concise, imperative commit messages, e.g. `Refine logger runtimes and Android packaging`.
- Keep commits focused; avoid mixing generated artifacts with source changes.
- PRs should include:
  - a short summary of the user-visible change,
  - affected platforms (`iOS`, `Android`, or both),
  - test evidence (`swift test`, `./gradlew testDebugUnitTest`),
  - sample log output if formatting changed.

## Security & Configuration Tips

- Do not commit local caches, `build/`, `.gradle/`, `.build/`, or `dist/`.
- Use `storagePath` inside app-controlled directories only.
- Treat redaction changes carefully; verify `redactedKeys` behavior in tests before merging.
