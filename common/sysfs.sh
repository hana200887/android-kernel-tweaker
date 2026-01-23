#!/system/bin/sh

ensure_util_loaded() {
  if [ -n "${LOG_FILE:-}" ] && [ -n "${BASELINE_DB:-}" ] && [ -n "${STATE_DIR:-}" ]; then
    return 0
  fi

  if [ -n "${AKTUNE_MODDIR:-}" ] && [ -f "$AKTUNE_MODDIR/common/util.sh" ]; then
    . "$AKTUNE_MODDIR/common/util.sh"
  else
    d0="${0%/*}"
    [ -f "$d0/util.sh" ] && . "$d0/util.sh"
    [ -f "$d0/../common/util.sh" ] && . "$d0/../common/util.sh"
  fi

  AKTUNE_DATA_DIR="${AKTUNE_DATA_DIR:-/data/adb/aktune}"
  STATE_DIR="${STATE_DIR:-$AKTUNE_DATA_DIR/state}"
  LOG_DIR="${LOG_DIR:-$AKTUNE_DATA_DIR/logs}"
  BASELINE_DB="${BASELINE_DB:-$STATE_DIR/baseline.tsv}"
  BLOCKED_DB="${BLOCKED_DB:-$STATE_DIR/blocked.tsv}"
  LOG_FILE="${LOG_FILE:-$LOG_DIR/aktune.log}"

  mkdir -p "$STATE_DIR" "$LOG_DIR" 2>/dev/null
  [ -f "$BASELINE_DB" ] || : > "$BASELINE_DB"
  [ -f "$BLOCKED_DB" ] || : > "$BLOCKED_DB"
  [ -f "$LOG_FILE" ] || : > "$LOG_FILE"
}

_extract_bracket_active() {
  # For scheduler/comp_algorithm: "none [mq-deadline] kyber"
  s="$1"
  case "$s" in
    *"["*"]"*)
      t="${s#*[}"
      t="${t%%]*}"
      echo "$t"
      ;;
    *) echo "" ;;
  esac
}

_normalize_baseline_value() {
  path="$1"
  val="$2"
  case "$path" in
    */scheduler|*/comp_algorithm)
      picked="$(_extract_bracket_active "$val")"
      [ -n "$picked" ] && val="$picked"
      ;;
  esac
  echo "$val"
}

_verify_effective() {
  path="$1"
  wanted="$2"
  got="$3"

  case "$path" in
    */scheduler|*/comp_algorithm)
      case "$got" in *"[$wanted]"*) return 0 ;; esac
      ;;
  esac

  case "$path" in
    /proc/sys/kernel/printk|/proc/sys/kernel/sched_upmigrate|/proc/sys/kernel/sched_downmigrate)
      got1="$(akt_first_token "$got")"
      [ "$got1" = "$wanted" ] && return 0
      ;;
  esac

  [ "$wanted" = "$got" ]
}

read_node() {
  ensure_util_loaded
  path="$1"
  [ -e "$path" ] || return 1

  # Prefer pure-sh reader
  if command -v cat >/dev/null 2>&1; then
    cat "$path" 2>/dev/null
    return $?
  fi

  akt_read_file "$path" 2>/dev/null
}

blocked_has() {
  ensure_util_loaded
  p="$1"
  [ -n "$p" ] || return 1
  [ -f "$BLOCKED_DB" ] || return 1
  while IFS="$(printf '\t')" read -r bp reason; do
    bp="$(akt_strip_cr "$bp")"
    [ -n "$bp" ] || continue
    [ "$bp" = "$p" ] && return 0
  done < "$BLOCKED_DB"
  return 1
}

blocked_add() {
  ensure_util_loaded
  p="$1"
  reason="$2"
  [ -n "$p" ] || return 0
  blocked_has "$p" && return 0
  printf "%s\t%s\n" "$p" "${reason:-blocked}" >> "$BLOCKED_DB" 2>/dev/null
}

