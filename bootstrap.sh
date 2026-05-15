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
# v1 simplification: the quickstart uses a single all-in-one Helm
# release per service, with Helm values overridden by
# helm/values-quickstart.yaml in this repo. The production hosting
# path (GKE per-customer) uses different charts authored by John's
# Slice 22.5 + Slice 23 work; we deliberately separate the two.

VALUES_FILE="${TRUSTACKS_QUICKSTART_DIR:-.}/helm/values-quickstart.yaml"
if [[ ! -f "${VALUES_FILE}" ]]; then
    # Script was launched directly (not via install.sh handoff); fall
    # back to the values file relative to the script's location.
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    VALUES_FILE="${SCRIPT_DIR}/helm/values-quickstart.yaml"
fi
[[ -f "${VALUES_FILE}" ]] || die "missing values file: ${VALUES_FILE}"

say "installing TruStacks (control-plane, runner, ui)…"
say "   ${DIM}helm install \\${RESET}"
say "   ${DIM}    --namespace trustacks-system \\${RESET}"
say "   ${DIM}    --set image.controlPlane=${CP_IMAGE} \\${RESET}"
say "   ${DIM}    --set image.runner=${RUNNER_IMAGE} \\${RESET}"
say "   ${DIM}    --set image.ui=${UI_IMAGE} \\${RESET}"
say "   ${DIM}    -f ${VALUES_FILE}${RESET}"

# TODO(candidate-O-phase-A2): the actual Helm chart bundle for the
# quickstart distribution isn't packaged yet. The trustacks-mvp
# `charts/runner/` chart is the seed; quickstart vendors a slim copy
# tuned for single-node k3d. When Phase A2 ships, this script switches
# to:
#   helm upgrade --install trustacks ./charts/quickstart \
#       --namespace trustacks-system \
#       --set image.controlPlane="${CP_IMAGE}" \
#       --set image.runner="${RUNNER_IMAGE}" \
#       --set image.ui="${UI_IMAGE}" \
#       -f "${VALUES_FILE}"
warn "Phase A2 stub: Helm chart vendoring not yet wired. See README for status."
echo

# ---------------------------------------------------------------------------
# URLs to open
# ---------------------------------------------------------------------------

cat <<EOF

${GREEN}${BOLD}TruStacks Quickstart bootstrap complete (scaffold).${RESET}

Next steps once Phase A2 ships the Helm bundle:

  1. Open the UI:        ${BOLD}http://ui.localtest.me:8080${RESET}
  2. Settings → LLM Provider: paste your Anthropic API key.
  3. /audit a sample repo, /plan a proposal, watch the PR open
     in the local Gitea at:    ${BOLD}http://gitea.localtest.me:8080${RESET}
  4. ArgoCD watcher at:        ${BOLD}http://argocd.localtest.me:8080${RESET}

Cleanup when you're done:
  ${DIM}k3d cluster delete ${CLUSTER_NAME}${RESET}

Trouble?  https://trustacks.com/docs/workshop  ·  https://github.com/TruStacks/trustacks-quickstart/issues

Thanks for trying TruStacks. ${BOLD}Feedback shapes the Beta launch on 2026-07-27.${RESET}
EOF
