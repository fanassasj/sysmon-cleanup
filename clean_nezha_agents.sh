#!/bin/bash
set +e

EXPECTED_SERVER="${EXPECTED_NEZHA_SERVER:-8.899877.xyz:8008}"
AGENT_DIR="${NEZHA_AGENT_DIR:-/opt/nezha/agent}"
TS=$(date +%Y%m%d_%H%M%S)
BK="/root/incident_nezha_agent_$TS"

echo "== nezha-agent cleanup =="
echo "host=$(hostname 2>/dev/null || echo unknown)"
echo "time=$(date)"
echo "expected_server=$EXPECTED_SERVER"
echo "backup=$BK"
mkdir -p "$BK"

if ! command -v systemctl >/dev/null 2>&1; then
  echo "ERROR: systemctl not found"
  exit 1
fi

normalize_server() {
  printf '%s' "$1" | sed 's#^[a-zA-Z][a-zA-Z0-9+.-]*://##; s#/*$##'
}

extract_config_from_unit() {
  unit="$1"
  cfg=$(systemctl cat "$unit" 2>/dev/null \
    | awk '{gsub(/"/," "); for (i=1;i<=NF;i++) { if ($i=="-c" || $i=="--config") print $(i+1); else if ($i ~ /^--config=/) { sub(/^--config=/,"",$i); print $i } }}' \
    | tail -n 1)
  if [ -n "$cfg" ]; then
    echo "$cfg"
    return 0
  fi
  file=$(unit_file_path "$unit")
  [ -f "$file" ] || return 1
  awk '{gsub(/"/," "); for (i=1;i<=NF;i++) { if ($i=="-c" || $i=="--config") print $(i+1); else if ($i ~ /^--config=/) { sub(/^--config=/,"",$i); print $i } }}' "$file" 2>/dev/null | tail -n 1
}

server_from_config() {
  cfg="$1"
  [ -f "$cfg" ] || return 1
  sed -nE 's/^[[:space:]]*server:[[:space:]]*"?([^"#]+)"?.*/\1/p' "$cfg" 2>/dev/null | head -n 1 | xargs
}

unit_fragment_path() {
  path=$(systemctl show "$1" -p FragmentPath --value 2>/dev/null)
  if [ -n "$path" ]; then
    echo "$path"
    return 0
  fi
  unit_file_path "$1"
}

unit_file_path() {
  unit="$1"
  for dir in /etc/systemd/system /run/systemd/system /lib/systemd/system /usr/lib/systemd/system; do
    [ -f "$dir/$unit" ] && echo "$dir/$unit" && return 0
  done
  return 1
}

discover_units() {
  for dir in /etc/systemd/system /run/systemd/system /lib/systemd/system /usr/lib/systemd/system; do
    [ -d "$dir" ] || continue
    find "$dir" -maxdepth 1 -type f -name 'nezha-agent*.service' -printf '%f\n' 2>/dev/null
  done | sort -u
}

backup_path() {
  path="$1"
  [ -e "$path" ] || return 0
  dest="$BK$path"
  mkdir -p "$(dirname "$dest")"
  cp -a "$path" "$dest" 2>/dev/null
}

delete_if_safe() {
  path="$1"
  case "$path" in
    /etc/systemd/system/nezha-agent*.service|/etc/sysconfig/nezha-agent*|/opt/nezha/agent/config*.yml|/opt/nezha/agent/config*.yaml)
      rm -f "$path"
      ;;
    *)
      echo "skip unsafe delete path: $path"
      ;;
  esac
}

EXPECTED_NORM=$(normalize_server "$EXPECTED_SERVER")
FOUND=0
KEPT=0
REMOVED=0

CANONICAL_CONFIG=$(extract_config_from_unit nezha-agent.service)
CANONICAL_SERVER=$(server_from_config "$CANONICAL_CONFIG")
CANONICAL_GOOD=0
if [ "$(normalize_server "$CANONICAL_SERVER")" = "$EXPECTED_NORM" ]; then
  CANONICAL_GOOD=1
fi

echo "== scan systemd units =="
UNITS=$(discover_units)
if [ -z "$UNITS" ]; then
  echo "no nezha-agent*.service unit files found"
fi

for unit in $UNITS; do
  FOUND=$((FOUND + 1))
  cfg=$(extract_config_from_unit "$unit")
  server=$(server_from_config "$cfg")
  server_norm=$(normalize_server "$server")
  fragment=$(unit_fragment_path "$unit")

  echo "-- unit=$unit"
  echo "   fragment=${fragment:-unknown}"
  echo "   config=${cfg:-unknown}"
  echo "   server=${server:-unknown}"

  if [ "$unit" = "nezha-agent.service" ] && [ -n "$server" ] && [ "$server_norm" = "$EXPECTED_NORM" ]; then
    echo "   action=keep"
    KEPT=$((KEPT + 1))
    continue
  fi

  if [ "$unit" != "nezha-agent.service" ] && [ "$CANONICAL_GOOD" -eq 0 ] && [ -n "$server" ] && [ "$server_norm" = "$EXPECTED_NORM" ]; then
    echo "   action=keep_no_good_canonical"
    KEPT=$((KEPT + 1))
    continue
  fi

  echo "   action=disable_delete"
  backup_path "$fragment"
  backup_path "$cfg"
  backup_path "/etc/sysconfig/${unit%.service}"

  systemctl disable --now "$unit" 2>/dev/null

  delete_if_safe "$fragment"
  delete_if_safe "/etc/sysconfig/${unit%.service}"
  delete_if_safe "$cfg"

  REMOVED=$((REMOVED + 1))
done

echo "== scan orphan configs =="
if [ -d "$AGENT_DIR" ]; then
  find "$AGENT_DIR" -maxdepth 1 -type f \( -name 'config*.yml' -o -name 'config*.yaml' \) 2>/dev/null | while read -r cfg; do
    server=$(server_from_config "$cfg")
    server_norm=$(normalize_server "$server")
    [ -n "$server" ] || continue
    if [ "$server_norm" != "$EXPECTED_NORM" ]; then
      echo "-- orphan_config=$cfg"
      echo "   server=$server"
      echo "   action=backup_delete"
      backup_path "$cfg"
      delete_if_safe "$cfg"
    fi
  done
fi

echo "== reload systemd =="
systemctl daemon-reload 2>/dev/null
systemctl reset-failed 2>/dev/null

echo "== restart kept canonical service if present =="
if [ -f /etc/systemd/system/nezha-agent.service ] || [ -f /lib/systemd/system/nezha-agent.service ] || [ -f /usr/lib/systemd/system/nezha-agent.service ]; then
  cfg=$(extract_config_from_unit nezha-agent.service)
  server=$(server_from_config "$cfg")
  if [ "$(normalize_server "$server")" = "$EXPECTED_NORM" ]; then
    systemctl enable nezha-agent.service 2>/dev/null
    systemctl restart nezha-agent.service 2>/dev/null
  fi
fi

echo "== summary =="
echo "found_units=$FOUND"
echo "kept_units=$KEPT"
echo "removed_units=$REMOVED"
echo "backup=$BK"
echo "== remaining nezha agent units =="
discover_units
echo "== done =="
