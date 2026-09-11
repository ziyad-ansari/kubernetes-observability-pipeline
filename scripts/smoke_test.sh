#!/usr/bin/env bash
set -euo pipefail
NS=observability
kubectl -n "$NS" rollout status deployment/vector --timeout=180s
kubectl -n "$NS" get pods -o wide
kubectl -n "$NS" logs deployment/vector --since=2m | tail -n 40
