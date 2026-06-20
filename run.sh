#!/bin/bash
set -e

DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
echo "== sysmon-cleanup run =="
echo "host=$(hostname 2>/dev/null || echo unknown)"
echo "time=$(date)"
bash "$DIR/clean_sysmon.sh"
echo "== next step =="
echo "Run this check command to confirm cleanup:"
echo "bash $DIR/check.sh"
