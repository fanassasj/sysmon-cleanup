#!/bin/bash
set +e

echo "== sysmon-cleanup check =="
echo "host=$(hostname 2>/dev/null || echo unknown)"
echo "time=$(date)"
echo

echo "== services =="
echo "Expected clean result: Unit ... could not be found, or no active sysmon/systemlog units."
systemctl status sysmon.service systemlog.service sysmon-guard.service sysmon-guard.timer --no-pager 2>/dev/null

echo "== files =="
echo "Expected clean result: no files listed."
ls -la /opt/systemlog /usr/local/sysmon /usr/local/.sysmon-guard /usr/local/lib/libsysmon.so 2>/dev/null

echo "== process =="
echo "Expected clean result: no process output."
ps auxww | grep -E 'SystemLoger|/usr/local/sysmon|/usr/local/.sysmon-guard|\[kworker/0:2\]|libsysmon' | grep -v grep

echo "== net =="
echo "Expected clean result: no connection output."
ss -tunap 2>/dev/null | grep -E '51\.254\.44\.35|24\.144\.123\.109|systemlog|sysmon|kworker/0:2'

echo "== preload =="
echo "Expected clean result: empty output or no libsysmon.so entry."
cat /etc/ld.so.preload 2>/dev/null

echo "== check done =="
