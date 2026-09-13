#!/usr/bin/env bash
# Produce a distributable arm64 DMG only after Developer ID and notary acceptance.
set -euo pipefail
: "${SIGNING_KEYCHAIN:?Signing keychain required}"
: "${SIGNING_IDENTITY:?Developer ID Application identity required}"
: "${NOTARY_KEY_ID:?App Store Connect notary key ID required}"
: "${NOTARY_ISSUER:?App Store Connect issuer required}"
: "${NOTARY_KEY_PATH:?Path to private notary key required}"
case "$SIGNING_IDENTITY" in
  'Developer ID Application: '*) ;;
  *) echo 'A Developer ID Application identity is required; development/ad-hoc signing is rejected.' >&2; exit 1 ;;
esac
app='build/macos/Build/Products/Release/Sakrylle Chat.app'
version=$(python3 -c "import re; print(re.search(r'^version: (.+)$',open('pubspec.yaml').read(),re.M)[1])")
binary="$app/Contents/MacOS/sakrylle_chat"
# CFBundleExecutable is authoritative; do not infer it from the display name.
executable=$(/usr/libexec/PlistBuddy -c 'Print CFBundleExecutable' "$app/Contents/Info.plist")
binary="$app/Contents/MacOS/$executable"
test "$(lipo -archs "$binary")" = arm64
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
export RELEASE_APP="$app"
# Sign inside out. Mach-O files first, then containing bundles, then the app.
python3 - <<'PY'
import os, subprocess
from pathlib import Path
app = Path(os.environ['RELEASE_APP'])
identity = os.environ['SIGNING_IDENTITY']
keychain = os.environ['SIGNING_KEYCHAIN']
for p in sorted(app.rglob('*'), key=lambda p: len(p.parts), reverse=True):
    if p.is_symlink():
        continue
    if p.is_file() and 'Mach-O' in subprocess.check_output(['file', '-b', str(p)], text=True):
        subprocess.run(['codesign', '--force', '--timestamp', '--options', 'runtime', '--keychain', keychain, '--sign', identity, str(p)], check=True)
    elif p.is_dir() and p.suffix in {'.framework', '.app', '.xpc', '.bundle'}:
        subprocess.run(['codesign', '--force', '--timestamp', '--options', 'runtime', '--keychain', keychain, '--sign', identity, str(p)], check=True)
PY
codesign --force --timestamp --options runtime --entitlements macos/Runner/Release.entitlements --keychain "$SIGNING_KEYCHAIN" --sign "$SIGNING_IDENTITY" "$app"
codesign --verify --deep --strict --verbose=2 "$app"
codesign -dv --verbose=4 "$app" 2> "$work/signature.txt"
grep -q '^Authority=Developer ID Application:' "$work/signature.txt"
grep -q '^TeamIdentifier=8XBMNVHFK6$' "$work/signature.txt"
ditto -c -k --keepParent "$app" "$work/app.zip"
xcrun notarytool submit "$work/app.zip" --key "$NOTARY_KEY_PATH" --key-id "$NOTARY_KEY_ID" --issuer "$NOTARY_ISSUER" --wait --output-format json > "$work/app-notary.json"
python3 -c 'import json,sys; assert json.load(open(sys.argv[1]))["status"] == "Accepted"' "$work/app-notary.json"
xcrun stapler staple "$app"
xcrun stapler validate "$app"
spctl --assess --type execute --verbose=2 "$app"
mkdir "$work/image"
ditto "$app" "$work/image/Sakrylle Chat.app"
ln -s /Applications "$work/image/Applications"
mkdir -p release
image="release/Sakrylle_Chat_macOS-arm64-${version}.dmg"
test ! -e "$image"
hdiutil create -volname 'Sakrylle Chat' -srcfolder "$work/image" -format UDZO "$image"
codesign --force --timestamp --keychain "$SIGNING_KEYCHAIN" --sign "$SIGNING_IDENTITY" "$image"
xcrun notarytool submit "$image" --key "$NOTARY_KEY_PATH" --key-id "$NOTARY_KEY_ID" --issuer "$NOTARY_ISSUER" --wait --output-format json > "$work/dmg-notary.json"
python3 -c 'import json,sys; assert json.load(open(sys.argv[1]))["status"] == "Accepted"' "$work/dmg-notary.json"
xcrun stapler staple "$image"
xcrun stapler validate "$image"
codesign --verify --strict --verbose=2 "$image"
shasum -a 256 "$image" > release/SHA256SUMS
cp "$work/app-notary.json" release/app-notary.json
cp "$work/dmg-notary.json" release/dmg-notary.json
cp "$work/signature.txt" release/signature.txt
printf 'commit=%s\nversion=%s\narchitecture=arm64\nci_run=%s\n' "$(git rev-parse HEAD)" "$version" "${GITHUB_RUN_ID:-local}" > release/provenance.txt
