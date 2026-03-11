#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE_DIR="$ROOT_DIR/packages/logger-ios"
BUILD_DIR="$ROOT_DIR/build/logger-ios"
OUTPUT_DIR="$ROOT_DIR/dist"
SCHEME="mLogger"
IOS_ARCHIVE_PATH="$BUILD_DIR/mLogger-iOS.xcarchive"
SIM_ARCHIVE_PATH="$BUILD_DIR/mLogger-iOS-Simulator.xcarchive"
XCFRAMEWORK_PATH="$OUTPUT_DIR/mLogger.xcframework"

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "error: xcodebuild not found" >&2
  exit 1
fi

rm -rf "$BUILD_DIR" "$XCFRAMEWORK_PATH"
mkdir -p "$BUILD_DIR" "$OUTPUT_DIR"

pushd "$PACKAGE_DIR" >/dev/null

echo "Archiving iOS device framework..."
xcodebuild archive \
  -scheme "$SCHEME" \
  -destination "generic/platform=iOS" \
  -archivePath "$IOS_ARCHIVE_PATH" \
  -derivedDataPath "$BUILD_DIR/DerivedData" \
  -skipPackagePluginValidation \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES

echo "Archiving iOS simulator framework..."
xcodebuild archive \
  -scheme "$SCHEME" \
  -destination "generic/platform=iOS Simulator" \
  -archivePath "$SIM_ARCHIVE_PATH" \
  -derivedDataPath "$BUILD_DIR/DerivedData" \
  -skipPackagePluginValidation \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES

echo "Creating xcframework..."
xcodebuild -create-xcframework \
  -framework "$IOS_ARCHIVE_PATH/Products/usr/local/lib/mLogger.framework" \
  -framework "$SIM_ARCHIVE_PATH/Products/usr/local/lib/mLogger.framework" \
  -output "$XCFRAMEWORK_PATH"

popd >/dev/null

echo "Built $XCFRAMEWORK_PATH"
