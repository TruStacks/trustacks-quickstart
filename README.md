# TruStacks Quickstart

> **Workshop + developer evaluation surface** for the TruStacks agentic platform. Single-node k3d local sandbox; runs on a MacBook in about 2 minutes. **Production hosting is separate** (GKE-hosted SaaS, launching 2026-07-27).

```sh
curl -fsSL https://trustacks.app/install | bash
```

That command pulls this repository, validates your local CLIs (Docker, k3d, kubectl, helm), creates a k3d cluster, installs the TruStacks control-plane + runner + UI from `ghcr.io/trustacks/*`, seeds four sample apps into a local Gitea, and prints URLs you can open in your browser. Bring your own Anthropic API key when you first run `/audit` or `/plan` — the UI's *Settings → LLM Provider* page handles it.

---

## What you get

After `bootstrap.sh` completes:

| Surface | URL | What it is |
|---------|-----|------------|
| **TruStacks UI** | `http://ui.localtest.me:8080` | The web app — agent activity, /audit, /plan, /stack |
| **Gitea** | `http://gitea.localtest.me:8080` | In-cluster Git host with the four pre-seeded sample repos |
| **ArgoCD** | `http://argocd.localtest.me:8080` | Watches the platform repo, syncs Applications you merge |

Four sample apps in `samples/` get pushed to Gitea automatically (per `helm/values-quickstart.yaml`):

- `fastapi-hello` — Python / FastAPI
- `spring-boot-hello` — Java / Spring Boot
- `dotnet-hello` — C# / ASP.NET Core
- `go-hello` — Go / stdlib HTTP

Each is a minimal "hello world" service the agent can analyze. Pick any one, run `/plan` on it from the UI, and watch a real PR open in the local Gitea with a CI workflow + Helm chart + ArgoCD Application.

---

## 15-minute workshop walkthrough

1. **Install.** `curl -fsSL https://trustacks.app/install | bash` (≈ 2 min).
2. **Open the UI** at `http://ui.localtest.me:8080`. Click **Settings → LLM Provider** and paste your Anthropic API key. The UI validates it with a live ping.
3. **Run an audit.** Navigate to **/audit** and click *Run gap analysis*. The Coordinator + Baseline Security agents narrate the customer's gap report inline.
4. **Pick a sample.** From the Services list, pick `sample-app-fastapi-hello`. The Code Reviewer agent has already analyzed it; click *Promote to proposal*.
5. **Watch a PR open.** The DevOps Engineer agent emits a CI workflow + Helm chart + ArgoCD Application; the proposal opens as a PR in the local Gitea (`http://gitea.localtest.me:8080`). The PR body cites the constitution rules it satisfies + the Profile entries it consumed.
6. **Merge in Gitea.** ArgoCD detects the merge, syncs the new Application, and the sample runs in your cluster.
7. **Iterate.** Edit the sample's Profile (in the overlay repo on Gitea), re-run `/audit`, watch the maturity score change.

That's the loop. Real PRs. Real policy gate. Real signed artifacts.

---

## Configuration

Most quickstart users won't need to change anything. For procurement or pinned-version needs:

| Environment variable | Default | What it does |
|----------------------|---------|--------------|
| `TRUSTACKS_VERSION` | `latest` | Image tag pulled from `ghcr.io/trustacks/*`. Set to a specific semver (e.g., `0.1.0`) for reproducible installs. |
| `TRUSTACKS_CLUSTER_NAME` | `trustacks` | k3d cluster name. Change if you already have a cluster called `trustacks`. |
| `ANTHROPIC_API_KEY` | (unset) | Optional — if set, will be applied at install. Otherwise the UI prompts you. |

```sh
# Reproducible pinned install
TRUSTACKS_VERSION=0.1.0 \
    curl -fsSL https://trustacks.app/install | bash
```

---

## Supply-chain verification

Every TruStacks image is signed via Sigstore keyless OIDC. Verify before you trust:

