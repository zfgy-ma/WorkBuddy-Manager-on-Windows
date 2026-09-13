# WorkBuddy Manager-on-Windows（本地运行实例）

本目录是 [ithtelab/workbuddy-manager](https://github.com/ithtelab/workbuddy-manager)
的 Windows 兼容运行副本，只加了 Windows 适配补丁，**不改业务逻辑、不含上游**。

> **完整说明请看补丁仓库**：
> [zfgy-ma/WorkBuddy-Manager-on-Windows](https://github.com/zfgy-ma/WorkBuddy-Manager-on-Windows)
> 本文件只记录本机这一份的运行信息，避免两处文档各自漂移。

---

## 本目录的改动（相对原版）

| 类型 | 文件 | 说明 |
|---|---|---|
| 新增 | `start-manager.ps1` | 启动管理端（等价原版 systemd 服务，内置环境变量） |
| 新增 | `stop-manager.ps1` | 停止管理端并清理残留端口进程 |
| 新增 | `status-manager.ps1` | 查看进程、端口、健康检查、上游容器状态 |
| 新增 | `部署说明-Windows.md` | 本机部署说明 |
| 修改 | `server/services/wb2api.py` | `read_container_logs()` 显式 UTF-8 解码 |
| 修改 | `server/services/updater.py` | `_local_upstream_head()` 显式 UTF-8 解码 |
| 修改 | `.gitignore` | 忽略 `旧内容/` |

修正原因：原版 `subprocess(text=True)` 在简中 Windows 上按 GBK 解码，
而 `docker logs` 与 `git` 输出为 UTF-8，抛 `UnicodeDecodeError`，
导致「任务记录」页读容器日志崩溃、自动任务日志采集失效。

---

## 启动与停止

```powershell
# 后台启动
powershell -ExecutionPolicy Bypass -File .\start-manager.ps1 -Daemon

# 前台启动（看实时日志）
powershell -ExecutionPolicy Bypass -File .\start-manager.ps1

# 查看状态
powershell -ExecutionPolicy Bypass -File .\status-manager.ps1

# 停止
powershell -ExecutionPolicy Bypass -File .\stop-manager.ps1
```

| 服务 | 地址 |
|---|---|
| 管理网页 | http://127.0.0.1:7864 |
| 上游 workbuddy2api | http://127.0.0.1:7863（Docker 容器 `workbuddy2api`） |

---

## 本机运行信息

- 依赖上游目录 `..\workbuddy2api`（与本目录同级），`start-manager.ps1` 自动推算；
- 数据目录 `data\`：SQLite、`users.json`、PID 与日志，**含敏感信息，勿外传**；
- 初始管理员密码见 `data\_init_pwd.txt`（仅首次启动写入）；
- Docker Desktop 必须处于运行状态，否则读不到上游状态。

---

## 本仓库的分支

| 分支 | 内容 |
|---|---|
| `windows-deploy` | 原版 v1.0.11 + 上述 Windows 补丁（当前使用） |
| `main` | 原版 v1.0.11，未改动 |

原版完整文档见 [ithtelab/workbuddy-manager](https://github.com/ithtelab/workbuddy-manager)；
本机另存的改动前 README 在 `旧内容\` 下。
