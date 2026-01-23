#!/system/bin/sh

MODDIR="${0%/*}"
. "$MODDIR/common/util.sh"

aktune_prepare_dirs
rotate_logs_if_needed

log_i "service: waiting for boot completion"
wait_boot_completed 180
akt_sleep 5

PIDFILE="$STATE_DIR/daemon.pid"
if [ -f "$PIDFILE" ]; then
  pid="$(read_first_line "$PIDFILE" 2>/dev/null)"
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    log_i "service: daemon already running pid=$pid"
    exit 0
  fi
fi

log_i "service: starting adaptive daemon"

if command -v nohup >/dev/null 2>&1; then
  nohup sh "$MODDIR/tweaks/daemon.sh" >> "$LOG_FILE" 2>&1 &
else
  sh "$MODDIR/tweaks/daemon.sh" >> "$LOG_FILE" 2>&1 &
fi

printf "%s\n" "$!" > "$PIDFILE" 2>/dev/null
log_i "service: daemon pid=$!"
exit 0
