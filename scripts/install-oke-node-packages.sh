#!/usr/bin/env bash
set -euo pipefail

: "${APT_SOURCE_URL:?APT_SOURCE_URL is required}"
: "${OKE_PACKAGE_NAME:?OKE_PACKAGE_NAME is required}"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/lib/common.sh"
source "${script_dir}/lib/timing-monitor.sh"
source "${script_dir}/lib/prepull.sh"

readonly expected_os_id="ubuntu"
readonly debian_frontend="noninteractive"
readonly oke_apt_source_path="/etc/apt/sources.list.d/oke-node-client.sources"
readonly helper_packages=(
  jq
  curl
  crictl
)
helper_packages_csv="$(IFS=,; echo "${helper_packages[*]}")"
prepull_images_csv="${PREPULL_IMAGES:-}"

load_os_release() {
  local os_release_path="/etc/os-release"
  if [[ ! -f "$os_release_path" ]]; then
    echo "${os_release_path} is missing" >&2
    exit 1
  fi
  . "$os_release_path"
}

assert_ubuntu_base_image() {
  if [[ "${ID:-}" != "$expected_os_id" ]]; then
    echo "Expected an Ubuntu base image, found ID=${ID:-unknown}" >&2
    exit 1
  fi
}

install_oke_apt_source() {
  sudo mkdir -p "$(dirname "$oke_apt_source_path")"
  sudo tee "$oke_apt_source_path" >/dev/null <<EOF
Enabled: yes
Types: deb
URIs: ${APT_SOURCE_URL}
Suites: stable
Components: main
Trusted: yes
EOF
}

disable_unattended_upgrades() {
  wait_for_apt_locks
  sudo apt-get remove -y unattended-upgrades || true
  sudo systemctl disable --now unattended-upgrades 2>/dev/null || true
}

load_os_release
assert_ubuntu_base_image

stop_apt_background_jobs
wait_for_apt_locks

prepare_cni_host_paths
disable_wait_online_services
install_oke_apt_source
disable_unattended_upgrades

export DEBIAN_FRONTEND="$debian_frontend"
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
