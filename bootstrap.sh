#!/usr/bin/env bash
#
# TruStacks Quickstart — bootstrap.
#
# Creates a single-node k3d cluster, installs the Helm releases for
# control-plane / runner / ui / gitea / argocd / zot pointing at the
# public GHCR images, seeds the sample apps, and prints URLs.
#
# Audience: workshop attendees + design-partner evaluators + curious
# developers. The cluster is local-only — explicitly NOT a production
# deployment surface. Production hosting lands as a separate offering
# via GKE (post-2026-07-27 Beta launch).
#
# Knobs (all optional, picked up from env):
#
#   TRUSTACKS_VERSION       — image tag to pull. Defaults to "latest".
#                             Pin to a specific semver for procurement.
#   TRUSTACKS_CLUSTER_NAME  — k3d cluster name. Defaults to "trustacks".
#   ANTHROPIC_API_KEY       — required at first /audit or /plan run.
#                             We don't ship one; you BYO. The cluster
#                             starts without it, and the UI's
#                             Settings → LLM Provider page lets you
#                             paste a key after install (per Slice
#                             23.6's BYO-key flow).
#
# Source: https://github.com/TruStacks/trustacks-quickstart
# EULA: https://trustacks.com/eula

set -euo pipefail

# ---------------------------------------------------------------------------
# Cosmetics
# ---------------------------------------------------------------------------

if [[ -t 1 ]]; then
    BOLD=$'\033[1m'
    DIM=$'\033[2m'
    GREEN=$'\033[32m'
    YELLOW=$'\033[33m'
    RESET=$'\033[0m'
else
    BOLD="" DIM="" GREEN="" YELLOW="" RESET=""
fi

