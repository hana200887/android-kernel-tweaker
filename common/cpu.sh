#!/system/bin/sh

apply_cpu_tweaks() {
  [ "$HAS_CPUFREQ" -eq 1 ] || { log_i "CPU: cpufreq not detected; skipping"; return 0; }

  log_i "CPU: applying governor selection + schedutil tuning (oneshot=ON profile)"
  for pol in /sys/devices/system/cpu/cpufreq/policy*; do
    [ -d "$pol" ] || continue

    gov_node="$pol/scaling_governor"
    avail_node="$pol/scaling_available_governors"
    [ -e "$gov_node" ] || continue

    avail=""
    [ -e "$avail_node" ] && avail="$(read_node "$avail_node" 2>/dev/null)"

    cur="$(read_node "$gov_node")"
    cur="$(akt_trim_ws "$cur")"

    target=""
    case " $avail " in *" schedutil "*) target="schedutil" ;; esac
    [ -z "$target" ] && case " $avail " in *" interactive "*) target="interactive" ;; esac
    [ -z "$target" ] && case " $avail " in *" ondemand "*) target="ondemand" ;; esac

    if [ -n "$target" ] && [ "$cur" != "$target" ]; then
      write_node "$gov_node" "$target"
      log_i "CPU: $pol governor -> $target"
    else
      log_i "CPU: $pol governor kept ($cur)"
    fi

    # schedutil knobs
    cur2="$(read_node "$gov_node")"
    cur2="$(akt_trim_ws "$cur2")"
    [ "$cur2" = "schedutil" ] || continue

    su_dir="$pol/schedutil"
    [ -d "$su_dir" ] || continue

    max_khz=""
    [ -e "$pol/cpuinfo_max_freq" ] && read -r max_khz < "$pol/cpuinfo_max_freq" 2>/dev/null

    # defaults = ON profile
    up="$(get_prop_int cpu.schedutil.on.little.up 6000)"
    down="$(get_prop_int cpu.schedutil.on.little.down 25000)"

    case "$max_khz" in
      ""|*[!0-9]*) : ;;
      *)
        if [ "$max_khz" -ge 2300000 ]; then
          up="$(get_prop_int cpu.schedutil.on.big.up 1500)"
          down="$(get_prop_int cpu.schedutil.on.big.down 18000)"
        fi
        ;;
    esac

    write_node_if_exists "$su_dir/up_rate_limit_us" "$up"
    write_node_if_exists "$su_dir/down_rate_limit_us" "$down"
    write_node_if_exists "$su_dir/iowait_boost_enable" "1"
  done
}
