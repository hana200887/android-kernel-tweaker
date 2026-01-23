#!/system/bin/sh

zram_can_change_algo() {
  [ -e /sys/block/zram0/disksize ] || return 1
  ds=""
  read -r ds < /sys/block/zram0/disksize 2>/dev/null
  [ "$ds" = "0" ] && return 0
  return 1
}

apply_mem_tweaks() {
  log_i "MEM: applying VM tweaks (conservative)"

  write_node_if_exists "/proc/sys/vm/vfs_cache_pressure" "80"
  write_node_if_exists "/proc/sys/vm/page-cluster" "0"

  case "$MEM_CLASS" in
    small) write_node_if_exists "/proc/sys/vm/swappiness" "80" ;;
    medium) write_node_if_exists "/proc/sys/vm/swappiness" "60" ;;
    large) write_node_if_exists "/proc/sys/vm/swappiness" "40" ;;
    *) : ;;
  esac

  write_node_if_exists "/proc/sys/vm/dirty_ratio" "20"
  write_node_if_exists "/proc/sys/vm/dirty_background_ratio" "10"
  write_node_if_exists "/proc/sys/vm/dirty_writeback_centisecs" "500"
  write_node_if_exists "/proc/sys/vm/dirty_expire_centisecs" "2000"
  write_node_if_exists "/proc/sys/vm/compaction_proactiveness" "20"
  write_node_if_exists "/proc/sys/vm/stat_interval" "20"

  if [ "$HAS_MGLRU" -eq 1 ]; then
    write_node_if_exists "/sys/kernel/mm/lru_gen/min_ttl_ms" "5000"
  fi

  # zram: don't force if active
  if [ "$HAS_ZRAM" -eq 1 ]; then
    if zram_can_change_algo; then
      write_node_if_exists "/sys/block/zram0/comp_algorithm" "lz4"
    else
      log_i "ZRAM: skip comp_algorithm (zram active)"
    fi
  fi
}
