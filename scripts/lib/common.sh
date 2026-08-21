#!/usr/bin/env bash

readonly apt_lock_files=(
  /var/lib/dpkg/lock-frontend
  /var/lib/dpkg/lock
  /var/lib/apt/lists/lock
  /var/cache/apt/archives/lock
)
readonly apt_background_units=(
  apt-daily.service
  apt-daily-upgrade.service
)
readonly apt_background_timers=(
  apt-daily.timer
  apt-daily-upgrade.timer
)
readonly wait_online_units=(
  systemd-networkd-wait-online.service
  NetworkManager-wait-online.service
)
readonly cni_host_directories=(
  /opt/cni/bin
  /etc/cni/net.d
  /etc/oci-cni
)

stop_apt_background_jobs() {
  sudo systemctl stop "${apt_background_units[@]}" 2>/dev/null || true
  sudo systemctl stop "${apt_background_timers[@]}" 2>/dev/null || true
}

wait_for_apt_locks() {
  local waited=0
  local max_wait=600

  while sudo fuser "${apt_lock_files[@]}" >/dev/null 2>&1; do
    if (( waited == 0 || waited % 30 == 0 )); then
      echo "Waiting for apt/dpkg locks to clear (${waited}s elapsed)..."
      sudo fuser -v "${apt_lock_files[@]}" 2>/dev/null || true
    fi
    if (( waited >= max_wait )); then
      echo "Timed out waiting for apt/dpkg locks to clear" >&2
      return 1
    fi
    sleep 5
    waited=$((waited + 5))
  done
}

prepare_cni_host_paths() {
  sudo install -d -m 0755 "${cni_host_directories[@]}"
  sudo touch /run/xtables.lock
}

disable_wait_online_services() {
  local unit

  for unit in "${wait_online_units[@]}"; do
    if systemctl list-unit-files "$unit" --no-legend 2>/dev/null | grep -q "^$unit"; then
      echo "Masking ${unit} to avoid boot-time wait-online delays"
      sudo systemctl disable --now "$unit" 2>/dev/null || true
      sudo systemctl mask "$unit" || true
    fi
  done
}

sanitize_guest_state() {
  echo "Sanitizing guest state before image capture..."

  stop_apt_background_jobs
  wait_for_apt_locks

  sudo apt-get clean
  sudo rm -rf /var/lib/apt/lists/*
  sudo rm -rf /tmp/* /var/tmp/*

  # Reset cloud-init instance state so cloned nodes re-run first-boot logic.
  if command -v cloud-init >/dev/null 2>&1; then
    sudo cloud-init clean --logs || true
  fi
  sudo rm -rf /var/lib/cloud/instance \
              /var/lib/cloud/instances/*

  # Clear machine identity so future boots regenerate per-instance values.
  sudo truncate -s 0 /etc/machine-id
  if [[ -f /var/lib/dbus/machine-id ]]; then
    sudo truncate -s 0 /var/lib/dbus/machine-id
  fi

  sudo find /var/log -type f -exec truncate -s 0 {} \; 2>/dev/null || true
}
