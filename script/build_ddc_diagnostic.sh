#!/bin/bash
set -euo pipefail
diagnostic_root="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -z "${DEVELOPER_DIR:-}" ]]; then
  if [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
  else
    export DEVELOPER_DIR="$(xcode-select -p)"
  fi
fi
if [[ ! -x "$DEVELOPER_DIR/usr/bin/xcodebuild" ]]; then
  echo "Full Xcode is required. Set DEVELOPER_DIR to Xcode.app/Contents/Developer." >&2
  exit 1
fi
xcodebuild \
  -project "$diagnostic_root/MacMix.xcodeproj" \
  -scheme MacMix -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$diagnostic_root/build/DerivedData" \
  MARKETING_VERSION=2.2.1 CURRENT_PROJECT_VERSION=20.1 \
  CODE_SIGNING_ALLOWED=NO DEVELOPMENT_TEAM= \
  ONLY_ACTIVE_ARCH=YES ARCHS=arm64 build
diagnostic_app="$diagnostic_root/build/DerivedData/Build/Products/Debug/MacMix DDC Diagnostic.app"
# Finder metadata on locally built bundles can prevent signing in Documents.
xattr -dr com.apple.FinderInfo "$diagnostic_app" 2>/dev/null || true
for diagnostic_binary in "$diagnostic_app/Contents/MacOS/MacMix DDC Diagnostic.debug.dylib" "$diagnostic_app/Contents/MacOS/__preview.dylib"; do
  if [[ -f "$diagnostic_binary" ]]; then
    codesign --force --sign - --timestamp=none "$diagnostic_binary"
  fi
done
# Xcode strips framework headers while embedding; reseal the embedded copy.
codesign --force --sign - --timestamp=none "$diagnostic_app/Contents/Frameworks/Sparkle.framework"
codesign --force --sign - --timestamp=none "$diagnostic_app"
codesign --verify --deep --strict "$diagnostic_app"