say()  { printf '%s\n' "${BOLD}[bootstrap]${RESET} $*"; }
warn() { printf '%s %s\n' "${YELLOW}[warn]${RESET}" "$*" >&2; }
die()  { printf '%s\n' "[fail] $*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

VERSION="${TRUSTACKS_VERSION:-latest}"
CLUSTER_NAME="${TRUSTACKS_CLUSTER_NAME:-trustacks}"

CP_IMAGE="ghcr.io/trustacks/control-plane:${VERSION}"
RUNNER_IMAGE="ghcr.io/trustacks/runner:${VERSION}"
UI_IMAGE="ghcr.io/trustacks/ui:${VERSION}"

say "version: ${BOLD}${VERSION}${RESET}    cluster: ${BOLD}${CLUSTER_NAME}${RESET}"
echo

# ---------------------------------------------------------------------------
# Cluster
# ---------------------------------------------------------------------------

if k3d cluster list 2>/dev/null | awk 'NR>1 {print $1}' | grep -qx "${CLUSTER_NAME}"; then
    say "${DIM}cluster '${CLUSTER_NAME}' already exists — reusing${RESET}"
else
    say "creating k3d cluster '${CLUSTER_NAME}' (this is the only step that needs sudo on some systems)"
    k3d cluster create "${CLUSTER_NAME}" \
        --port "8080:80@loadbalancer" \
        --k3s-arg "--disable=traefik@server:0" \
        --wait
fi

KUBECONFIG_PATH="$(k3d kubeconfig write "${CLUSTER_NAME}")"
export KUBECONFIG="${KUBECONFIG_PATH}"

say "kubeconfig: ${DIM}${KUBECONFIG_PATH}${RESET}"
echo

# ---------------------------------------------------------------------------
# Namespaces
# ---------------------------------------------------------------------------

for ns in trustacks-system gitea argocd; do
    kubectl create namespace "${ns}" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
done

# ---------------------------------------------------------------------------
# Helm install — TruStacks stack
# ---------------------------------------------------------------------------
#
# The umbrella chart at charts/quickstart/ pulls in:
#   - control-plane + runner + UI (TruStacks)
#   - gitea  (subchart — in-cluster git provider)
#   - argo-cd (subchart — GitOps watcher)
#
# Production SaaS (post-Slice 22.5 / Slice 23) uses a different chart
# (multi-tenant CP, externalized secrets, GKE-shaped ingress, no UI
# deployment). Two charts, two audiences.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHART_DIR="${TRUSTACKS_QUICKSTART_DIR:-${SCRIPT_DIR}}/charts/quickstart"
[[ -d "${CHART_DIR}" ]] || die "missing chart directory: ${CHART_DIR}"

say "fetching Helm subchart dependencies (gitea + argo-cd)…"
helm dep update "${CHART_DIR}" >/dev/null

say "installing TruStacks chart at version ${BOLD}${VERSION}${RESET}…"
# All three images + the policy bundle pin to the same VERSION env var
# so a `TRUSTACKS_VERSION=0.1.2 ./bootstrap.sh` invocation gets a fully
# coherent release across both image families and the policy bundle.
# Default `latest` is fine for ad-hoc workshop runs.
POLICY_BUNDLE_REF="ghcr.io/trustacks/policy/constitution:${VERSION}"

helm upgrade --install trustacks "${CHART_DIR}" \
    --namespace trustacks-system --create-namespace \
    --set "image.controlPlane.tag=${VERSION}" \
    --set "image.runner.tag=${VERSION}" \
    --set "image.ui.tag=${VERSION}" \
    --set "policyBundle.bundleRef=${POLICY_BUNDLE_REF}" \
    --wait --timeout 5m

say "helm install complete"
echo

# ---------------------------------------------------------------------------
# Seed Gitea with sample repos
# ---------------------------------------------------------------------------
#
# The chart spun up an in-cluster Gitea instance (subchart). Workshop
# attendees use it as their git provider:
#   - 4 polyglot sample repos for /audit + /plan
#   - 1 empty platform repo for the agent's emitted PRs
# Idempotent — repos already present in Gitea are skipped.

GITEA_URL="${GITEA_URL:-http://gitea.localtest.me:8080}"
GITEA_USER="trustacks"
GITEA_PASS="trustacks-dev"
GITEA_ORG="${GITEA_USER}"

# Wait for Gitea to be reachable through the Traefik ingress. The Helm
# --wait above ensured the gitea Deployment is rolled out, but the
# ingress + DNS dance via *.localtest.me sometimes needs a few seconds
# more before HTTP responses succeed.
say "waiting for Gitea HTTP at ${GITEA_URL}…"
for attempt in {1..30}; do
    if curl -sf "${GITEA_URL}/api/v1/version" >/dev/null 2>&1; then
        break
    fi
    sleep 2
    if [[ ${attempt} -eq 30 ]]; then
        die "Gitea didn't come up at ${GITEA_URL} after 60s"
    fi
done

create_gitea_repo() {
    local name="$1"
    local exists
    exists=$(curl -sf -u "${GITEA_USER}:${GITEA_PASS}" \
        "${GITEA_URL}/api/v1/repos/${GITEA_ORG}/${name}" 2>/dev/null \
        | grep -o '"full_name"' || true)
    if [[ -n "${exists}" ]]; then
        say "  ${DIM}${name}: already exists, skipping${RESET}"
        return 0
    fi
    curl -sf -u "${GITEA_USER}:${GITEA_PASS}" \
        -H "Content-Type: application/json" \
        -X POST "${GITEA_URL}/api/v1/user/repos" \
        -d "{\"name\":\"${name}\",\"auto_init\":true,\"default_branch\":\"main\"}" >/dev/null
    say "  ${GREEN}${name}: created${RESET}"
}

push_sample_to_repo() {
    local sample_dir="$1"
    local repo_name
    repo_name="$(basename "${sample_dir}")"
    local push_url="http://${GITEA_USER}:${GITEA_PASS}@${GITEA_URL#http://}/${GITEA_ORG}/${repo_name}.git"
    local tmp
    tmp=$(mktemp -d)
    # Snapshot-push: copy sample tree into a temporary git repo and push
    # the initial main branch. If the gitea repo was auto-init'd with a
    # README we override via --force on first push to keep the script
    # idempotent across re-runs.
    cp -R "${sample_dir}/." "${tmp}/"
    (
        cd "${tmp}"
        git init -q -b main
        git config user.email "bootstrap@trustacks.local"
        git config user.name  "trustacks-bootstrap"
        git add -A
        git -c commit.gpgsign=false commit -q -m "Initial sample content from trustacks-quickstart"
        git push -q --force "${push_url}" main:main
    )
    rm -rf "${tmp}"
    say "  ${GREEN}${repo_name}: pushed${RESET}"
}

say "seeding Gitea repos under ${BOLD}${GITEA_ORG}/${RESET}…"
for sample_dir in "${SCRIPT_DIR}"/samples/*/; do
    sample_name="$(basename "${sample_dir}")"
    create_gitea_repo "${sample_name}"
    push_sample_to_repo "${sample_dir}"
done

# Empty platform repo — the DevOps Engineer agent commits the initial
# argo-apps/ + gitops/ tree on its first /plan run.
create_gitea_repo "trustacks-platform"
echo

# ---------------------------------------------------------------------------
# Register ArgoCD root Application
# ---------------------------------------------------------------------------
#
# Watches the platform repo's argo-apps/argo-apps-<cluster>/ path. As
# the agent emits per-service Application manifests there, ArgoCD picks
# them up and creates the per-service Applications described therein.
# Same App-of-Apps pattern as the mvp full install (scripts/seed_argocd.py).

say "registering ArgoCD root Application for the platform repo…"
# Wait for argocd-server's Application CRD to be available before
# applying. The Helm --wait completed the pod rollout but the CRD
# registration happens just after.
for attempt in {1..15}; do
    if kubectl get crd applications.argoproj.io >/dev/null 2>&1; then
        break
    fi
    sleep 2
    [[ ${attempt} -eq 15 ]] && die "ArgoCD Application CRD didn't register after 30s"
done

kubectl apply -n trustacks-system -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: trustacks-platform-root
  namespace: trustacks-system
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    # The in-cluster Gitea URL — ArgoCD pulls from here via the Kubernetes
    # service DNS, no public network needed.
    repoURL: http://trustacks-gitea-http.trustacks-system.svc.cluster.local:3000/${GITEA_ORG}/trustacks-platform.git
    targetRevision: HEAD
    path: argo-apps/argo-apps-${CLUSTER_NAME}/
    directory:
      recurse: true
  destination:
    server: https://kubernetes.default.svc
    namespace: trustacks-system
  syncPolicy:
    # Auto-sync the App-of-Apps so per-service Applications appear as
    # soon as the agent emits them. The per-service Applications they
    # create use manual sync (the agent's emit dictates), so the
    # customer still clicks Sync before code deploys.
    automated:
      prune: true
      selfHeal: false
EOF
say "ArgoCD root Application registered"
echo

# ---------------------------------------------------------------------------
# All done
# ---------------------------------------------------------------------------

cat <<EOF

${GREEN}${BOLD}TruStacks Quickstart ready.${RESET} (version ${VERSION}, cluster ${CLUSTER_NAME})

Next steps:

  1. Open the UI:        ${BOLD}http://ui.localtest.me:8080${RESET}
  2. Settings → LLM Provider: paste your Anthropic API key (BYO).
  3. /audit a sample repo (the four polyglot samples are pre-seeded
     in Gitea under ${BOLD}${GITEA_ORG}/${RESET} — fastapi-hello, spring-boot-hello,
     dotnet-hello, go-hello).
  4. /plan a proposal: watch the agent open a PR in the local Gitea:
     ${BOLD}${GITEA_URL}${RESET}    (user: ${GITEA_USER} / pass: ${GITEA_PASS})
  5. Merge the PR. ArgoCD picks it up + auto-syncs:
     ${BOLD}http://argocd.localtest.me:8080${RESET}

Cleanup when you're done:
  ${DIM}k3d cluster delete ${CLUSTER_NAME}${RESET}

Trouble?  https://trustacks.com/docs/workshop  ·  https://github.com/TruStacks/trustacks-quickstart/issues

Thanks for trying TruStacks. ${BOLD}Feedback shapes the Beta launch on 2026-07-27.${RESET}
EOF
