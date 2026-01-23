#!/system/bin/sh
apply_net_tweaks() {
  log_i "NET: applying net tweaks"

  if [ "$(get_prop_bool net.tcp_low_latency.enable 1)" -eq 1 ]; then
    write_node_if_exists "/proc/sys/net/ipv4/tcp_low_latency" "1"
  fi

  if [ "$(get_prop_bool net.tcp_timestamps.disable 0)" -eq 1 ]; then
    write_node_if_exists "/proc/sys/net/ipv4/tcp_timestamps" "0"
  fi
}
