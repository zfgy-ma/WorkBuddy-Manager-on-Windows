# WorkBuddy Manager-on-Windows

**WorkBuddy Manager 的 Windows 兼容修复仓库**

本仓库是 [ithtelab/workbuddy-manager](https://github.com/ithtelab/workbuddy-manager) 的
**Windows 兼容修复**，只做一件事：让原版管理端在 Windows 上恢复正常运行。

**不新增功能、不改动业务逻辑、不含上游、不含原版完整源码。**

---

## ⚠️ 重要声明（务必先读）

### 1. 本仓库不含上游 workbuddy2api

原版 WorkBuddy Manager 只是**管理端界面**。账号轮询、并发调度、签到、
OpenAI 兼容接口全部由上游 [`workbuddy2api`](https://github.com/Sliverkiss/workbuddy2api)
（Go 项目，Docker 部署）负责。本仓库**不含上游代码，也不替代上游**。

### 2. 单独 clone 本仓库无法运行

本仓库**只有被改动的几个文件，没有完整源码**，clone 下来什么也跑不起来
—— 没有入口程序、没有前端、没有依赖清单。

完整运行需要三样东西同时就位：

| 必需组件 | 来源 | 作用 |
|---|---|---|
| 上游 `workbuddy2api` | [Sliverkiss/workbuddy2api](https://github.com/Sliverkiss/workbuddy2api) | 账号池调度 + OpenAI 兼容接口（Docker） |
| 原版管理端源码 | [ithtelab/workbuddy-manager](https://github.com/ithtelab/workbuddy-manager) | 管理界面 + 对外网关 |
| Windows 适配文件 | **本仓库** | 覆盖到原版对应位置，让管理端在 Windows 上跑通 |

三者的正确组合方式见下方[使用方法](#使用方法)。

### 3. 分支说明

| 分支 | 内容 | 用途 |
|---|---|---|
| `main` | **只有新增/修改部分**（本 README 所述内容） | 默认分支，覆盖到原版用 |
| `archive/original` | 原版管理端完整源码（对应 `00d623c`） | 仅作备份，便于对照 |
| `archive/original-with-patch` | 原版 + 修复后的完整代码 | 仅作备份，便于对照 |

**只有 `main` 分支是给使用者用的。** `archive/` 分支为备份，内容属原版作者，
请以 [ithtelab/workbuddy-manager](https://github.com/ithtelab/workbuddy-manager) 为准。

### 4. 本项目只做一件事：修复 Windows 兼容性

本仓库仅解决原版管理端在 Windows 上无法运行的问题。
**Linux 用户请直接使用原版，不需要本仓库。**

---

## 本仓库内容：完整的替换文件，覆盖即可

本仓库**不搬运原版那 155 个文件**，只放被改动的文件，且**保持与原版相同的目录结构**：

| 文件 | 相对原版的改动 |
|---|---|
| `server/services/wb2api.py` | 修复容器日志解码（完整文件，可直接覆盖） |
| `server/services/updater.py` | 修复 git 输出解码（完整文件，可直接覆盖） |
| `.gitignore` | 增加忽略 `旧内容/`（完整文件，可直接覆盖） |
| `start-manager.ps1` | **新增**：启动管理端，等价原版 Linux 的 systemd 服务 |
| `stop-manager.ps1` | **新增**：停止管理端并清理残留端口进程 |
| `status-manager.ps1` | **新增**：查看进程、端口、健康检查、上游容器状态 |
| `部署说明-Windows.md` | **新增**：本机部署说明 |

### 修的是什么问题

原版用 `subprocess(..., text=True)` 读取子进程输出。
Python 在 Windows 上会按系统区域编码（简体中文系统为 **GBK**）解码，
而 `docker logs` 与 `git` 输出的是 **UTF-8**（上游日志含中文），于是抛异常：

```
UnicodeDecodeError: 'gbk' codec can't decode byte 0xaa in position 158
```

**实际影响**：「任务记录」页读容器日志的线程崩溃，自动任务日志采集完全失效。

| 文件 | 函数 | 修复内容 |
|---|---|---|
| `server/services/wb2api.py` | `read_container_logs()` | `text=True` → `encoding='utf-8', errors='replace'` |
| `server/services/updater.py` | `_local_upstream_head()` | 同上 |

> Linux 下行为完全不变（原本就是 UTF-8），因此该修复对原版无副作用。
> `errors='replace'` 保证个别坏字节只显示为 `?`，不会让整个功能崩溃。

---
## 使用方法

> 前提：本仓库需要与原版管理端源码**配合使用**，不能单独运行。

### 前提条件

| 依赖 | 要求 | 用途 |
|---|---|---|
| Python | ≥ 3.11 | 运行管理端 |
| Node.js | ≥ 18 | 构建前端（仅首次需要） |
| Docker Desktop | 已运行 | 跑上游 workbuddy2api |
| Git | 任意版本 | 拉取代码 |

### 第一步：部署上游 workbuddy2api（必需，不可省略）

```powershell
cd C:\你的目录
git clone https://github.com/Sliverkiss/workbuddy2api.git
cd workbuddy2api

# 若仓库自带 config.example.json，复制为 config.json 并填入随机 api_key
Copy-Item config.example.json config.json

docker compose up -d --build
```

上游默认监听 `127.0.0.1:7863`，容器名 `workbuddy2api`。

### 第二步：拉取原版管理端

```powershell
cd C:\你的目录
git clone https://github.com/ithtelab/workbuddy-manager.git workbuddy-manager
cd workbuddy-manager
```

> 目录名建议保持 `workbuddy-manager`，并与上游 `workbuddy2api` **同级**，
> 因为 `start-manager.ps1` 会按同级目录自动推算上游路径。

### 第三步：用本仓库的文件覆盖原版

**方式 A：用 git 拉取（推荐，便于后续更新）**

`git checkout` 会按原目录结构取出文件，不会碰你其它文件：

```powershell
# 仍在 workbuddy-manager 目录下
git remote add winpatch https://github.com/zfgy-ma/WorkBuddy-Manager-on-Windows.git
git fetch winpatch
git checkout winpatch/main -- server/services/wb2api.py server/services/updater.py .gitignore start-manager.ps1 stop-manager.ps1 status-manager.ps1 部署说明-Windows.md
```

> 两点注意：
>
> 1. `git checkout` 会把取到的文件放进暂存区（`git status` 显示为 `A`/`M`），
>    不想要它们进版本库就别 `git commit`，不影响运行；
> 2. 本仓库目前是**私有仓库**，`git fetch` 会要求 GitHub 登录凭证。
>    拿不到权限时请改用方式 B。

**方式 B：下载后直接覆盖（最直观）**

下载本仓库压缩包，把里面的文件按**相同的目录结构**复制到原版管理端：

```
本仓库                              原版管理端
├─ server/services/wb2api.py   →   server\services\wb2api.py   （覆盖）
├─ server/services/updater.py  →   server\services\updater.py  （覆盖）
├─ .gitignore                  →   .gitignore                  （覆盖）
├─ start-manager.ps1           →   start-manager.ps1           （新增）
├─ stop-manager.ps1            →   stop-manager.ps1            （新增）
├─ status-manager.ps1          →   status-manager.ps1          （新增）
└─ 部署说明-Windows.md         →   部署说明-Windows.md         （新增）
```

一条命令完成（假设本仓库解压在 `C:\你的目录\WorkBuddy-Manager-on-Windows`）：

```powershell
cd C:\你的目录\WorkBuddy-Manager-on-Windows
Copy-Item .\server, .\start-manager.ps1, .\stop-manager.ps1, .\status-manager.ps1, .\.gitignore, .\部署说明-Windows.md -Destination ..\workbuddy-manager -Recurse -Force
```

覆盖成功的标志：`git status`（若原版是 git 克隆）显示
`server/services/wb2api.py`、`server/services/updater.py`、`.gitignore` 三处被修改。

> 若你拉取的原版比 `00d623c` 更新，且这两处代码被上游改过，
> 直接覆盖会**覆盖掉上游的新改动**。这种情况请先比对，再手工把那两行
> `encoding='utf-8', errors='replace'` 加上（见上文「修的是什么问题」）。

### 第四步：构建前端与 Python 环境

```powershell
# 构建前端静态产物（生成 web\out）
cd web
npm ci
npm run build:export
cd ..

# 创建虚拟环境并安装依赖
python -m venv venv
.\venv\Scripts\python.exe -m pip install -r server\requirements.txt
```

### 第五步：启动

```powershell
# 后台运行（推荐）
powershell -ExecutionPolicy Bypass -File .\start-manager.ps1 -Daemon

# 或前台运行，直接看实时日志
powershell -ExecutionPolicy Bypass -File .\start-manager.ps1
```

浏览器打开 **http://127.0.0.1:7864**，用 `admin` + 初始密码登录。

首次启动若不指定密码，会随机生成并打印到 `data\manager.err.log`：

```powershell
Select-String -Path .\data\manager.err.log -Pattern '初始管理员' -Context 0,3
```

### 第六步：添加账号

登录后进入「账号」页 → 「添加账号」→ 用微信 / QQ 扫码授权。
授权成功后自动签到并纳管，之后即可在「密钥」页创建调用密钥。

---
## 常用命令

```powershell
# 启动（后台）
powershell -ExecutionPolicy Bypass -File .\start-manager.ps1 -Daemon

# 启动（前台，看实时日志）
powershell -ExecutionPolicy Bypass -File .\start-manager.ps1

# 指定端口与初始管理员密码（密码仅首次启动生效）
powershell -ExecutionPolicy Bypass -File .\start-manager.ps1 -Daemon -Port 7864 -AdminPassword 你的强密码

# 查看运行状态
powershell -ExecutionPolicy Bypass -File .\status-manager.ps1

# 停止
powershell -ExecutionPolicy Bypass -File .\stop-manager.ps1
```

### 查看日志

```powershell
Get-Content .\data\manager.out.log -Tail 50 -Wait   # 标准输出
Get-Content .\data\manager.err.log -Tail 50         # 错误与启动信息

# 上游容器日志
docker logs -f workbuddy2api
```

### 网页端口

| 服务 | 端口 | 说明 |
|---|---|---|
| **管理网页** | **7864** | 浏览器访问 http://127.0.0.1:7864（本仓库默认值） |
| 上游反代 API | 7863 | OpenAI 兼容接口，由上游提供 |

管理端绑定 `0.0.0.0`，同一局域网可用 `http://本机IP:7864` 访问。
若被防火墙拦截，用管理员身份执行一次放行：

```powershell
New-NetFirewallRule -DisplayName "WorkBuddy Manager 7864" -Direction Inbound -Protocol TCP -LocalPort 7864 -Action Allow
```

端口可用 `-Port` 参数修改：

```powershell
powershell -ExecutionPolicy Bypass -File .\start-manager.ps1 -Daemon -Port 8080
```

### 环境变量怎么设置（PowerShell 与 bash 的差异）

Linux 教程里常见这种写法，**PowerShell 不支持**：

```bash
WB_ADMIN_PASSWORD=xxx \
WB_DATA_DIR=./data \
python -m uvicorn server.main:app
```

在 PowerShell 里粘贴这段会直接报错：

```
WB_ADMIN_PASSWORD=xxx : 术语 'WB_ADMIN_PASSWORD=xxx' 不会被识别为 cmdlet、函数、脚本文件或可执行程序的名称。
```

原因是 PowerShell 没有「命令前赋值」语法，`$env:` 前缀才是环境变量：

```powershell
$env:WB_ADMIN_PASSWORD = 'xxx'
$env:WB_DATA_DIR = './data'
.\venv\Scripts\python.exe -m uvicorn server.main:app --port 7864
```

注意三条：

1. 等号两侧**不要有空格**以外的符号，字符串用引号包住；
2. **不能用 `\` 续行**，一行一个变量；
3. `$env:` 只对**当前会话**有效，关掉窗口即失效。

本项目已把全部环境变量写进 `start-manager.ps1`，**一般无需手工设置**。

原版（Linux）与 Windows 的做法对照：

| 环节 | 原版 Linux | 本仓库 Windows |
|---|---|---|
| 服务托管 | systemd 单元 `workbuddy-web.service` | `start-manager.ps1` 后台运行 |
| 环境变量 | 写在 systemd 单元里 | 写在 `start-manager.ps1` 里 |
| 查看日志 | `journalctl -u workbuddy-web -f` | `Get-Content data\manager.err.log` |
| 重启 | `systemctl restart workbuddy-web` | `stop-manager.ps1` 后 `start-manager.ps1 -Daemon` |
| 开机自启 | `systemctl enable` | 未实现（需自行放入任务计划程序） |

---
## 原理说明：为什么 Windows 上会出错

原版这两处代码用 `text=True` 让 Python 自动解码子进程输出：

```python
proc = subprocess.run(cmd, capture_output=True, text=True, timeout=25)
```

Python 在 Windows 上遵循「区域编码」规则：
简体中文系统下 `text=True` 会用 **GBK（cp936）** 解码标准输出。
但 `docker logs` 与 `git` 输出的都是 **UTF-8**：

```
2026-09-13T02:20:55.073Z 2026/09/13 10:20:55 签到已启用：[9 21] 点
```

GBK 解不出 UTF-8 的中文字节，直接抛异常：

```
UnicodeDecodeError: 'gbk' codec can't decode byte 0xaa in position 158
```

修复后显式声明编码，与平台无关：

```python
proc = subprocess.run(cmd, capture_output=True, timeout=25,
                      encoding='utf-8', errors='replace')
```

---

## 未实现 / 已知差异

以下是原版在 Linux 上具备、Windows 版暂未实现的能力，属系统能力差异：

| 能力 | 说明 |
|---|---|
| 开机自启 | 原版用 systemd；Windows 需自行配置「任务计划程序」 |
| 崩溃自动重启 | 原版 `Restart=always`；Windows 无对应守护机制 |
| 一键更新 | 原版「设置 → 系统更新」依赖 `deploy/update.py` 与 systemd，Windows 下不可用 |

---

## 兼容性

| 项目 | 版本 |
|---|---|
| 原版管理端 | 默认分支 `00d623c`（v1.0.11 标签之后 3 个提交） |
| 上游 workbuddy2api | 最新 main 分支 |
| 验证环境 | Windows 11 + Python 3.12 + Node 24 + Docker Desktop 29 |

替换文件后，`python -m unittest discover -s server/tests -t .` 单元测试全部通过：

| 原版版本 | 覆盖后测试结果 |
|---|---|
| 默认分支 `00d623c` | 102 个测试通过 |
| `v1.0.11` 标签 | 94 个测试通过 |

两个版本的 `wb2api.py`、`updater.py`、`.gitignore` 与被改动的三处完全一致，
因此同一份替换文件可同时适用于它们。

> 原版后续升级后，若这两处代码未变，替换文件仍可直接覆盖使用；
> 若上游改动了这两处，请按本文「原理说明」手工把那两行补上，
> 不要整体覆盖，以免覆盖掉上游的新改动。

---

## 上游与致谢

- 管理端原版：[ithtelab/workbuddy-manager](https://github.com/ithtelab/workbuddy-manager)
- 上游反代：[Sliverkiss/workbuddy2api](https://github.com/Sliverkiss/workbuddy2api)
- 本仓库许可：MIT（同原版）

本仓库所有代码均来自上述上游，仅做 Windows 兼容性修补，版权归原作者所有。
