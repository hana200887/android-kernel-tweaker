#!/system/bin/sh
# AKTune uninstall script: best-effort restore captured baseline values
MODDIR="${0%/*}"

# shellcheck disable=SC1091
. "$MODDIR/common/util.sh"
. "$MODDIR/common/sysfs.sh"

aktune_prepare_dirs

log_i "Uninstall: attempting baseline restore..."
restore_baseline_all
log_i "Uninstall: baseline restore complete"

# Optional: cleanup AKTune state (comment out if you want to keep logs after uninstall)
rm -rf "$AKTUNE_DATA_DIR/state" 2>/dev/null
