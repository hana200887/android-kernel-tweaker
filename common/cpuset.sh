#!/system/bin/sh

_apply_uclamp_nodes() {
  grp="$1"
  maxv="$2"
  minv="$3"
  boosted="$4"
  lat="$5"

  [ -d "$grp" ] || return 0

  maxn=""
  minn=""

  if [ -e "$grp/uclamp.max" ] || [ -e "$grp/uclamp.min" ]; then
    maxn="$grp/uclamp.max"
    minn="$grp/uclamp.min"
  elif [ -e "$grp/cpu.uclamp.max" ] || [ -e "$grp/cpu.uclamp.min" ]; then
    maxn="$grp/cpu.uclamp.max"
    minn="$grp/cpu.uclamp.min"
  fi

  case "$maxv" in max) maxv="1024" ;; esac

  [ -n "$maxn" ] && write_node_if_exists "$maxn" "$maxv"
  [ -n "$minn" ] && write_node_if_exists "$minn" "$minv"
  write_node_if_exists "$grp/uclamp.boosted" "$boosted"
  write_node_if_exists "$grp/uclamp.latency_sensitive" "$lat"
}

_cg_find_group() {
  g="$1"
  [ -d "/sys/fs/cgroup/$g" ] && { echo "/sys/fs/cgroup/$g"; return 0; }

  for a in /sys/fs/cgroup/*; do
    [ -d "$a" ] || continue
    [ -d "$a/$g" ] && { echo "$a/$g"; return 0; }

    for b in "$a"/*; do
      [ -d "$b" ] || continue
      [ -d "$b/$g" ] && { echo "$b/$g"; return 0; }

      for c in "$b"/*; do
        [ -d "$c" ] || continue
        [ -d "$c/$g" ] && { echo "$c/$g"; return 0; }

        for d in "$c"/*; do
          [ -d "$d" ] || continue
          [ -d "$d/$g" ] && { echo "$d/$g"; return 0; }
        done
      done
    done
  done

  return 1
}

_apply_uclamp_group_all_bases() {
  g="$1"
  maxv="$2"
  minv="$3"
  boosted="$4"
  lat="$5"

  [ -d "/dev/stune/$g" ] && _apply_uclamp_nodes "/dev/stune/$g" "$maxv" "$minv" "$boosted" "$lat"
  [ -d "/dev/cpuset/$g" ] && _apply_uclamp_nodes "/dev/cpuset/$g" "$maxv" "$minv" "$boosted" "$lat"

  cg="$(_cg_find_group "$g" 2>/dev/null)"
  [ -n "$cg" ] && _apply_uclamp_nodes "$cg" "$maxv" "$minv" "$boosted" "$lat"
}

apply_cpuset_uclamp_tweaks() {
  [ "$HAS_UCLAMP" -eq 1 ] || { log_i "UCLAMP: not detected; skipping"; return 0; }
  log_i "UCLAMP: applying one-shot group clamps"

  _apply_uclamp_group_all_bases "top-app" "1024" "128" "1" "1"
  _apply_uclamp_group_all_bases "foreground" "896" "0" "0" "0"
  _apply_uclamp_group_all_bases "background" "384" "0" "0" "0"
  _apply_uclamp_group_all_bases "system-background" "320" "0" "0" "0"

  set_sysctl "kernel/sched_util_clamp_min_rt_default" "0"
  set_sysctl "kernel/sched_util_clamp_min" "128"
}
