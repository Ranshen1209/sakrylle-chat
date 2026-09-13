---
title: Sakrylle Chat Troubleshooting
status: local
scope: product-local
canonical_source: https://doc.sakrylle.com/apps/chat
last_verified: 2026-09-13
---

# Sakrylle Chat Troubleshooting

Use this page for product-local failure modes only. For endpoint semantics, scopes, claims, and token boundaries, use the canonical center docs.

## First checks

- Confirm the product is using issuer `https://oidc1.sakrylle.com` and client id `sakrylle-chat`.
- Confirm the product-specific redirect URI: `sakrylle-chat://oauth/callback` (Android/iOS/macOS custom scheme) or `http://127.0.0.1:<dynamic-port>/callback` (Windows/Linux loopback), and that both remain registered in the center RP matrix.
- Confirm the app requests the intended local scopes: `openid profile email models:read chat.completions:create offline_access`.
- Confirm local storage paths / bundle ids / data directories do not collide with upstream software.
- Confirm logs do not expose OAuth codes, access tokens, refresh tokens, id tokens, full callback URLs, full authorization URLs, or raw token responses.
- Confirm platform secure storage is available; Sakrylle Chat refuses to persist OAuth/API credentials through insecure SharedPreferences fallback.

## Login fails before browser opens

- Check OIDC discovery availability for the configured issuer.
- Check the platform can reach the Sakrylle API host and that any configured proxy does not block discovery/JWKS requests.
- Check that secure storage initialization succeeds before token persistence is attempted.

## Login returns to app but fails after callback

- Check returned `state` matches the authorization transaction; mismatch is treated as CSRF protection failure.
- Check the token response includes both `access_token` and `id_token` for the authorization-code login path.
- Check `id_token` signature validates against the Sakrylle JWKS.
- Check `iss`, `aud`, `exp` / `nbf` / `iat`, and `nonce` claims match the current transaction.

## Refresh or logout problems

- Refresh token expiry is checked locally when the provider returns `refresh_token_expires_in`.
- `invalid_grant` / `invalid_token` refresh errors clear local OAuth tokens.
- Transient network or server errors during refresh should not be treated as successful refreshes.
- Logout attempts to revoke both refresh and access tokens when the revocation endpoint is advertised by discovery, then clears local OAuth tokens.

## Platform callback boundary

- Android, iOS, and macOS have repository-visible `sakrylle-chat://` callback configuration.
- Windows and Linux use loopback redirect (`http://127.0.0.1` with a dynamically assigned port, per RFC 8252 §7.3). The loopback HTTP server is implemented and activated for those platforms. OAuth browser round-trip smoke testing on Windows and Linux is pending until center RP registration confirms port-agnostic redirect matching. See `oidc-docs/sakrylle-chat-client-registration-request.md` for the outstanding center confirmation item.

## Current references

- [Published Sakrylle Chat documentation](https://doc.sakrylle.com/apps/chat)
- Local checkout: `../Sakrylle Docs/apps/chat.md` (product documentation)
- Local checkout: `../Sakrylle API/` (read-only source for current platform protocol behavior)

## Browser opens and immediately returns to a login failure

Check for the authorization error code `invalid_scope` without logging callback URLs or tokens. The provider discovery document lists platform-supported scopes; it does **not** prove that the `sakrylle-chat` client registration permits each requested scope. Verify the client-specific allowed list against the scope row in the current Chat documentation. Do not remove required scopes or bypass PKCE/state checks to hide a registration mismatch.
