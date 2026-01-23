#!/system/bin/sh

is_queue_blacklisted() {
  dev="$1"
  case "$dev" in ""|loop*|ram*|zram*) return 0 ;; esac
  return 1
}

mount_dev_for_mp() {
  mp="$1"
  [ -r /proc/mounts ] || return 1
  while IFS= read -r dev mnt rest; do
    [ "$mnt" = "$mp" ] || continue
    echo "${dev##*/}"
    return 0
  done < /proc/mounts
  return 1
}

_io_add_target() {
  dev="$1"
  [ -n "$dev" ] || return 0
  [ -d "/sys/block/$dev/queue" ] || return 0
  is_queue_blacklisted "$dev" && return 0
  case " $IO_TARGETS " in *" $dev "*) return 0 ;; esac
  IO_TARGETS="${IO_TARGETS:-}${IO_TARGETS:+ }$dev"
}

_io_collect_targets() {
  IO_TARGETS=""
  for mp in /data /; do
    dev="$(mount_dev_for_mp "$mp")"
    case "$dev" in
      dm-*)
        for s in /sys/block/"$dev"/slaves/*; do
          [ -e "$s" ] || continue
          _io_add_target "${s##*/}"
        done
        ;;
      *)
        _io_add_target "$dev"
        for s in /sys/block/"$dev"/slaves/*; do
          [ -e "$s" ] || continue
          _io_add_target "${s##*/}"
        done
        ;;
    esac
  done
  echo "$IO_TARGETS"
}

apply_io_tweaks() {
  log_i "IO: applying queue tweaks (mounted targets only)"
  for dev in $(_io_collect_targets); do
    q="/sys/block/$dev/queue"
    [ -d "$q" ] || continue

    write_node_if_exists "$q/read_ahead_kb" "128"

    if [ "$(get_prop_bool io.iostats.disable 1)" -eq 1 ]; then
      write_node_if_exists "$q/iostats" "0"
    fi

    if [ -e "$q/rq_affinity" ] && [ "$(get_prop_bool io.rq_affinity.enable 1)" -eq 1 ]; then
      write_node_if_exists "$q/rq_affinity" "$(get_prop io.rq_affinity.value 2)"
    fi

    if [ -e "$q/nr_requests" ]; then
      cur="$(read_node "$q/nr_requests")"
      cur="$(akt_trim_ws "$cur")"
      case "$cur" in ""|*[!0-9]*) : ;; *) [ "$cur" -gt 256 ] && write_node "$q/nr_requests" "128" ;; esac
    fi

    if [ -e "$q/scheduler" ]; then
      write_one_of "$q/scheduler" "none" "mq-deadline" "deadline"
    fi
  done
}
