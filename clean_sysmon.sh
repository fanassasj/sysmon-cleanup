#!/bin/bash
set +e

echo "== prepare backup =="
TS=$(date +%Y%m%d_%H%M%S)
BK=/root/incident_sysmon_$TS
mkdir -p "$BK"
echo "backup=$BK"

echo "== backup suspicious files =="
cp -a /opt/systemlog "$BK/" 2>/dev/null
cp -a /usr/local/sysmon "$BK/" 2>/dev/null
cp -a /usr/local/.sysmon-guard "$BK/" 2>/dev/null
cp -a /usr/local/lib/libsysmon.so "$BK/" 2>/dev/null
cp -a /etc/systemd/system/systemlog.service "$BK/" 2>/dev/null
cp -a /etc/systemd/system/sysmon.service "$BK/" 2>/dev/null
cp -a /etc/systemd/system/sysmon-guard.service "$BK/" 2>/dev/null
cp -a /etc/systemd/system/sysmon-guard.timer "$BK/" 2>/dev/null
cp -a /etc/ld.so.preload "$BK/" 2>/dev/null

echo "== stop and disable services =="
systemctl disable --now sysmon-guard.timer 2>/dev/null
systemctl disable --now sysmon-guard.service 2>/dev/null
systemctl disable --now sysmon.service 2>/dev/null
systemctl disable --now systemlog.service 2>/dev/null

echo "== clean preload injection =="
cp -a /etc/ld.so.preload "$BK/ld.so.preload.before_clean" 2>/dev/null
sed -i '\#/usr/local/lib/libsysmon\.so#d' /etc/ld.so.preload 2>/dev/null
sed -i '\#libsysmon\.so#d' /etc/ld.so.preload 2>/dev/null

echo "== kill matching processes =="
pkill -f '/usr/local/sysmon/sysmon' 2>/dev/null
pkill -f '/usr/local/.sysmon-guard/sysmon' 2>/dev/null
pkill -f '/opt/systemlog/SystemLoger' 2>/dev/null

echo "== unlock files =="
chattr -ia /usr/local/lib/libsysmon.so 2>/dev/null
chattr -iaR /opt/systemlog 2>/dev/null
chattr -iaR /usr/local/sysmon 2>/dev/null
chattr -iaR /usr/local/.sysmon-guard 2>/dev/null
chattr -ia /etc/systemd/system/systemlog.service 2>/dev/null
chattr -ia /etc/systemd/system/sysmon.service 2>/dev/null
chattr -ia /etc/systemd/system/sysmon-guard.service 2>/dev/null
chattr -ia /etc/systemd/system/sysmon-guard.timer 2>/dev/null

echo "== remove files =="
rm -rf /opt/systemlog
rm -rf /usr/local/sysmon
rm -rf /usr/local/.sysmon-guard
rm -f /usr/local/lib/libsysmon.so
rm -f /etc/systemd/system/systemlog.service
rm -f /etc/systemd/system/sysmon.service
rm -f /etc/systemd/system/sysmon-guard.service
rm -f /etc/systemd/system/sysmon-guard.timer

echo "== reload systemd =="
systemctl daemon-reload 2>/dev/null
systemctl reset-failed 2>/dev/null

echo "== verify services =="
systemctl status sysmon.service systemlog.service sysmon-guard.service sysmon-guard.timer --no-pager 2>/dev/null
echo "== verify process =="
ps auxww | grep -E 'SystemLoger|/usr/local/sysmon|/usr/local/.sysmon-guard|\[kworker/0:2\]|libsysmon' | grep -v grep
echo "== verify net =="
ss -tunap 2>/dev/null | grep -E '51\.254\.44\.35|24\.144\.123\.109|systemlog|sysmon|kworker/0:2'
echo "== verify preload =="
cat /etc/ld.so.preload 2>/dev/null
echo "== done =="
echo "backup=$BK"
