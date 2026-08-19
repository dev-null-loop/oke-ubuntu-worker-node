#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <kubernetes-full-version>" >&2
  echo "Example: $0 1.32.10" >&2
  exit 1
fi

kubernetes_version="$1"

if [[ ! "$kubernetes_version" =~ ^1\.[0-9]+\.[0-9]+$ ]]; then
  echo "Unsupported Kubernetes version format: $kubernetes_version" >&2
  exit 1
fi

echo "oci-oke-node-all-${kubernetes_version}"
