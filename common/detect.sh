#!/system/bin/sh

MEM_TOTAL_MB=0
MEM_CLASS="unknown"
HAS_CPUFREQ=0
HAS_GPU_DEVFREQ=0
HAS_UCLAMP=0
HAS_ZSWAP=0
HAS_ZRAM=0
HAS_MGLRU=0

# Pure-sh cgroup-v2 uclamp probe (no find/head)
_has_cgv2_uclamp() {
  [ -d /sys/fs/cgroup ] || return 1

  # direct
  [ -e /sys/fs/cgroup/cpu.uclamp.max ] && return 0

  # depth 1..4
  for a in /sys/fs/cgroup/*; do
    [ -d "$a" ] || continue
    [ -e "$a/cpu.uclamp.max" ] && return 0

    for b in "$a"/*; do
      [ -d "$b" ] || continue
      [ -e "$b/cpu.uclamp.max" ] && return 0

      for c in "$b"/*; do
        [ -d "$c" ] || continue
        [ -e "$c/cpu.uclamp.max" ] && return 0

        for d in "$c"/*; do
          [ -d "$d" ] || continue
          [ -e "$d/cpu.uclamp.max" ] && return 0
        done
      done
    done
  done

  return 1
}

detect_platform() {
  MEM_TOTAL_MB="$(get_mem_total_mb)"
  case "$MEM_TOTAL_MB" in ""|*[!0-9]*) MEM_TOTAL_MB=0 ;; esac

  # IMPORTANT: If detection failed, do NOT misclassify as "small"
  if [ "$MEM_TOTAL_MB" -le 0 ]; then
    MEM_CLASS="unknown"
    log_w "Detected: MEM_TOTAL_MB=0 (RAM detection failed) -> MEM_CLASS=unknown"
  elif [ "$MEM_TOTAL_MB" -le 4096 ]; then
    MEM_CLASS="small"
  elif [ "$MEM_TOTAL_MB" -le 8192 ]; then
    MEM_CLASS="medium"
  else
    MEM_CLASS="large"
  fi

  [ -d /sys/devices/system/cpu/cpufreq ] && HAS_CPUFREQ=1
  [ -d /sys/class/devfreq ] && HAS_GPU_DEVFREQ=1

  if [ -e /dev/stune/top-app/uclamp.max ] || [ -e /dev/cpuset/top-app/uclamp.max ] || _has_cgv2_uclamp; then
    HAS_UCLAMP=1
  fi

  [ -d /sys/module/zswap ] && HAS_ZSWAP=1
  [ -d /sys/block/zram0 ] && HAS_ZRAM=1
  [ -d /sys/kernel/mm/lru_gen ] && HAS_MGLRU=1

  log_i "Detected: MEM_TOTAL_MB=$MEM_TOTAL_MB MEM_CLASS=$MEM_CLASS"
  log_i "Detected: CPUFREQ=$HAS_CPUFREQ GPU_DEVFREQ=$HAS_GPU_DEVFREQ UCLAMP=$HAS_UCLAMP"
  log_i "Detected: ZSWAP=$HAS_ZSWAP ZRAM=$HAS_ZRAM MGLRU=$HAS_MGLRU"
}
