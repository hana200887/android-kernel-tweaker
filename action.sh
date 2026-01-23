#!/system/bin/sh

MODDIR="${0%/*}"

# Load helpers/paths
. "$MODDIR/common/util.sh"

aktune_prepare_dirs

MODE_FILE="$STATE_DIR/force_mode"
PIDFILE="$STATE_DIR/daemon.pid"

read_mode() {
  if [ -f "$MODE_FILE" ]; then
    m="$(read_first_line "$MODE_FILE" 2>/dev/null)"
    m="$(akt_trim_ws "$m")"
    [ -n "$m" ] && { echo "$m"; return 0; }
  fi
  echo "auto"
}

normalize_mode() {
  case "$1" in
    auto|aggressive|strict) echo "$1" ;;
    *) echo "auto" ;;
  esac
}

next_mode() {
  case "$1" in
    auto) echo "aggressive" ;;
    aggressive) echo "strict" ;;
    strict) echo "auto" ;;
    *) echo "auto" ;;
  esac
}

mode_desc() {
  case "$1" in
    auto) echo "AUTO: Screen ON => Aggressive, Screen OFF => Strict" ;;
    aggressive) echo "AGGRESSIVE: Always Aggressive (ignores screen state)" ;;
    strict) echo "STRICT: Always Strict (ignores screen state)" ;;
    *) echo "AUTO: Screen ON => Aggressive, Screen OFF => Strict" ;;
  esac
}

cur="$(read_mode)"
cur="$(normalize_mode "$cur")"
nxt="$(next_mode "$cur")"

echo "$nxt" > "$MODE_FILE" 2>/dev/null

log_i "action: mode changed $cur -> $nxt"

echo ""
echo "========================================"
echo "AKTune: mode changed"
echo "Current: $cur"
echo "Next: $nxt"
echo "----------------------------------------"
mode_desc "$nxt"
echo "========================================"
echo ""

# Restart daemon so changes apply immediately
if [ -f "$PIDFILE" ]; then
  pid="$(read_first_line "$PIDFILE" 2>/dev/null)"
  pid="$(akt_trim_ws "$pid")"
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null
    sleep 1
  fi
fi

if command -v nohup >/dev/null 2>&1; then
  nohup sh "$MODDIR/tweaks/daemon.sh" >> "$LOG_FILE" 2>&1 &
else
  sh "$MODDIR/tweaks/daemon.sh" >> "$LOG_FILE" 2>&1 &
fi

echo $! > "$PIDFILE" 2>/dev/null

log_i "action: daemon restarted pid=$!"
echo "AKTune: daemon restarted"
echo ""
