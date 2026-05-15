"""Minimal FastAPI hello-world for the TruStacks workshop quickstart.

The Code Reviewer agent fingerprints this repo as a Python/FastAPI
service; the DevOps Engineer agent emits a multi-stage Dockerfile +
GitHub Actions workflow + Helm chart + ArgoCD Application against it.
"""

from fastapi import FastAPI

app = FastAPI(title="hello")


@app.get("/")
def root() -> dict[str, str]:
    return {"message": "hello from TruStacks quickstart"}


@app.get("/healthz")
def healthz() -> dict[str, str]:
    return {"status": "ok"}
