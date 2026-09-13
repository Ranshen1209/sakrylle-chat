#!/usr/bin/env bash
set -euo pipefail
: "${DEVELOPER_ID_P12_BASE64:?Developer ID certificate secret missing}"
: "${DEVELOPER_ID_P12_PASSWORD:?Certificate password secret missing}"
: "${NOTARY_KEY_BASE64:?Notary API key secret missing}"
: "${RUNNER_TEMP:?CI temporary directory missing}"
keychain="$RUNNER_TEMP/sakrylle-release.keychain-db"
password=$(openssl rand -hex 32)
certificate="$RUNNER_TEMP/sakrylle-developer-id.p12"
trap 'rm -f "$certificate"' EXIT
printf '%s' "$DEVELOPER_ID_P12_BASE64" | base64 --decode > "$certificate"
printf '%s' "$NOTARY_KEY_BASE64" | base64 --decode > "$RUNNER_TEMP/sakrylle-notary.p8"
chmod 600 "$certificate" "$RUNNER_TEMP/sakrylle-notary.p8"
security create-keychain -p "$password" "$keychain"
security set-keychain-settings -lut 21600 "$keychain"
security unlock-keychain -p "$password" "$keychain"
security import "$certificate" -P "$DEVELOPER_ID_P12_PASSWORD" -A -t cert -f pkcs12 -k "$keychain" >/dev/null
security set-key-partition-list -S apple-tool:,apple:,codesign: -k "$password" "$keychain" >/dev/null
# Hosted runner keychain only; signing script explicitly uses this keychain.
echo "SIGNING_KEYCHAIN=$keychain" >> "$GITHUB_ENV"
echo "NOTARY_KEY_PATH=$RUNNER_TEMP/sakrylle-notary.p8" >> "$GITHUB_ENV"
