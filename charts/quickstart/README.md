# `trustacks-quickstart` Helm chart

Workshop / evaluation install path for TruStacks. Spins up the full stack
(control-plane + runner + UI + gitea + ArgoCD) on a single k3d cluster so
an attendee can run the agent loop (`/audit` → `/plan` → PR → ArgoCD sync)
end-to-end without any TruStacks-hosted SaaS dependency.

This chart implements the "all-in-one workshop topology" — it's not the
production Developer-tier SaaS shape. The production chart (post-Slice
22.5 / Slice 23) will be a different chart: multi-tenant CP, externalized
secrets, GKE-shaped ingress, no UI deployment (UI lives with the hosted
CP in that shape). See `values.yaml`'s `mode:` field for the marker.

## Quick start

> **Status (A2.2):** the chart is installable via direct `helm` commands as
> shown below. The `bootstrap.sh` wrapper at the root of this repo (which
> will run the prereq checks + the chart install + the post-install
> seeding) lands in A2.3 — until then it still emits a TODO warning at
> the install step. Use the direct `helm` flow below.

Once A2.3 ships, `bootstrap.sh` becomes the canonical one-shot
entrypoint. For direct chart installation today (and as a contributor
debugging path even after A2.3):

```bash
# From the root of this repo:
helm dep update charts/quickstart

# Install the chart. `--create-namespace` is fine — the chart installs
# into `trustacks-system` plus the two subchart namespaces (gitea +
# argocd) created by their respective subcharts.
helm upgrade --install trustacks charts/quickstart \
  --namespace trustacks-system --create-namespace \
  --wait --timeout 5m
```

Then open `http://ui.localtest.me:8080` (assuming k3d's
`--port 8080:80@loadbalancer` flag, which `bootstrap.sh` sets) and paste
your Anthropic or OpenRouter API key into Settings → LLM Provider.

## Pinning a specific version

The chart defaults to `:latest` for all four OCI artifacts (control-plane,
runner, UI images + the constitution Rego bundle). For reproducible
workshop runs:

```bash
helm upgrade --install trustacks charts/quickstart \
  --namespace trustacks-system --create-namespace \
  --set image.controlPlane.tag=0.1.0 \
  --set image.runner.tag=0.1.0 \
  --set image.ui.tag=0.1.0 \
  --set policyBundle.bundleRef=ghcr.io/trustacks/policy/constitution:0.1.0 \
  --wait --timeout 5m
```

`bootstrap.sh` exposes the `TRUSTACKS_VERSION` env var for the same
effect via a single knob.

## What the chart installs

| Namespace | Resource | Purpose |
|---|---|---|
| `trustacks-system` | `control-plane` Deployment + Service + RBAC + Ingress | FastAPI control plane (CRUD + dispatcher + SSE) |
| `trustacks-system` | `runner` Deployment + Service + RBAC + Ingress | Hosts the Crew agents; pulls constitution bundle at startup |
| `trustacks-system` | `ui` Deployment + Service + Ingress | The React app — chat, /audit, /plan, /stack, Settings → LLM Provider |
| `<release>-gitea` (subchart) | Gitea + Ingress | In-cluster git provider for sample repos + the platform repo agents open PRs against |
| `<release>-argocd` (subchart) | ArgoCD + Ingress | GitOps watcher that syncs merged PRs into the cluster |

## Image + bundle provenance

Every image and the constitution Rego bundle are Sigstore-signed via
keyless OIDC against this repo's publish workflows. Customer-side
verification:

```bash
# Verify any container image:
cosign verify \
  --certificate-identity-regexp \
    'https://github.com/TruStacks/trustacks-mvp/.github/workflows/publish-images.yml@.*' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  ghcr.io/trustacks/runner:0.1.0

# Verify the constitution Rego bundle:
cosign verify \
  --certificate-identity-regexp \
    'https://github.com/TruStacks/trustacks-mvp/.github/workflows/publish-policy.yml@.*' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  ghcr.io/trustacks/policy/constitution:0.1.0
```

The runner's `load-policy-bundle` init container performs the bundle
verification at pod startup — verification failures block extract and
fall back to the rego baked into the image.

## License

The chart, sample repos, and bootstrap scripts in this repository are
Apache License 2.0 (see `LICENSE` at the repo root). The container
images installed by this chart are governed separately by the TruStacks
EULA at <https://trustacks.com/eula>.
