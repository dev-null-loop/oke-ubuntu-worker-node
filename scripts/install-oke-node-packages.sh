#!/usr/bin/env bash
set -euo pipefail

: "${APT_SOURCE_URL:?APT_SOURCE_URL is required}"
: "${OKE_PACKAGE_NAME:?OKE_PACKAGE_NAME is required}"

disable_unattended="${DISABLE_UNATTENDED_UPGRADES:-true}"
install_helper_packages="${INSTALL_HELPER_PACKAGES:-true}"
helper_packages_csv="${HELPER_PACKAGES:-jq,curl,crictl}"
enable_image_prepull="${ENABLE_IMAGE_PREPULL:-false}"
prepull_failure_fatal="${PREPULL_FAILURE_FATAL:-false}"
enable_boot_cri_runtime="${ENABLE_BOOT_CRI_RUNTIME:-true}"
prepull_images_csv="${PREPULL_IMAGES:-}"

stop_apt_background_jobs() {
  sudo systemctl stop apt-daily.service apt-daily-upgrade.service 2>/dev/null || true
  sudo systemctl stop apt-daily.timer apt-daily-upgrade.timer 2>/dev/null || true
}

install_bootstrap_timing_monitor() {
  sudo install -d -m 0755 /usr/local/bin /var/lib/oke-optimization

  sudo tee /usr/local/bin/oke-bootstrap-timing-monitor.sh >/dev/null <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

log_file="/var/log/oke-optimized-bootstrap-timing.log"
marker_dir="/var/lib/oke-optimization"
timeout_seconds=2700
poll_interval=2

mkdir -p "$marker_dir"
touch "$log_file"

mark() {
  local event="$1"
  printf '%s epoch=%s uptime=%s event=%s\n' \
    "$(date --iso-8601=seconds)" \
    "$(date +%s)" \
    "$(cut -d' ' -f1 /proc/uptime)" \
    "$event" | tee -a "$log_file"
  touch "$marker_dir/$event"
}

get_prop() {
  local unit="$1"
  local prop="$2"
  systemctl show "$unit" -p "$prop" --value 2>/dev/null || true
}

mark monitor-start

deadline=$(( $(date +%s) + timeout_seconds ))
oke_start_marked=false
oke_end_marked=false
kubelet_marked=false
cri_marked=false

while (( $(date +%s) < deadline )); do
  if [[ "$cri_marked" == "false" ]] && systemctl is-active --quiet crio.service; then
    mark cri-runtime-active
    cri_marked=true
  fi

  if [[ "$oke_start_marked" == "false" ]]; then
    oke_start="$(get_prop oke.service ExecMainStartTimestampMonotonic)"
    if [[ -n "$oke_start" && "$oke_start" != "0" ]]; then
      mark oke-installer-start
      oke_start_marked=true
    fi
  fi

  if [[ "$oke_end_marked" == "false" ]]; then
    oke_end="$(get_prop oke.service ExecMainExitTimestampMonotonic)"
    if [[ -n "$oke_end" && "$oke_end" != "0" ]]; then
      mark oke-installer-end
      oke_end_marked=true
    fi
  fi

  if [[ "$kubelet_marked" == "false" ]] && systemctl is-active --quiet kubelet; then
    mark kubelet-active
    kubelet_marked=true
    break
  fi

  sleep "$poll_interval"
done

if [[ "$kubelet_marked" == "false" ]]; then
  mark monitor-timeout
fi
EOF
  sudo chmod 0755 /usr/local/bin/oke-bootstrap-timing-monitor.sh

  sudo tee /etc/systemd/system/oke-bootstrap-timing-monitor.service >/dev/null <<'EOF'
[Unit]
Description=OKE bootstrap timing monitor
DefaultDependencies=yes
After=network-online.target
Wants=network-online.target
Before=oke.service kubelet.service

[Service]
Type=simple
ExecStart=/usr/local/bin/oke-bootstrap-timing-monitor.sh

[Install]
WantedBy=multi-user.target
EOF

  sudo systemctl daemon-reload
  sudo systemctl enable oke-bootstrap-timing-monitor.service
}

prepare_cni_host_paths() {
  sudo install -d -m 0755 /opt/cni/bin /etc/cni/net.d /etc/oci-cni
  sudo touch /run/xtables.lock
}

