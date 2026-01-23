#!/system/bin/sh
# Power related knobs (safe)

apply_power_tweaks() {
  log_i "POWER: applying safe power knobs"

  # Workqueue power efficiency (safe; may improve battery)
  write_node_if_exists "/sys/module/workqueue/parameters/power_efficient" "1"

  # Some kernels expose scheduler boost knobs; do not force if unknown.
  # We keep default behavior to avoid UI regressions.
}
