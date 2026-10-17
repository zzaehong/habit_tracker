#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
swift test --package-path ios/ChagokCore --scratch-path runtime/swift-build
xcodebuild -project ios/Chagok.xcodeproj -scheme Chagok -destination 'generic/platform=iOS Simulator' -derivedDataPath runtime/DerivedData CODE_SIGNING_ALLOWED=NO build
if [ -n "${CHAGOK_TEST_DESTINATION:-}" ]; then
  xcodebuild -project ios/Chagok.xcodeproj -scheme Chagok -destination "$CHAGOK_TEST_DESTINATION" -derivedDataPath runtime/DerivedData CODE_SIGNING_ALLOWED=NO test
else
  echo 'UI tests NOT RUN: set CHAGOK_TEST_DESTINATION to an available iPhone simulator.'
fi
