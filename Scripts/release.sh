#!/bin/bash
# Builds, signs, notarizes, and packages the chapterize CLI for distribution.
#
#   ./Scripts/release.sh <version>        e.g. ./Scripts/release.sh 1.0.0
#
# Requirements:
#   - A "Developer ID Application" certificate in the login keychain.
#   - Notarization credentials: the App Store Connect API key env vars from
#     ChapterPod's fastlane/.env (ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH)
#     are used automatically when that file exists; otherwise a keychain
#     profile named by NOTARY_PROFILE (default "chapterize-notary").
#
# Output: build/chapterize-<version>.zip, notarized and ready to attach to a
# GitHub release. Prints the sha256 for the Homebrew formula.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:?Usage: ./Scripts/release.sh <version>}"
NOTARY_PROFILE="${NOTARY_PROFILE:-chapterize-notary}"
ENV_FILE="${ENV_FILE:-$HOME/Apps/ChapterPod/fastlane/.env}"
ZIP_PATH="build/chapterize-${VERSION}.zip"

if [[ -f "$ENV_FILE" ]]; then
  set -a
  source "$ENV_FILE"
  set +a
fi

echo "Building chapterize ${VERSION} (release, universal)..."
swift build -c release --arch arm64 --arch x86_64

BIN=".build/apple/Products/Release/chapterize"
test -x "$BIN"

echo "Signing with Developer ID..."
codesign --force --options runtime --timestamp \
  --sign "Developer ID Application" \
  "$BIN"

echo "Zipping..."
mkdir -p build
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$BIN" "$ZIP_PATH"

echo "Submitting to the Apple notary service (this can take a few minutes)..."
if [[ -n "${ASC_KEY_PATH:-}" ]]; then
  xcrun notarytool submit "$ZIP_PATH" \
    --key "$ASC_KEY_PATH" \
    --key-id "$ASC_KEY_ID" \
    --issuer "$ASC_ISSUER_ID" \
    --wait
else
  xcrun notarytool submit "$ZIP_PATH" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait
fi

# Command-line tools cannot be stapled (no bundle). Gatekeeper checks the
# ticket online, and Homebrew installs skip quarantine anyway.

SHA256=$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')
echo ""
echo "Done: $ZIP_PATH"
echo "  sha256: $SHA256"
echo ""
echo "Next steps:"
echo "  1. Create a GitHub release with human-readable notes and attach the zip."
echo "  2. Update Formula/chapterize.rb in homebrew-tap with the URL and sha256."
