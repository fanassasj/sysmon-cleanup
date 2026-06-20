#!/bin/bash
set -e

DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
bash "$DIR/clean_sysmon.sh"
