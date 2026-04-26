# ADR-011 — Authelia as OIDC Provider and Forward-Auth

**Date:** 2026-04-26
**Status:** Decided

## Context

ADR-010 established Cloudflare Tunnel as the path for exposing services publicly, with Traefik owning routing at the Ingress level. With public exposure available, the next gap is authentication and identity:

- Apps with native OIDC support (Immich, Jellyfin via plugin) should authenticate against a single identity provider rather than each maintaining its own user database
- Apps without authentication or with weak built-in auth (Sonarr, Radarr, Prowlarr, qBittorrent, the Traefik dashboard) need a reverse-proxy-level auth layer before they are publicly reachable
- The Traefik dashboard is currently protected by a basic-auth middleware (see `k8s/infrastructure/controllers/traefik/helmrelease.yaml`) — a stopgap that should be replaced once a real IdP exists

The cluster runs on ARM64 Pis with constrained RAM (Pi 5 8GB shared with Jellyfin/Immich/ARR stack and their databases). The rest of the platform leans hard on declarative GitOps (Flux + SOPS), so the IdP's configuration model matters as much as its feature list.

## Options Considered

**Keycloak** — JVM, ~1 GB RAM idle. Enterprise-grade but disqualified on resource grounds.

**Authentik** — Python/Django + Postgres + Redis + Outposts. Full web UI, visual Flow builder, OIDC + SAML + LDAP + RADIUS. Polished and feature-rich, but realistic footprint is 500 MB – 1 GB+, and configuration state lives in Postgres (Blueprints provide a YAML escape hatch but the GitOps story is not as clean as file-based config).

**Pocket-ID** — Tiny Go binary, passkey-only OIDC OP. No forward-auth — would still need oauth2-proxy in front of the ARR stack, doubling the moving parts. Mandating passkeys for every user is a stronger constraint than warranted here.

**Kanidm** — Rust, lightweight, strong identity model, OIDC + LDAP. No forward-auth (same oauth2-proxy caveat as Pocket-ID) and a smaller community / fewer integration tutorials than Authelia or Authentik.

**Zitadel** — Go + Postgres, multi-tenant by design. Multi-tenancy is overhead for a homelab; no forward-auth.

**Dex** — Federator only, no user store. Wrong shape for the primary IdP role.

## Decision

Deploy **Authelia** as the cluster's OIDC provider and forward-auth gateway.

- **OIDC OP** for apps with native OIDC support (Immich, Jellyfin via SSO plugin)
- **Forward-auth via Traefik middleware** for apps without OIDC (ARR stack, qBittorrent UI, Traefik dashboard)
- **File-based user backend** (YAML) — LDAP is unnecessary for the current single-operator scope and adds a stateful dependency
- **SQLite** for session/2FA storage — Postgres is unnecessary at this scale
- **WebAuthn + TOTP** for 2FA, with WebAuthn preferred
- **Configuration via SOPS-encrypted ConfigMap/Secret**, reconciled by Flux — same pattern as the rest of the cluster

The basic-auth middleware on the Traefik dashboard is replaced by the Authelia forward-auth middleware as the first integration, before any public-facing app is wired up.

### Why Authelia over Authentik

The choice is effectively Authelia vs. Authentik — the other candidates either need oauth2-proxy as a shim or don't fit the resource budget.

1. **Declarative configuration matches the rest of the platform.** Authelia's entire state — users, OIDC clients, access control rules, 2FA policy — lives in YAML files. That maps cleanly onto the existing Flux + SOPS pattern and means an `mr` to git is the audit log. Authentik's state lives in Postgres; Blueprints exist but are a parallel mechanism, not the primary one.

2. **Resource footprint.** Authelia idles around ~80 MB RAM. Authentik realistically needs 500 MB – 1 GB once server + worker + Postgres + Redis + at least one Outpost are running. The Pi 5 will host Jellyfin, Immich (with its own Postgres), and the ARR stack — keeping the IdP small leaves headroom.

3. **Forward-auth is built-in, not an Outpost.** Authelia ships forward-auth as a first-class feature, configured by a single Traefik middleware. Authentik routes forward-auth through a separate Proxy Outpost process — workable, but more components for the same outcome.

4. **Feature ceiling matches the use case.** Authentik's killer feature is the Flow builder (composable login/enrollment/recovery stages, conditional MFA, per-app policy mixing). Authelia's per-app access rules and 2FA policy cover the homelab's needs without that machinery.

5. **Lower migration regret.** If the homelab grows beyond what Authelia handles cleanly — many users, SAML apps, complex flows — Authentik is the natural upgrade path. The reverse migration (Authentik → Authelia) would be a downgrade and is unlikely. Starting with the lighter option is the lower-regret choice.

## Consequences

- The Traefik dashboard's basic-auth middleware (`k8s/infrastructure/controllers/traefik/helmrelease.yaml`) is removed once Authelia is reconciled and the forward-auth middleware is in place
- Adding a user is an edit to a SOPS-encrypted YAML file followed by a Flux reconcile — no UI, no runtime API
- Adding an OIDC client is a YAML change in the Authelia config plus the corresponding configuration in the consuming app
- New public-facing apps follow one of two patterns:
  - **OIDC-native apps** (Immich, Jellyfin): register an OIDC client in Authelia, configure the app to point at it
  - **Non-OIDC apps** (ARR stack, qBittorrent): attach the Authelia forward-auth middleware to the app's Ingress
- Authelia becomes a critical dependency for everything publicly exposed — its availability gates access to those services
- If the homelab grows beyond Authelia's comfort zone (many users, SAML apps, conditional flows), revisit and migrate to Authentik
