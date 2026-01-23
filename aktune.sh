#!/system/bin/sh
MODDIR="${0%/*}"
export AKTUNE_MODDIR="$MODDIR"
. "$MODDIR/common/util.sh"
. "$MODDIR/common/sysfs.sh"
. "$MODDIR/common/detect.sh"
. "$MODDIR/common/sched.sh"
. "$MODDIR/common/cpuset.sh"
. "$MODDIR/common/cpu.sh"
. "$MODDIR/common/gpu.sh"
. "$MODDIR/common/io.sh"
. "$MODDIR/common/mem.sh"
. "$MODDIR/common/power.sh"
. "$MODDIR/common/net.sh"

main() {
  aktune_prepare_dirs
  rotate_logs_if_needed
  detect_platform
  apply_sched_tweaks
  apply_cpuset_uclamp_tweaks
  apply_cpu_tweaks
  apply_gpu_tweaks
  apply_io_tweaks
  apply_mem_tweaks
  apply_power_tweaks
  apply_net_tweaks
  log_i "aktune: oneshot complete"
}

main "$@"
exit 0
