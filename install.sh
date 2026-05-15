#!/usr/bin/env bash
#
# TruStacks Quickstart — one-line installer.
#
# Pulled by curl-pipe-bash from https://trustacks.com/install. Use:
#
#     curl -fsSL https://trustacks.com/install | bash
#
# What this script does (transparent + small enough to read):
#
#   1. Validates that the host has the prerequisite CLIs installed
#      (docker, k3d, kubectl, helm). Prints install hints if missing.
#   2. Clones the trustacks-quickstart repo to a temp directory.
#   3. Hands off to ./bootstrap.sh, which does the real work of
#      creating the k3d cluster + installing Helm releases pointing
#      at the public GHCR images (ghcr.io/trustacks/control-plane,
#      runner, ui).
#
# Why it's small: curl-pipe-bash is a known anti-pattern from a
# security POV — the script can do anything before the user reviews
# it. Keeping this entry script lean (validate deps + clone +
# delegate) means a security-conscious user can audit it on
# trustacks-quickstart's main branch before running. The substantive
# logic lives in bootstrap.sh, which they can inspect in the cloned
# repo before executing.
#
# Source: https://github.com/TruStacks/trustacks-quickstart
# EULA (governs the images this script pulls):
#   https://trustacks.com/eula
# Trademark policy:
#   https://github.com/TruStacks/trustacks-policy/blob/main/TRADEMARK.md

set -euo pipefail

# ---------------------------------------------------------------------------
# Cosmetics
# ---------------------------------------------------------------------------

if [[ -t 1 ]]; then
    BOLD=$'\033[1m'
    DIM=$'\033[2m'
    GREEN=$'\033[32m'
    RED=$'\033[31m'
    YELLOW=$'\033[33m'
    RESET=$'\033[0m'
else
    BOLD="" DIM="" GREEN="" RED="" YELLOW="" RESET=""
fi

say()  { printf '%s\n' "${BOLD}[trustacks-quickstart]${RESET} $*"; }
warn() { printf '%s %s\n' "${YELLOW}[warn]${RESET}" "$*" >&2; }
die()  { printf '%s %s\n' "${RED}[fail]${RESET}" "$*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Banner
# ---------------------------------------------------------------------------

cat <<'BANNER'
   _____            ___ _             _
  |_   _| _ _  _ __| __| |_ __ _ __ _| |__ ___
    | || '_| || (_-< _||  _/ _` / _| | / /(_-<
    |_||_|  \_,_/__/___/ \__\__,_\__|_\_\/__/

  Workshop quickstart — local k3d sandbox.
  Production: GKE-hosted SaaS (coming July 27, 2026).

BANNER

say "Welcome. This installer will:"
say "  1. Validate your local CLIs (docker, k3d, kubectl, helm)."
say "  2. Clone the trustacks-quickstart repo to a temp directory."
say "  3. Hand off to bootstrap.sh to create the cluster + install TruStacks."
say "  4. Print URLs you can open in your browser when it's ready."
echo
say "By proceeding you accept the TruStacks End-User License Agreement:"
say "  ${DIM}https://trustacks.com/eula${RESET}"
echo

# ---------------------------------------------------------------------------
# Prerequisites
# ---------------------------------------------------------------------------

require() {
    local bin="$1"
    local hint="$2"
    if ! command -v "${bin}" >/dev/null 2>&1; then
        warn "missing prerequisite: ${BOLD}${bin}${RESET}"
        printf '%s        install: %s\n' "${DIM}" "${hint}${RESET}"
        return 1
    fi
    return 0
}

missing=0
require docker  "https://docs.docker.com/get-docker/"                   || missing=$((missing + 1))
require k3d     "brew install k3d  ·  https://k3d.io/#installation"     || missing=$((missing + 1))
require kubectl "brew install kubectl  ·  https://kubernetes.io/docs/tasks/tools/" || missing=$((missing + 1))
require helm    "brew install helm  ·  https://helm.sh/docs/intro/install/"        || missing=$((missing + 1))

if [[ ${missing} -gt 0 ]]; then
    die "${missing} prerequisite(s) missing. Install them and re-run ${BOLD}curl -fsSL https://trustacks.com/install | bash${RESET}."
fi

if ! docker info >/dev/null 2>&1; then
    die "docker is installed but not running. Start Docker Desktop (or your daemon of choice) and re-run."
fi

say "${GREEN}prerequisites OK${RESET}"
echo

# ---------------------------------------------------------------------------
# Clone + delegate
# ---------------------------------------------------------------------------

CLONE_DIR="${TRUSTACKS_QUICKSTART_DIR:-${TMPDIR:-/tmp}/trustacks-quickstart-$(date +%s)}"
REPO_URL="${TRUSTACKS_QUICKSTART_REPO:-https://github.com/TruStacks/trustacks-quickstart.git}"
REPO_REF="${TRUSTACKS_QUICKSTART_REF:-main}"

say "cloning ${REPO_URL} (${REPO_REF}) → ${CLONE_DIR}"
git clone --depth 1 --branch "${REPO_REF}" "${REPO_URL}" "${CLONE_DIR}" >/dev/null 2>&1 \
    || die "git clone failed. Network blocked? Wrong ref? Try cloning manually: git clone ${REPO_URL}"

say "${GREEN}clone OK${RESET}"
echo

say "handing off to ${BOLD}bootstrap.sh${RESET} — substantive logic lives there; auditable in the cloned repo."
echo

cd "${CLONE_DIR}"
exec bash ./bootstrap.sh "$@"
