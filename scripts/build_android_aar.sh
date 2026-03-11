#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_DIR="$ROOT_DIR/packages/logger-android"
OUTPUT_DIR="$ROOT_DIR/dist"
AAR_NAME="logger-android-release.aar"
AAR_SOURCE_PATH="$PROJECT_DIR/build/outputs/aar/$AAR_NAME"
AAR_OUTPUT_PATH="$OUTPUT_DIR/$AAR_NAME"

if [[ ! -x "$PROJECT_DIR/gradlew" ]]; then
  echo "error: gradlew not found at $PROJECT_DIR/gradlew" >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

pushd "$PROJECT_DIR" >/dev/null

echo "Building Android release AAR..."
./gradlew clean assembleRelease

popd >/dev/null

if [[ ! -f "$AAR_SOURCE_PATH" ]]; then
  echo "error: expected AAR not found at $AAR_SOURCE_PATH" >&2
  exit 1
fi

cp "$AAR_SOURCE_PATH" "$AAR_OUTPUT_PATH"

echo "Built $AAR_OUTPUT_PATH"
