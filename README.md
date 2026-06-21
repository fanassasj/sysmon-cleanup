# sysmon-cleanup

针对 `sysmon` / `systemlog` / `ld.so.preload` 注入类后门的应急清理脚本。

这个仓库适合多台服务器逐台处理：每台服务器拉取仓库，授权脚本，执行一键清理，然后执行核查脚本确认结果。

## 文件

- `run.sh`：一键清理入口
- `clean_sysmon.sh`：实际清理逻辑
- `check.sh`：清理结果核查
- `clean_nezha_agents.sh`：Nezha Agent 节点清理，删除非指定服务端地址的 `nezha-agent*.service`
- `check_nezha_agents.sh`：Nezha Agent 节点核查

## 使用

在目标服务器上执行：

```bash
git clone https://github.com/fanassasj/sysmon-cleanup.git
cd sysmon-cleanup
chmod +x run.sh clean_sysmon.sh check.sh
bash run.sh
```

`run.sh` 执行完成后会打印建议运行的核查命令：

```bash
bash ./check.sh
```

也可以手动执行核查：

```bash
bash check.sh
```

## Nezha Agent 节点清理

只保留服务端地址为 `8.899877.xyz:8008` 的 Nezha Agent 服务，其他 `nezha-agent*.service` 会被停用、禁用并删除对应 unit/config/env 文件。

在 Agent 节点执行：

```bash
chmod +x clean_nezha_agents.sh check_nezha_agents.sh
bash clean_nezha_agents.sh
bash check_nezha_agents.sh
```

如果以后服务端地址变化，可以用环境变量覆盖：

```bash
EXPECTED_NEZHA_SERVER=example.com:8008 bash clean_nezha_agents.sh
EXPECTED_NEZHA_SERVER=example.com:8008 bash check_nezha_agents.sh
```

清理前会备份到：

```text
/root/incident_nezha_agent_<timestamp>
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

## 成功标志

核查脚本中这些部分应为空，或显示对应 unit 不存在：

- `services`：`sysmon.service`、`systemlog.service`、`sysmon-guard.service`、`sysmon-guard.timer` 不存在或不活跃
- `files`：不再列出上述恶意路径
- `process`：没有 `SystemLoger`、`/usr/local/sysmon`、`[kworker/0:2]`、`libsysmon`
- `net`：没有 `51.254.44.35`、`24.144.123.109` 或相关连接
- `preload`：为空，或至少没有 `libsysmon.so`

## 备份

清理前会把可疑文件备份到：

```text
/root/incident_sysmon_<timestamp>
```

## 注意

这是应急清理，不替代重装系统。若机器已经出现 root 级持久化，清理后仍建议更换 root 密码、SSH key、面板密码、API token，并在云安全组限制 SSH 来源 IP。
