# Changelog — trustacks-quickstart

All notable changes to the install scripts + scaffold tracked here. The image versions the scaffold pulls are versioned independently in [`trustacks-mvp/docs/versioning.md`](https://github.com/TruStacks/trustacks-mvp/blob/main/docs/versioning.md); this changelog covers the install pipeline only.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## Image compatibility

The `bootstrap.sh` script's `TRUSTACKS_VERSION` env var pins which trustacks-mvp image release to pull. Compatibility notes:

| trustacks-mvp version | BYO-key flow (Settings → LLM Provider) | Notes |
|---|---|---|
| `0.2.23` and later | ❌ Control plane won't start | Every install signs in from 0.2.23 (trustacks-mvp ADR-0078): the control plane refuses to start without an OIDC issuer, and the quickstart doesn't install one yet. The default is pinned to `0.2.22` until it does. |
| `0.1.3` (and later, once published) | ✅ Works end-to-end | Includes the kubernetes-python 36.x auth fix (trustacks-mvp #96). Use this for any new workshop install. |
| `0.1.2` | ❌ UI key submission fails with HTTP 500 | The `PUT /api/llm-config` path returns `failed to write LLM Secret: ... 401 Unauthorized` due to a latent kubernetes-python regression in the CP image. Workaround: skip the UI and set the Secret directly — `kubectl -n trustacks-system create secret generic trustacks-runner-llm --from-literal=ANTHROPIC_API_KEY="<key>" --from-literal=LLM_PROVIDER=anthropic` followed by `kubectl -n trustacks-system rollout restart deployment/runner-runner`. |
| `0.1.0` / `0.1.0-rc1` / `0.1.1` | ❌ Same as 0.1.2 | Same root cause. Same workaround if pinning to an older release is required. |

The default is pinned to `0.2.22`. Don't set `TRUSTACKS_VERSION=latest`: `:latest` advances on each stable release, and from 0.2.23 that image needs sign-in.

## [Unreleased]

### Changed

- Images default to `0.2.22` instead of `:latest`, with `IfNotPresent` pulls. From 0.2.23 the control plane requires an OIDC issuer, so following `:latest` would stop every quickstart install from starting, including existing ones the next time a pod restarts.

### Fixed

- `bootstrap.sh`: removed `--k3s-arg "--disable=traefik@server:0"` that was stripping the cluster's only ingress controller. The umbrella chart at `charts/quickstart/` relies on k3s's bundled Traefik (per `templates/_helpers.tpl` + `templates/ingress.yaml` + `values.yaml` header comment); the disable flag silently broke every `*.localtest.me:8080` route while leaving all workload pods healthy. PR #4.

## [0.1.0] — 2026-05-23 (workshop loop is real)

The first version of the workshop quickstart where `curl -fsSL https://trustacks.com/install | bash` produces a working end-to-end TruStacks sandbox on a customer machine. The `bootstrap.sh` script went from scaffold to a real install that:

- Creates a k3d cluster + namespaces
- Installs the umbrella Helm chart at `charts/quickstart/` (CP + runner + UI + gitea + argocd as subcharts, all in `trustacks-system`)
- Seeds the in-cluster Gitea with 4 polyglot samples (fastapi-hello / spring-boot-hello / dotnet-hello / go-hello) + an empty `trustacks-platform` repo for the agent's emitted PRs
- Registers the ArgoCD root Application watching the platform repo
- Prints the browser URLs + the BYO Anthropic key handoff

### Added

- Helm umbrella chart at `charts/quickstart/` (PR #2 / Candidate O Phase A2.2 in trustacks-mvp).
- `bootstrap.sh` real wiring: `helm dep update` + `helm upgrade --install` against the umbrella chart, Gitea REST-API repo seeding, ArgoCD root Application bootstrap (PR #3 / Phase A2.3).
- Four polyglot hello-world samples under `samples/` (Python FastAPI / Java 21 + Spring Boot 3.4 / .NET 8 / Go 1.23).
- `install.sh` curl-pipe-bash entry that validates prerequisites (docker / k3d / kubectl / helm), clones the repo to a temp dir, and delegates to `bootstrap.sh`.
- `NOTICE` separating the Apache 2.0 install scripts from the TruStacks-EULA-1.0 container images.
- Supply-chain verification command in the README (Sigstore keyless OIDC against the publish workflow identity).
- BYO LLM key flow via the UI's *Settings → LLM Provider* page (per `trustacks-mvp` Slice 23.6 — note Image compatibility above for the version that works end-to-end).

### Changed

- Marketing-site domain unified to `trustacks.com` (was `.app` in earlier drafts; PR #1).

[Unreleased]: https://github.com/TruStacks/trustacks-quickstart/compare/main..HEAD
[0.1.0]: https://github.com/TruStacks/trustacks-quickstart/releases/tag/v0.1.0