```sh
cosign verify \
  --certificate-identity-regexp \
    'https://github.com/trustacks/trustacks-mvp/.github/workflows/publish-images.yml@.*' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  ghcr.io/trustacks/runner:0.1.0
```

SBOMs:

```sh
docker buildx imagetools inspect \
  ghcr.io/trustacks/runner:0.1.0 \
  --format '{{ json .SBOM }}'
```

The signing identity is the publish workflow at `trustacks/trustacks-mvp/.github/workflows/publish-images.yml`. If verification fails, **don't run the image** — report to `security@trustacks.app`.

---

## What this is, and isn't

| Concern | What quickstart does | What it doesn't do |
|---------|----------------------|---------------------|
| Audience | Workshop attendees, design-partner evaluators, curious developers | Production deployments — those are the hosted GKE SaaS, separate |
| Infrastructure | Single-node k3d on your laptop | Multi-cluster, multi-region, HA |
| LLM cost | BYO Anthropic / OpenRouter key — you pay, we don't intermediate | Managed-key Workspace — that's the hosted SaaS |
| Trial duration | No expiration — pull, run, delete cluster, repeat | Production-grade SLA |
| License | Apache 2.0 (this repo) for scripts; TruStacks EULA Beta for images | Production-grade commercial license (post-GA only) |

---

## Trouble?

| Symptom | Try |
|---------|-----|
| `k3d: command not found` | `brew install k3d` (or see https://k3d.io/#installation) |
| `docker: daemon not running` | Start Docker Desktop |
| `Permission denied` on port 8080 | Another service is bound there. Set `K3D_PORT=8081` and re-run. |
| UI loads but agent calls hang | You probably haven't pasted an Anthropic key. *Settings → LLM Provider*. |
| ArgoCD never syncs | Check `kubectl -n argocd get applications` — sync policy is manual in the quickstart |

File an issue at https://github.com/TruStacks/trustacks-quickstart/issues with the output of `kubectl -n trustacks-system get pods` + your k3d version.

---

## Cleanup

```sh
k3d cluster delete trustacks
```

Removes the cluster, the in-cluster Gitea repos, the cached images. Doesn't touch your Anthropic billing relationship.

---

## License + the bright line

- **This repository** (install.sh, bootstrap.sh, helm/, samples/, README.md) — **Apache License 2.0**. Fork it, modify it, run it inside or outside your organization.
- **The container images** at `ghcr.io/trustacks/*` — governed by the [TruStacks End-User License Agreement (Beta)](https://trustacks.app/eula). Permitted use covers evaluation, workshop, and local development on infrastructure you control. Not for production use during Beta; not for redistribution.
- **The constitution Rego bundle + framework packs** — Apache 2.0, at https://github.com/TruStacks/trustacks-policy.
- **The TruStacks trademark** — governed by https://github.com/TruStacks/trustacks-policy/blob/main/TRADEMARK.md.

See `LICENSE` and `NOTICE` in this repo for the full text.

---

## Roadmap

- **v0.1.0** — initial public release (workshop quickstart, four polyglot samples, BYO LLM key)
- **v0.2.x** — public OCI fallback for the constitution Rego bundle so the bootstrap doesn't need in-cluster Zot setup
- **v0.x+** — Recommended-tools-on-/stack (Candidate M, in flight) + intent-state Promote action (Candidate N, queued) — these ship through `trustacks-mvp` image releases; this scaffold updates to surface them as they land

See [`docs/phase-4-roadmap.md`](https://github.com/TruStacks/trustacks-mvp/blob/main/docs/phase-4-roadmap.md) — Candidate O for the full quickstart roadmap entry (currently access-restricted; mirror docs live at https://trustacks.app/docs).

---

## Contact

- **Workshop questions:** the Discord linked from https://trustacks.app
- **Security / supply-chain:** security@trustacks.app
- **License / trademark:** legal@trustacks.app
- **Everything else:** hello@trustacks.app

**Thanks for trying TruStacks.** Feedback from quickstart users shapes the 2026-07-27 Beta launch directly.
