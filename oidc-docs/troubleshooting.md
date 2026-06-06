---
title: Sakrylle Chat Troubleshooting
status: local
scope: product-local
canonical_source: ../../sub2api/sakrylle-docs/10-platform-identity/rp-integration-guide.md
last_verified: 2026-06-06
---

# Sakrylle Chat Troubleshooting

Use this page for product-local failure modes only. For endpoint semantics, scopes, claims, and token boundaries, use the canonical center docs.

## First checks

- Confirm the product is using issuer `https://sub.sakrylle.com` and client id `sakrylle-chat`.
- Confirm the product-specific redirect URI is `sakrylle-chat://oauth/callback` and remains registered in the center RP matrix.
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

- Android, iOS, and macOS have repository-visible `sakrylle-chat` callback configuration.
- Windows and Linux OAuth callback support is not verified in this repository state. If those platforms must support OAuth login, implement a verifiable custom-protocol or loopback strategy and keep center RP registration in sync.

## Canonical references

- [OIDC current state](../../sub2api/sakrylle-docs/10-platform-identity/current-state.md)
- [RP integration guide](../../sub2api/sakrylle-docs/10-platform-identity/rp-integration-guide.md)
- [Commercial boundaries](../../sub2api/sakrylle-docs/10-platform-identity/commercial-boundaries.md)
- [Configuration isolation](../../sub2api/sakrylle-docs/10-platform-identity/configuration-isolation.md)
