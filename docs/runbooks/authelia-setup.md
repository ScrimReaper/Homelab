# Authelia setup

Bootstrap steps for ADR-011's Authelia deployment. The Helm chart auto-generates Authelia's internal secrets (session, storage encryption, identity-validation JWT, OIDC HMAC and issuer keys) on first install — only the user database needs to be provided manually.

## Storage notes

Persistence uses the `nfs-persistent` StorageClass, backed by `/media/sandisk/persistent` on jellypi. The export is owned by `root:persistent` (GID 2000) with the setgid bit set (mode `2775`). The Authelia pod sets `runAsGroup: 2000` so the process runs with that GID and can read/write its SQLite data. Any future NFS-backed app on this share needs the same GID treatment.

## 1. Generate an argon2 password hash

```sh
docker run --rm authelia/authelia:latest \
  authelia crypto hash generate argon2 --password '<your password>'
```

Copy the resulting `$argon2id$...` string.

## 2. Populate and encrypt the user database

Edit `k8s/infrastructure/controllers/authelia/users-database.yaml`, replace `REPLACE_WITH_ARGON2_HASH` with the hash from step 1, then encrypt in place:

```sh
sops -e -i k8s/infrastructure/controllers/authelia/users-database.yaml
```

The `.sops.yaml` creation rule encrypts only `data` / `stringData` — the rest of the manifest stays human-readable.

## 3. Wire the Secret into the kustomization

Uncomment the `users-database.yaml` line in `k8s/infrastructure/controllers/authelia/kustomization.yaml`.

## 4. Add Authelia to the controllers kustomization

Append `- authelia` to `k8s/infrastructure/controllers/kustomization.yaml`.

## 5. Configure the Cloudflare Tunnel hostname

In the Cloudflare dashboard (per ADR-010, hostname routing lives there, not in git), add a public hostname mapping:

- **Subdomain:** `auth`
- **Domain:** `scrimreaper.dev`
- **Service:** `http://traefik.traefik.svc.cluster.local:80`

## 6. Reconcile and verify

```sh
flux reconcile kustomization infra-controllers --with-source
kubectl -n authelia get pods,svc,ingressroute
```

Visit `https://auth.scrimreaper.dev/` — the Authelia portal should load and accept the credentials from the user database.

## 7. Replace the Traefik dashboard basic-auth (smoke test)

Once the portal is reachable, swap the dashboard's auth middleware to the Authelia forward-auth middleware as the first integration:

- In `k8s/infrastructure/controllers/traefik/helmrelease.yaml`, replace the `dashboard-auth` middleware reference with `authelia-authelia@kubernetescrd` (Traefik's namespaced reference for the `authelia` Middleware in the `authelia` namespace).
- Add an access-control rule for `traefik.scrimreaper.dev` in the Authelia config (currently a comment placeholder in `helmrelease.yaml`).

After this step, the basic-auth Secret and `dashboard-auth` Middleware can be removed.

## Adding OIDC clients (later)

Once an OIDC-native app (Immich, Jellyfin) is being wired up, append an `identity_providers` block to the chart's `configMap` values. The chart will auto-generate the `hmac_secret` and issuer private key — only client entries need to be authored. Each client's `client_secret` should be the pbkdf2 hash output of:

```sh
docker run --rm authelia/authelia:latest \
  authelia crypto hash generate pbkdf2 --variant sha512 --random --random.length 72
```

The plaintext value is what the consuming app stores; the hash is what goes into the Authelia config.
