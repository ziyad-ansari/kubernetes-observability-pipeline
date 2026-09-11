#!/usr/bin/env bash
set -euo pipefail
for cmd in aws terraform kubectl; do
  command -v "$cmd" >/dev/null || { echo "Missing command: $cmd" >&2; exit 1; }
done
aws sts get-caller-identity >/dev/null
echo "Prerequisites look good."