get_cri_runtime_endpoint() {
  local candidate
  for candidate in \
    /var/run/crio/crio.sock \
    /run/crio/crio.sock \
    /run/containerd/containerd.sock
  do
    if [[ -S "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

get_cri_service_name() {
  local unit
  for unit in crio.service containerd.service cri-o.service; do
    if systemctl list-unit-files "$unit" --no-legend 2>/dev/null | grep -q "^$unit"; then
      printf '%s\n' "$unit"
      return 0
    fi
  done
  return 1
}

ensure_cri_runtime_for_prepull() {
  local service_name
  sudo systemctl daemon-reload || true

  if ! service_name="$(get_cri_service_name)"; then
    echo "No supported CRI service found for image pre-pull" >&2
    systemctl list-unit-files --type=service | grep -E 'cri|containerd' || true
    return 1
  fi

  if ! sudo systemctl enable --now "$service_name"; then
    echo "Failed to start ${service_name} for image pre-pull" >&2
    sudo systemctl status "$service_name" --no-pager || true
    sudo journalctl -u "$service_name" -n 200 --no-pager || true
    return 1
  fi

  local waited=0
  local max_wait=120
  while (( waited < max_wait )); do
    if get_cri_runtime_endpoint >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
    waited=$((waited + 2))
  done

  echo "Timed out waiting for CRI runtime socket" >&2
  sudo systemctl status "$service_name" --no-pager || true
  sudo journalctl -u "$service_name" -n 200 --no-pager || true
  return 1
}

configure_boot_cri_runtime() {
  [[ "$enable_boot_cri_runtime" == "true" ]] || return 0

  local service_name
  if ! service_name="$(get_cri_service_name)"; then
    echo "No supported CRI service found to enable for boot optimization" >&2
    return 0
  fi

  echo "Enabling ${service_name} for earlier boot-time runtime startup"
  sudo systemctl enable "$service_name" || true
}

prepull_container_images() {
  [[ "$enable_image_prepull" == "true" ]] || return 0
  [[ -n "$prepull_images_csv" ]] || return 0

  if ! command -v crictl >/dev/null 2>&1; then
    echo "enable_image_prepull=true requires crictl in the image" >&2
    return 1
  fi

  if ! ensure_cri_runtime_for_prepull; then
    if [[ "$prepull_failure_fatal" == "true" ]]; then
      return 1
    fi
    echo "Continuing without image pre-pull because runtime startup failed." >&2
    return 0
  fi

  local runtime_endpoint
  runtime_endpoint="$(get_cri_runtime_endpoint)"
  echo "Using CRI runtime endpoint: ${runtime_endpoint}"

  IFS=',' read -r -a prepull_images <<<"$prepull_images_csv"
  for image in "${prepull_images[@]}"; do
    [[ -n "$image" ]] || continue
    echo "Pre-pulling image: ${image}"
    sudo crictl --runtime-endpoint="$runtime_endpoint" pull "$image"
  done

  echo "Verifying pre-pulled images..."
  sudo crictl --runtime-endpoint="$runtime_endpoint" images

  local service_name
  if service_name="$(get_cri_service_name)"; then
    sudo systemctl stop "$service_name" || true
  fi
}

install_helper_packages_if_needed() {
  [[ "$install_helper_packages" == "true" ]] || return 0
  [[ -n "$helper_packages_csv" ]] || return 0

  IFS=',' read -r -a helper_packages <<<"$helper_packages_csv"
  if (( ${#helper_packages[@]} == 0 )); then
    return 0
  fi

  local missing_packages=()
  local pkg
  for pkg in "${helper_packages[@]}"; do
    [[ -n "$pkg" ]] || continue
    if ! dpkg-query -W -f='${Status}\n' "$pkg" 2>/dev/null | grep -q "install ok installed"; then
      missing_packages+=("$pkg")
    fi
  done

  if (( ${#missing_packages[@]} == 0 )); then
    echo "Helper packages already present: ${helper_packages[*]}"
    return 0
  fi

  echo "Installing missing helper packages: ${missing_packages[*]}"
  wait_for_apt_locks
  sudo apt-get install -y --no-upgrade "${missing_packages[@]}"
}

install_prepull_runtime_dependencies() {
  [[ "$enable_image_prepull" == "true" ]] || return 0

  local runtime_dependencies=()

  if ! command -v crun >/dev/null 2>&1; then
    runtime_dependencies+=("crun")
  fi

  if (( ${#runtime_dependencies[@]} == 0 )); then
    return 0
  fi

  echo "Installing missing pre-pull runtime dependencies: ${runtime_dependencies[*]}"
  wait_for_apt_locks
  sudo apt-get install -y --no-upgrade "${runtime_dependencies[@]}"
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

prepare_cni_host_paths

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
sudo systemctl daemon-reload || true
install_helper_packages_if_needed
install_prepull_runtime_dependencies

sudo systemctl enable oke.service || true
configure_boot_cri_runtime
prepull_container_images
install_bootstrap_timing_monitor
sanitize_guest_state

echo "Installed ${OKE_PACKAGE_NAME}"
echo "Configured apt source: ${APT_SOURCE_URL}"