save_baseline_once() {
  ensure_util_loaded
  path="$1"
  cur="$2"
  [ -n "$path" ] || return 1
  [ -f "$BASELINE_DB" ] || : > "$BASELINE_DB"

  while IFS="$(printf '\t')" read -r bp bv; do
    bp="$(akt_strip_cr "$bp")"
    [ -n "$bp" ] || continue
    [ "$bp" = "$path" ] && return 0
  done < "$BASELINE_DB"

  cur_clean="$(akt_trim_ws "$cur")"
  cur_clean="$(_normalize_baseline_value "$path" "$cur_clean")"
  cur_clean="$(akt_trim_ws "$cur_clean")"
  printf "%s\t%s\n" "$path" "$cur_clean" >> "$BASELINE_DB" 2>/dev/null
  return 0
}

baseline_get() {
  ensure_util_loaded
  path="$1"
  [ -n "$path" ] || return 1
  [ -f "$BASELINE_DB" ] || return 1
  while IFS="$(printf '\t')" read -r bp bv; do
    bp="$(akt_strip_cr "$bp")"
    [ -n "$bp" ] || continue
    if [ "$bp" = "$path" ]; then
      bv="$(akt_strip_cr "$bv")"
      echo "$bv"
      return 0
    fi
  done < "$BASELINE_DB"
  return 1
}

baseline_restore_node() {
  ensure_util_loaded
  path="$1"
  [ -n "$path" ] || return 1
  v="$(baseline_get "$path")"
  [ -n "$v" ] || return 1
  write_node_if_exists "$path" "$v"
}

write_node() {
  ensure_util_loaded
  path="$1"
  value="$2"
  [ -n "$path" ] || return 1
  [ -e "$path" ] || return 2
  blocked_has "$path" && return 2

  old="$(read_node "$path")"
  old_trim="$(akt_trim_ws "$old")"
  value_trim="$(akt_trim_ws "$value")"
  [ "$old_trim" = "$value_trim" ] && return 0

  save_baseline_once "$path" "$old_trim"

  if { printf "%s\n" "$value_trim" > "$path"; } 2>/dev/null; then
    new="$(read_node "$path")"
    new_trim="$(akt_trim_ws "$new")"
    [ -z "$new_trim" ] && return 0
    if _verify_effective "$path" "$value_trim" "$new_trim"; then
      log_i "Set: $path = $value_trim"
      return 0
    fi
    log_w "Write verify mismatch: $path wanted '$value_trim' got '$new_trim'"
    return 0
  fi

  log_w "Failed to write: $path = $value_trim"
  blocked_add "$path" "write_failed"
  return 1
}

write_node_if_exists() {
  [ -e "$1" ] || return 0
  write_node "$1" "$2"
}

_word_in_list() {
  list="$1"
  w="$2"
  case " $list " in
    *" $w "*) return 0 ;;
    *) return 1 ;;
  esac
}

write_one_of() {
  ensure_util_loaded
  path="$1"
  shift
  [ -e "$path" ] || return 0
  blocked_has "$path" && return 0

  supported=""
  parent="${path%/*}"

  if [ -e "$parent/available_governors" ]; then
    supported="$(read_node "$parent/available_governors" 2>/dev/null)"
  elif [ -e "$parent/scaling_available_governors" ]; then
    supported="$(read_node "$parent/scaling_available_governors" 2>/dev/null)"
  else
    supported="$(read_node "$path" 2>/dev/null)"
  fi

  for v in "$@"; do
    if [ -n "$supported" ]; then
      _word_in_list "$supported" "$v" || continue
    fi
    write_node "$path" "$v"
    return 0
  done
  return 0
}

set_sysctl() {
  key="$1"
  value="$2"
  path="/proc/sys/$key"
  write_node_if_exists "$path" "$value"
}

restore_baseline_all() {
  ensure_util_loaded
  [ -f "$BASELINE_DB" ] || { log_w "No baseline DB found"; return 0; }

  while IFS="$(printf '\t')" read -r path value; do
    path="$(akt_strip_cr "$path")"
    value="$(akt_strip_cr "$value")"
    [ -n "$path" ] || continue
    [ -e "$path" ] || continue
    { printf "%s\n" "$value" > "$path"; } 2>/dev/null && log_i "Restored baseline: $path = $value"
  done < "$BASELINE_DB"
}
