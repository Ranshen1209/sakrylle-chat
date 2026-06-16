---
title: Sakrylle Chat Local Integration
status: local
scope: product-local
canonical_source: ../../sub2api/sakrylle-docs/10-platform-identity/rp-integration-guide.md
last_verified: 2026-06-10
---

# Sakrylle Chat Local Integration

This page summarizes only the repository-local OIDC/Sakrylle integration concerns for **Sakrylle Chat**.

For protocol details, use the canonical [RP integration guide](../../sub2api/sakrylle-docs/10-platform-identity/rp-integration-guide.md). For current Sakrylle API/OIDC Provider capability, use [current-state.md](../../sub2api/sakrylle-docs/10-platform-identity/current-state.md).

## Local configuration points

- Issuer: `https://oidc1.sakrylle.com`
- Client id: `sakrylle-chat`
- Redirect URI used by the current Flutter client:
  - Custom scheme: `sakrylle-chat://oauth/callback` (Android / iOS / macOS)
  - Loopback: `http://127.0.0.1:<dynamic-port>/callback` (Windows / Linux; port is assigned at runtime by the OS)
- Callback scheme passed to `flutter_web_auth_2` (custom scheme path): `sakrylle-chat`
- Loopback server implementation: `lib/core/services/auth/loopback_redirect_server.dart` (conditionally imported via `dart:io`; stub at `loopback_redirect_server_stub.dart`)
- Platform routing: `shouldUseLoopback()` in `sakrylle_oauth_service.dart` returns `true` for Windows and Linux
- Scopes requested by the product client: `openid profile email models:read chat.completions:create offline_access`

These values must remain aligned with the center RP registration matrix. Do not copy endpoint semantics or claim policy into this repository; link to the center docs instead.

## Product-local implementation status

- Flutter OAuth uses Authorization Code + PKCE with `state` and `nonce` bound to the authorization transaction.
- OIDC discovery is read from the issuer before building the authorization and token endpoints.
- `id_token` is verified with JWKS-backed JWS verification plus issuer, audience, expiry/not-before/issued-at, and nonce checks before user identity is trusted.
- Access, refresh, expiry, refresh-expiry, and id token values are stored through `SecureStorageService` under the `sakrylle_chat.oauth.` secure-storage prefix.
- Secure storage is fail-closed for OAuth/API credentials: unavailable secure storage raises an explicit error instead of silently writing tokens to `SharedPreferences`.
- Legacy `secure_fallback.sakrylle_chat.*` values are read only for migration into secure storage; after successful migration the legacy fallback key is removed.
- Sakrylle login/logout/status/error UI text is localized through the app ARB files.

## Platform callback boundary

Runtime launch evidence:

- macOS arm64 debug launch was verified on 2026-06-06 with `flutter run -d macos --debug`; the build produced `build/macos/Build/Products/Debug/Sakrylle Chat.app`, the app reached the Flutter run loop, and secure storage read/write/delete probing completed successfully.
- The same debug run confirmed that a stale expired `id_token` no longer crashes the Sakrylle OAuth status section during startup; local OAuth credentials are cleared instead.
- This launch evidence does not prove the OAuth browser callback round-trip; login, refresh, revoke/logout, and profile mapping still require a real test account smoke test.
- The final `flutter run` session ended with `Lost connection to device` and exit code 0, so the app was not left running after verification.

Verified repository configuration for `sakrylle-chat://oauth/callback` exists on:

- Android: app id/namespace `com.sakrylle.chat`, manifest intent-filter for scheme `sakrylle-chat`, host `oauth`, path prefix `/callback`.
- iOS: bundle id `com.sakrylle.chat`, `CFBundleURLSchemes = sakrylle-chat`.
- macOS: bundle id `com.sakrylle.chat`, `CFBundleURLSchemes = sakrylle-chat`.

Windows and Linux use the loopback redirect strategy (`http://127.0.0.1` with a dynamically assigned port per RFC 8252 §7.3). The loopback HTTP server is implemented in `lib/core/services/auth/loopback_redirect_server.dart` and activated by `shouldUseLoopback()`. The redirect URI is constructed at runtime after the server binds to an OS-assigned port. This approach does not require OS-level custom protocol registration on Windows or Linux. Center RP registration must confirm that redirect matching for `http://127.0.0.1` is done port-agnostically (RFC 8252 §7.3) — see `oidc-docs/sakrylle-chat-client-registration-request.md` for the open question. Full OAuth browser round-trip smoke testing on Windows and Linux remains pending until center registration is in place.

## Logging and storage constraints

- OAuth logs must not include authorization codes, access tokens, refresh tokens, id tokens, full callback URLs, complete authorization URLs, or raw token responses.
- Token exchange/refresh failures may log or surface bounded status/error names, not raw response bodies.
- Do not introduce SharedPreferences token fallback, hidden credential fallback, or real secrets in source code.

## Preserved historical notes

Detailed original research and development planning were preserved under:

- [historical/research.md](./historical/research.md)
- [historical/development-plan.md](./historical/development-plan.md)

Those files are historical/product-local references. They do not override center platform facts.
