#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "Usage: $0 <ubuntu-codename> <kubernetes-major.minor> <par-token-or-placeholder>" >&2
  echo "Example: $0 jammy 1.32 '<PAR>'" >&2
  exit 1
fi

ubuntu_codename="$1"
kubernetes_minor="$2"
par_token="$3"

case "$ubuntu_codename" in
  jammy|noble) ;;
  *)
    echo "Unsupported Ubuntu codename: $ubuntu_codename" >&2
    exit 1
    ;;
esac

if [[ ! "$kubernetes_minor" =~ ^1\.[0-9]+$ ]]; then
  echo "Unsupported Kubernetes minor version format: $kubernetes_minor" >&2
  exit 1
fi

echo "https://objectstorage.us-sanjose-1.oraclecloud.com/p/${par_token}/n/odx-oke/b/okn-repositories-private/o/prod/ubuntu-${ubuntu_codename}/kubernetes-${kubernetes_minor}"
