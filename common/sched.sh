#!/system/bin/sh
# Scheduler/kernel knobs (conservative, avoids risky latency hacks)

apply_sched_tweaks() {
  log_i "SCHED: applying conservative scheduler/sysctl tweaks"

  # Disable autogrouping if present (often irrelevant on Android)
  set_sysctl "kernel/sched_autogroup_enabled" "0"

  # Prefer child-runs-first if present (safe micro-optimization)
  set_sysctl "kernel/sched_child_runs_first" "1"

  # Limit perf events CPU time overhead if node exists
  set_sysctl "kernel/perf_cpu_time_max_percent" "10"

  # Disable schedstats if present (reduce overhead, harmless)
  set_sysctl "kernel/sched_schedstats" "0"

  # Timer migration sometimes adds jitter on some devices; only if exposed
  set_sysctl "kernel/timer_migration" "0"
}
