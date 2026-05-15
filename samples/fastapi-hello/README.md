# fastapi-hello

Minimal FastAPI service for the TruStacks quickstart workshop. The Code Reviewer agent identifies this as a Python/FastAPI service; the DevOps Engineer emits CI + Helm + ArgoCD against it when you run `/plan`.

Run locally:

```sh
uvicorn src.app:app --reload
curl http://localhost:8000/
```

## License

Apache License 2.0 — fork it freely. See [`../../LICENSE`](../../LICENSE).
