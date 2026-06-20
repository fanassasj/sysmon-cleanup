#!/bin/bash
set +e

echo "== services =="
systemctl status sysmon.service systemlog.service sysmon-guard.service sysmon-guard.timer --no-pager 2>/dev/null

echo "== files =="
ls -la /opt/systemlog /usr/local/sysmon /usr/local/.sysmon-guard /usr/local/lib/libsysmon.so 2>/dev/null

echo "== process =="
ps auxww | grep -E 'SystemLoger|/usr/local/sysmon|/usr/local/.sysmon-guard|\[kworker/0:2\]|libsysmon' | grep -v grep

echo "== net =="
ss -tunap 2>/dev/null | grep -E '51\.254\.44\.35|24\.144\.123\.109|systemlog|sysmon|kworker/0:2'

echo "== preload =="
cat /etc/ld.so.preload 2>/dev/null
