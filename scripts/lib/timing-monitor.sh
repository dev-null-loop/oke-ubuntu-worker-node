#!/usr/bin/env bash

readonly timing_monitor_script_path="/usr/local/bin/oke-bootstrap-timing-monitor.sh"
readonly timing_monitor_unit_path="/etc/systemd/system/oke-bootstrap-timing-monitor.service"
readonly timing_monitor_state_directory="/var/lib/oke-optimization"

install_bootstrap_timing_monitor() {
  sudo install -d -m 0755 /usr/local/bin "$timing_monitor_state_directory"

  sudo tee "$timing_monitor_script_path" >/dev/null <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

readonly log_file="/var/log/oke-optimized-bootstrap-timing.log"
readonly marker_dir="/var/lib/oke-optimization"
readonly timeout_seconds=2700
readonly poll_interval=2

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
  sudo chmod 0755 "$timing_monitor_script_path"

  sudo tee "$timing_monitor_unit_path" >/dev/null <<EOF
[Unit]
Description=OKE bootstrap timing monitor
DefaultDependencies=yes
After=basic.target
Before=network-online.target oke.service kubelet.service

[Service]
Type=simple
ExecStart=${timing_monitor_script_path}

[Install]
WantedBy=multi-user.target
EOF

  sudo systemctl daemon-reload
  sudo systemctl enable oke-bootstrap-timing-monitor.service
}
