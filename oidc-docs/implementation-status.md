---
title: Sakrylle Chat Implementation Status
status: local
scope: product-local
canonical_source: ../../sub2api/sakrylle-docs/10-platform-identity/current-state.md
last_verified: 2026-06-10
---

# Sakrylle Chat Implementation Status

Current documentation status: **security-critical local OIDC work is implemented in this repository; macOS arm64 debug launch has been verified; OAuth browser round-trip smoke testing is still required before release sign-off.**

Canonical platform status lives in [Sakrylle OIDC current state](../../sub2api/sakrylle-docs/10-platform-identity/current-state.md). This file only tracks product-local readiness and gaps.

## Product-local readiness checklist

- [x] Local configuration points are documented in [local-integration.md](./local-integration.md).
- [x] Product-specific OAuth/OIDC callback or scheme is documented.
- [x] Token storage behavior is documented.
- [x] Known security gaps are linked to product implementation tasks and test coverage.
- [x] macOS arm64 debug launch has been verified with `flutter run -d macos --debug`.
- [ ] Runtime login, refresh, revoke/logout, and profile mapping smoke tests are completed on every release target.

## Implemented local controls

- `lib/core/services/auth/sakrylle_oauth_service.dart` uses OIDC discovery endpoints instead of hardcoded token/authorize endpoint strings.
- `lib/core/services/auth/oidc_id_token_validator.dart` verifies `id_token` signature through JWKS and checks issuer, audience, time claims, and nonce.
- OAuth token response handling rejects missing `access_token` or `id_token` before storing tokens.
- OAuth logs were reduced to non-sensitive flow status; code, tokens, callback URLs, auth URLs, and raw token responses are not printed.
- `lib/core/services/auth/secure_storage_service.dart` fails closed when secure storage is unavailable, probes read/write/delete availability before use, and only reads legacy SharedPreferences fallback values for migration into secure storage.
- Expired or otherwise invalid stored `id_token` values are cleared locally instead of crashing Sakrylle OAuth status UI during startup.
- Sakrylle login UI strings in provider detail and desktop provider panes are localized through the four ARB files.

## Test evidence

Focused automated tests added:

- `test/core/services/auth/oidc_id_token_validator_test.dart`
  - accepts a signed token with matching issuer, audience, and nonce
  - rejects wrong nonce
  - rejects token signed by an unknown key
  - rejects expired tokens
- `test/core/services/auth/secure_storage_service_test.dart`
  - stores API keys and OAuth tokens in secure storage
  - migrates legacy fallback values into secure storage
  - fails closed when secure storage is unavailable
- `test/features/provider/pages/provider_detail_page_oidc_smoke_test.dart`
  - renders the localized Sakrylle login button

## Remaining product-local gaps

- Android/iOS/macOS callback configuration is present in the repository, but real OAuth browser round-trip smoke tests still need to be run in the target app builds.
- Windows/Linux OAuth callback handling is implemented via loopback redirect (`http://127.0.0.1` with a dynamically assigned port). The loopback server is conditionally imported using `dart:io` and only activated on Windows/Linux. Awaiting center RP registration (`oauth_clients` write) and RFC 8252 §7.3 port-agnostic redirect matching confirmation before production smoke testing.
- Some historical or compatibility-sensitive Kelivo identifiers remain intentionally out of scope for this pass, including provider key compatibility, release artifact naming, window autosave keys, and native internal type names.

## Suggested verification

- Run OAuth login in a non-production test profile on Android, iOS, and macOS.
- Run OAuth login on Windows and Linux once center RP registration is confirmed; verify the loopback callback round-trip and that RFC 8252 §7.3 port-agnostic redirect matching is active on the server side.
- Verify no auth code, token, callback URL, authorization URL, or token response is printed to logs.
- Confirm tokens are stored only in platform secure storage.
- Validate refresh, revoke/logout, and profile mapping behavior.
- Confirm center platform `allowed_scopes` covers `openid profile email models:read chat.completions:create offline_access` (see `oidc-docs/sakrylle-chat-client-registration-request.md` for open questions).
