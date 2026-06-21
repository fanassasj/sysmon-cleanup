#!/bin/bash
set +e

EXPECTED_SERVER="${EXPECTED_NEZHA_SERVER:-8.899877.xyz:8008}"

echo "== nezha-agent check =="
echo "host=$(hostname 2>/dev/null || echo unknown)"
echo "time=$(date)"
echo "expected_server=$EXPECTED_SERVER"
echo

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

EXPECTED_NORM=$(normalize_server "$EXPECTED_SERVER")
BAD=0

CANONICAL_CONFIG=$(extract_config_from_unit nezha-agent.service)
CANONICAL_SERVER=$(server_from_config "$CANONICAL_CONFIG")
CANONICAL_GOOD=0
if [ "$(normalize_server "$CANONICAL_SERVER")" = "$EXPECTED_NORM" ]; then
  CANONICAL_GOOD=1
fi

echo "== units =="
UNITS=$(discover_units)
if [ -z "$UNITS" ]; then
  echo "no nezha-agent*.service unit files found"
fi

for unit in $UNITS; do
  cfg=$(extract_config_from_unit "$unit")
  server=$(server_from_config "$cfg")
  server_norm=$(normalize_server "$server")
  state=$(systemctl is-active "$unit" 2>/dev/null)
  enabled=$(systemctl is-enabled "$unit" 2>/dev/null)
  if [ "$unit" = "nezha-agent.service" ] && [ -n "$server" ] && [ "$server_norm" = "$EXPECTED_NORM" ]; then
    verdict=OK
  elif [ "$unit" != "nezha-agent.service" ] && [ "$CANONICAL_GOOD" -eq 0 ] && [ -n "$server" ] && [ "$server_norm" = "$EXPECTED_NORM" ]; then
    verdict=OK_NO_GOOD_CANONICAL
  else
    verdict=BAD
    BAD=$((BAD + 1))
  fi
  echo "$verdict unit=$unit active=$state enabled=$enabled config=${cfg:-unknown} server=${server:-unknown}"
done

echo
echo "== process =="
ps auxww | grep -E 'nezha-agent' | grep -v grep

echo
echo "== connections =="
ss -tunap 2>/dev/null | grep -E 'nezha-agent|:8008'

echo
if [ "$BAD" -eq 0 ]; then
  echo "result=clean"
  exit 0
fi

echo "result=bad bad_units=$BAD"
exit 1
