#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

export CLANG_MODULE_CACHE_PATH=/private/tmp/pdf-speech-clang-cache
export SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/pdf-speech-swift-cache

swift build --configuration release -debug-info-format none --disable-sandbox \
  --cache-path /private/tmp/pdf-speech-build-cache \
  --manifest-cache local --scratch-path .build

APP_PATH="${PDF_SPEECH_APP_PATH:-$PROJECT_ROOT/dist/LibraryOn.app}"
CONTENTS="$APP_PATH/Contents"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp .build/release/PDFSpeech "$CONTENTS/MacOS/PDFSpeech"
cp -R .build/release/PDFSpeech_PDFSpeech.bundle "$CONTENTS/Resources/"
cp App/Info.plist "$CONTENTS/Info.plist"
for language in id en; do
  mkdir -p "$CONTENTS/Resources/$language.lproj"
  cp "Sources/PDFSpeech/Resources/$language.lproj/Localizable.strings" \
    "$CONTENTS/Resources/$language.lproj/Localizable.strings"
done
mkdir -p "$CONTENTS/Resources/Licenses"
cp Licenses/epubjs-BSD-2-Clause.txt "$CONTENTS/Resources/Licenses/epubjs-BSD-2-Clause.txt"
cp Vendor/ZIPFoundation/LICENSE "$CONTENTS/Resources/Licenses/ZIPFoundation-LICENSE.txt"
if [[ -n "${PDF_SPEECH_BUNDLE_ID:-}" ]]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $PDF_SPEECH_BUNDLE_ID" "$CONTENTS/Info.plist"
fi
if [[ -n "${PDF_SPEECH_APP_NAME:-}" ]]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleName $PDF_SPEECH_APP_NAME" "$CONTENTS/Info.plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $PDF_SPEECH_APP_NAME" "$CONTENTS/Info.plist"
fi

ICON_TMP="$(mktemp -d /private/tmp/pdf-speech-icon.XXXXXX)"
for variant in Default Dark; do
  ICON_SOURCE="$PROJECT_ROOT/AppIcon/Icons-iOS-$variant-1024@1x.png"
  if [[ ! -f "$ICON_SOURCE" ]]; then
    echo "Ikon tidak ditemukan: $ICON_SOURCE" >&2
    exit 1
  fi
  ICON_SET="$ICON_TMP/AppIcon-$variant.iconset"
  mkdir -p "$ICON_SET"
  swift -module-cache-path /private/tmp/pdf-speech-swift-cache \
    Scripts/make-icon.swift "$ICON_SOURCE" "$ICON_SET"
  if [[ "$variant" == "Default" ]]; then
    ICON_OUTPUT="$CONTENTS/Resources/AppIcon.icns"
  else
    ICON_OUTPUT="$CONTENTS/Resources/AppIcon-Dark.icns"
  fi
  if ! iconutil -c icns "$ICON_SET" -o "$ICON_OUTPUT" >/dev/null 2>&1; then
    echo "iconutil unavailable; packing $variant icon directly" >&2
    python3 Scripts/pack-icns.py "$ICON_SET" "$ICON_OUTPUT"
  fi
done
rm -rf "$ICON_TMP"

ENTITLEMENTS="${PDF_SPEECH_ENTITLEMENTS_PATH:-App/Entitlements.plist}"
codesign --force --deep --sign - --entitlements "$ENTITLEMENTS" "$APP_PATH"
touch "$APP_PATH"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
if [[ -x "$LSREGISTER" ]]; then
  "$LSREGISTER" -f "$APP_PATH" >/dev/null 2>&1 ||
    echo "Launch Services registration skipped" >&2
fi
echo "$APP_PATH"
