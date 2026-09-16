#!/usr/bin/env bash
# Archive Scanner, export a Developer ID build, notarize, and staple.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

TEAM_ID="${TEAM_ID:-MNC9M36A88}"
NOTARY_PROFILE="${NOTARY_PROFILE:-notarytool}"
ARCHIVE_PATH="$ROOT/build/release/Scanner.xcarchive"
EXPORT_PATH="$ROOT/build/release/export"
DIST_PATH="$ROOT/build/release/dist"
DERIVED_DATA="$ROOT/build/release/DerivedData"

if ! command -v xcodegen >/dev/null; then
  echo "error: xcodegen is required" >&2
  exit 1
fi

xcodegen generate

mkdir -p "$ROOT/build/release"
rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH" "$DIST_PATH"

echo "==> Archiving Release"
xcodebuild \
  -scheme Scanner \
  -destination 'generic/platform=macOS' \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  -derivedDataPath "$DERIVED_DATA" \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  CODE_SIGN_STYLE=Automatic \
  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
  archive

echo "==> Exporting Developer ID app"
xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$ROOT/scripts/ExportOptions.plist" \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$TEAM_ID"

APP="$EXPORT_PATH/Scanner.app"
if [[ ! -d "$APP" ]]; then
  echo "error: expected $APP after export" >&2
  exit 1
fi

ZIP="$EXPORT_PATH/Scanner.zip"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

notarized=0
if xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
  echo "==> Submitting with notarytool profile '$NOTARY_PROFILE'"
  xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait --timeout 2h
  notarized=1
else
  echo "==> No notarytool profile '$NOTARY_PROFILE'; uploading via Xcode account"
  xcodebuild \
    -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$ROOT/scripts/ExportOptions-upload.plist" \
    -allowProvisioningUpdates \
    DEVELOPMENT_TEAM="$TEAM_ID"
  echo "==> Waiting for notarized export"
  mkdir -p "$DIST_PATH"
  # Apple can take several minutes; retry exportNotarizedApp.
  for _ in {1..36}; do
    if xcodebuild -exportNotarizedApp -archivePath "$ARCHIVE_PATH" -exportPath "$DIST_PATH"; then
      notarized=1
      if [[ -d "$DIST_PATH/Scanner.app" ]]; then
        APP="$DIST_PATH/Scanner.app"
      fi
      break
    fi
    sleep 20
  done
fi

if [[ "$notarized" -ne 1 ]]; then
  echo "error: notarization did not complete. Store credentials with:" >&2
  echo "  xcrun notarytool store-credentials $NOTARY_PROFILE --team-id $TEAM_ID" >&2
  exit 1
fi

echo "==> Stapling"
xcrun stapler staple "$APP"
ZIP="$ROOT/build/release/Scanner-notarized.zip"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "==> Gatekeeper"
spctl --assess --type execute -vv "$APP"
xcrun stapler validate "$APP"

echo "Notarized app: $APP"
echo "Zip: $ZIP"
