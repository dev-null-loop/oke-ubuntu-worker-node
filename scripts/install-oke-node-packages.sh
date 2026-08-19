#!/usr/bin/env bash
set -euo pipefail

: "${APT_SOURCE_URL:?APT_SOURCE_URL is required}"
: "${OKE_PACKAGE_NAME:?OKE_PACKAGE_NAME is required}"

disable_unattended="${DISABLE_UNATTENDED_UPGRADES:-true}"

stop_apt_background_jobs() {
  sudo systemctl stop apt-daily.service apt-daily-upgrade.service 2>/dev/null || true
  sudo systemctl stop apt-daily.timer apt-daily-upgrade.timer 2>/dev/null || true
}

wait_for_apt_locks() {
  local waited=0
  local max_wait=600

  while sudo fuser /var/lib/dpkg/lock-frontend \
                   /var/lib/dpkg/lock \
                   /var/lib/apt/lists/lock \
                   /var/cache/apt/archives/lock >/dev/null 2>&1; do
    if (( waited == 0 || waited % 30 == 0 )); then
      echo "Waiting for apt/dpkg locks to clear (${waited}s elapsed)..."
      sudo fuser -v /var/lib/dpkg/lock-frontend \
                    /var/lib/dpkg/lock \
                    /var/lib/apt/lists/lock \
                    /var/cache/apt/archives/lock 2>/dev/null || true
    fi
    if (( waited >= max_wait )); then
      echo "Timed out waiting for apt/dpkg locks to clear" >&2
      return 1
    fi
    sleep 5
    waited=$((waited + 5))
  done
}

if [[ -f /etc/os-release ]]; then
  . /etc/os-release
else
  echo "/etc/os-release is missing" >&2
  exit 1
fi

if [[ "${ID:-}" != "ubuntu" ]]; then
  echo "Expected an Ubuntu base image, found ID=${ID:-unknown}" >&2
  exit 1
fi

stop_apt_background_jobs
wait_for_apt_locks

sudo mkdir -p /etc/apt/sources.list.d
sudo tee /etc/apt/sources.list.d/oke-node-client.sources >/dev/null <<EOF
Enabled: yes
Types: deb
URIs: ${APT_SOURCE_URL}
Suites: stable
Components: main
Trusted: yes
EOF

if [[ "$disable_unattended" == "true" ]]; then
  wait_for_apt_locks
  sudo apt-get remove -y unattended-upgrades || true
  sudo systemctl disable --now unattended-upgrades 2>/dev/null || true
fi

export DEBIAN_FRONTEND=noninteractive
wait_for_apt_locks
sudo apt-get update
wait_for_apt_locks
sudo apt-get install -y "${OKE_PACKAGE_NAME}"

sudo systemctl enable oke.service || true

echo "Installed ${OKE_PACKAGE_NAME}"
echo "Configured apt source: ${APT_SOURCE_URL}"
