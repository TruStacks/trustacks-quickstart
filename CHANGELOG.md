# Changelog — trustacks-quickstart

All notable changes to the install scripts + scaffold tracked here. The image versions the scaffold pulls are versioned independently in [`trustacks-mvp/docs/versioning.md`](https://github.com/TruStacks/trustacks-mvp/blob/main/docs/versioning.md); this changelog covers the install pipeline only.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- Initial scaffold (`install.sh`, `bootstrap.sh`, `helm/values-quickstart.yaml`, four polyglot samples, README, LICENSE, NOTICE).
- Curl-pipe-bash entry at `https://trustacks.app/install` (renders to this repo's `install.sh`).
- BYO LLM key flow via the UI's *Settings → LLM Provider* page (per `trustacks-mvp` Slice 23.6).
- Supply-chain verification command in the README (Sigstore keyless OIDC).

### Known limitations (Phase A1)

- The bootstrap script is a scaffold — it creates the cluster + namespaces and prints the URLs, but the Helm chart vendoring (`charts/quickstart/`) hasn't shipped yet. That's Candidate O **Phase A2** in the `trustacks-mvp` roadmap.
- Constitution Rego bundle currently lives in the runner image as a fallback; public OCI distribution (`ghcr.io/trustacks/policy/constitution:<version>`) is Phase A2 work.
- Multi-arch image pulls (amd64 + arm64) work on Apple Silicon + Intel Macs; Linux/x86 verified; Windows via WSL2 is best-effort.

[Unreleased]: https://github.com/TruStacks/trustacks-quickstart/compare/HEAD..HEAD
