# sysmon-cleanup

一组针对 `sysmon` / `systemlog` / `ld.so.preload` 注入类后门的应急清理脚本。

仓库里保留了清理前备份、清理执行和结果核查三部分，适合多台服务器逐台处理。

## 目录

- `clean_sysmon.sh`：实际清理脚本
- `run.sh`：一键入口
- `check.sh`：结果核查脚本

## 一键运行

```bash
bash run.sh
```

## 结果核查

```bash
bash check.sh
```

## 远程下载执行

```bash
curl -fsSL https://raw.githubusercontent.com/fanassasj/sysmon-cleanup/main/run.sh -o /root/run.sh
bash /root/run.sh
```

## 清理目标

- `/opt/systemlog`
- `/usr/local/sysmon`
- `/usr/local/.sysmon-guard`
- `/usr/local/lib/libsysmon.so`
- `/etc/systemd/system/systemlog.service`
- `/etc/systemd/system/sysmon.service`
- `/etc/systemd/system/sysmon-guard.service`
- `/etc/systemd/system/sysmon-guard.timer`
- `/etc/ld.so.preload` 中的 `libsysmon.so`

## 说明

- 脚本会先备份可疑文件到 `/root/incident_sysmon_<timestamp>`
- 会停用并删除已知的 systemd 持久化项
- 会清理 `ld.so.preload` 注入并杀掉匹配进程
- 结果核查脚本会检查服务、进程、网络和 preload 状态

## 注意

这是应急清理，不替代重装系统。若机器已出现 root 级持久化，清理后仍建议尽快更换密码、SSH key、API token，并收紧安全组。
