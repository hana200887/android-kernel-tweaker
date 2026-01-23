#!/system/bin/sh

apply_gpu_tweaks() {
  [ "$HAS_GPU_DEVFREQ" -eq 1 ] || { log_i "GPU: devfreq not detected; skipping"; return 0; }

  log_i "GPU: scanning devfreq nodes"
  for d in /sys/class/devfreq/*; do
    [ -d "$d" ] || continue
    gov="$d/governor"
    [ -e "$gov" ] || continue

    name="${d##*/}"
    case "$name" in
      *gpu*|*GPU*|*kgsl*|*KGSL*|*mali*|*Mali*|*adreno*|*Adreno*) : ;;
      *) continue ;;
    esac

    avail=""
    [ -e "$d/available_governors" ] && avail="$(read_node "$d/available_governors" 2>/dev/null)"
    cur="$(read_node "$gov")"
    cur="$(akt_trim_ws "$cur")"

    log_i "GPU: node=$name current_governor=$cur supported='$avail'"
    [ -n "$avail" ] && write_one_of "$gov" "msm-adreno-tz" "simple_ondemand" "bw_hwmon" "ondemand" "interactive"
  done
}
