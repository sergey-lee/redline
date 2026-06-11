#!/bin/bash
# Builds, Developer-ID signs (app + widget extension), packages a DMG, and
# notarizes Redline for distribution outside the App Store.
#
# Prerequisites (one-time):
#   • Apple ID added in Xcode → Settings → Accounts (Team 4GZ4AH8Z6M).
#   • A "Developer ID Application" certificate in your login keychain.
#   • Notary credentials stored once:
#       xcrun notarytool store-credentials redline-notary \
#         --apple-id "you@example.com" --team-id 4GZ4AH8Z6M \
#         --password "app-specific-password"
#
# Usage:
#   ./release.sh                      # archive → Developer-ID export → DMG → notarize → staple
#   SKIP_NOTARIZE=1 ./release.sh      # everything except notarization (local validation)
#   NOTARY_PROFILE=myprofile ./release.sh
#   APPLE_ID=you@x.com TEAM_ID=4GZ4AH8Z6M APPLE_PASSWORD=xxxx ./release.sh

set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Redline"
SCHEME="Redline"
ARCHIVE="build/Redline.xcarchive"
EXPORT_DIR="build/export"
APP="$EXPORT_DIR/$APP_NAME.app"
DMG="dist/$APP_NAME.dmg"
NOTARY_PROFILE="${NOTARY_PROFILE:-redline-notary}"

echo "▸ Regenerating project…"
command -v xcodegen >/dev/null && xcodegen generate >/dev/null

echo "▸ Archiving…"
rm -rf "$ARCHIVE" "$EXPORT_DIR"
xcodebuild archive \
  -project Redline.xcodeproj -scheme "$SCHEME" -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates >/dev/null

echo "▸ Exporting (Developer ID)…"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist Resources/ExportOptions.plist \
  -exportPath "$EXPORT_DIR" \
  -allowProvisioningUpdates >/dev/null

echo "▸ Verifying signature…"
codesign --verify --deep --strict --verbose=2 "$APP"
spctl -a -vvv "$APP" 2>&1 | head -3 || true

echo "▸ Building DMG…"
mkdir -p dist
STAGING="$(mktemp -d)"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
rm -f "$DMG"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGING"
echo "✓ $DMG"

if [ "${SKIP_NOTARIZE:-}" = "1" ]; then
  echo "▸ SKIP_NOTARIZE=1 — signed DMG built, not notarized."
  exit 0
fi

echo "▸ Notarizing…"
if [ -n "${APPLE_ID:-}" ] && [ -n "${TEAM_ID:-}" ] && [ -n "${APPLE_PASSWORD:-}" ]; then
  xcrun notarytool submit "$DMG" --apple-id "$APPLE_ID" --team-id "$TEAM_ID" --password "$APPLE_PASSWORD" --wait
else
  xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
fi

echo "▸ Stapling…"
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"
echo "✓ Notarized & stapled: $DMG — upload this to GitHub Releases."
