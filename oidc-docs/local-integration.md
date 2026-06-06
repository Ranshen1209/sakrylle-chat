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

## Local focus areas

- Flutter OAuth/PKCE flow and custom URL scheme
- secure token storage and fail-closed behavior if secure storage is unavailable
- provider preset for Sakrylle API
- bundle id / platform app id isolation
- Monet Purple theme and Sakrylle launcher assets
- id_token validation gaps: discovery, JWKS, issuer, audience, expiry, nonce
- sensitive OAuth logs must not include code, tokens, or full token responses

## Preserved historical notes

Detailed original research and development planning were preserved under:

- [historical/research.md](./historical/research.md)
- [historical/development-plan.md](./historical/development-plan.md)

Those files are historical/product-local references. They do not override center platform facts.
