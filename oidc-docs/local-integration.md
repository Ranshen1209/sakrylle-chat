---
title: Sakrylle Chat Local Integration
status: local
scope: product-local
canonical_source: ../../sub2api/sakrylle-docs/10-platform-identity/rp-integration-guide.md
last_verified: 2026-06-06
---

# Sakrylle Chat Local Integration

This page summarizes only the repository-local OIDC/Sakrylle integration concerns for **Sakrylle Chat**.

For protocol details, use the canonical [RP integration guide](../../sub2api/sakrylle-docs/10-platform-identity/rp-integration-guide.md). For current Sakrylle API/OIDC Provider capability, use [current-state.md](../../sub2api/sakrylle-docs/10-platform-identity/current-state.md).

## Local configuration points

- Issuer: `https://sub.sakrylle.com`
- Client id: `sakrylle-chat`
- Redirect URI used by the current Flutter client: `sakrylle-chat://oauth/callback`
- Callback scheme passed to `flutter_web_auth_2`: `sakrylle-chat`
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

Windows and Linux are not claimed as fully verified OAuth callback targets in this repository state. No product-local loopback redirect implementation was added in this pass, and no repository evidence was added for OS-level custom protocol registration on those platforms. If Windows/Linux OAuth login must be supported, implement and register a verifiable callback strategy in a separate platform task and keep the center RP registration in sync.

## Logging and storage constraints

- OAuth logs must not include authorization codes, access tokens, refresh tokens, id tokens, full callback URLs, complete authorization URLs, or raw token responses.
- Token exchange/refresh failures may log or surface bounded status/error names, not raw response bodies.
- Do not introduce SharedPreferences token fallback, hidden credential fallback, or real secrets in source code.

## Preserved historical notes

Detailed original research and development planning were preserved under:

- [historical/research.md](./historical/research.md)
- [historical/development-plan.md](./historical/development-plan.md)

Those files are historical/product-local references. They do not override center platform facts.
