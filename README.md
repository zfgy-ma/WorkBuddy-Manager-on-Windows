# WorkBuddy Manager-on-Windows

**WorkBuddy Manager 的 Windows 兼容补丁仓库**

本仓库是 [ithtelab/workbuddy-manager](https://github.com/ithtelab/workbuddy-manager) 的
**Windows 兼容修复补丁**，只用于让原版管理端在 Windows 上正常运行。
**不新增功能、不改动业务逻辑、不包含上游、不含原版完整源码。**

---

## ⚠️ 重要声明（务必先读）

### 1. 本仓库不含上游 workbuddy2api

原版 WorkBuddy Manager 只是**管理端界面**。账号轮询、并发调度、签到、
OpenAI 兼容接口全部由上游 [`workbuddy2api`](https://github.com/Sliverkiss/workbuddy2api)
（Go 项目，Docker 部署）负责。本仓库**不含上游代码，也不替代上游**。

### 2. 单独 clone 本仓库无法运行

本仓库**只有补丁文件，没有原版源码**，clone 下来什么也跑不起来。

完整运行需要三样东西同时就位：

| 必需组件 | 来源 | 作用 |
|---|---|---|
| 上游 `workbuddy2api` | [Sliverkiss/workbuddy2api](https://github.com/Sliverkiss/workbuddy2api) | 账号池调度 + OpenAI 兼容接口（Docker） |
| 原版管理端源码 | [ithtelab/workbuddy-manager](https://github.com/ithtelab/workbuddy-manager) | 管理界面 + 对外网关 |
| Windows 适配补丁 | **本仓库** | 让管理端在 Windows 上跑通 |

### 3. 本项目只做一件事：修复 Windows 兼容性

本仓库仅解决原版管理端在 Windows 上无法运行的问题。
**Linux 用户请直接使用原版，不需要本仓库。**

---

## 本仓库内容：仅新增/修改部分

本仓库不包含原版那 150 多个源文件，只保留以下两新增 / 两修改。

### 一、新增文件（直接复制到原版对应位置即可）

| 文件 | 放到原版的位置 | 用途 |
|---|---|---|
| `start-manager.ps1` | 仓库根目录 | 启动管理端，等价于原版 Linux 版 systemd 服务，内置全部环境变量 |
| `stop-manager.ps1` | 仓库根目录 | 停止管理端，并清理残留的端口监听进程 |
| `status-manager.ps1` | 仓库根目录 | 查看管理端进程、端口、健康检查与上游容器状态 |
| `部署说明-Windows.md` | 仓库根目录 | 本机部署说明，含 PowerShell 环境变量写法差异 |

### 二、修改文件（只提供补丁，需应用到原版源码）

原版用 `subprocess(..., text=True)` 读取子进程输出。
Python 在 Windows 上会按系统区域编码（简体中文系统为 **GBK**）解码，
而 `docker logs` 与 `git` 输出的是 **UTF-8**（上游日志含中文），于是抛异常：

```
UnicodeDecodeError: 'gbk' codec can't decode byte 0xaa in position 158
```

**实际影响**：「任务记录」页读容器日志的线程崩溃，自动任务日志采集完全失效。

| 补丁文件 | 目标文件 | 修复内容 |
|---|---|---|
| `patches/wb2api-编码修复.patch` | `server/services/wb2api.py` | `read_container_logs()` 显式用 UTF-8 解码 |
| `patches/updater-编码修复.patch` | `server/services/updater.py` | `_local_upstream_head()` 显式用 UTF-8 解码 |
| `patches/gitignore-忽略旧内容.patch` | `.gitignore` | 忽略本地备份目录 `旧内容/` |

修复方式均为：`text=True` → `encoding='utf-8', errors='replace'`。

> Linux 下行为完全不变（原本就是 UTF-8），因此该修复对原版无副作用。
> `errors='replace'` 保证个别坏字节只显示为 `?`，不会让整个功能崩溃。

---

## 使用方法

### 前提条件

| 依赖 | 要求 | 用途 |
|---|---|---|
| Python | ≥ 3.9 | 运行管理端 |
| Node.js | ≥ 18 | 构建前端（仅首次需要） |
| Docker Desktop | 已运行 | 跑上游 workbuddy2api |
| Git | 任意版本 | 拉取代码与应用补丁 |

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

### 第三步：应用本仓库（两种方式任选）

**方式 A：用 git 拉取补丁仓库（推荐，便于后续更新）**

```powershell
git remote add winpatch https://github.com/zfgy-ma/WorkBuddy-Manager-on-Windows.git
git fetch winpatch
git merge winpatch/main --allow-unrelated-histories
```

**方式 B：手工复制**

1. 下载本仓库，把 4 个新增文件复制到原版管理端**根目录**；
2. 逐个应用 3 个补丁：

```powershell
git apply 路径\patches\wb2api-编码修复.patch
git apply 路径\patches\updater-编码修复.patch
git apply 路径\patches\gitignore-忽略旧内容.patch
```

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

### 端口说明

| 服务 | 端口 | 说明 |
|---|---|---|
| 管理网页 | **7864** | 浏览器访问 http://127.0.0.1:7864 |
| 上游反代 API | 7863 | OpenAI 兼容接口，由上游提供 |

管理端绑定 `0.0.0.0`，同一局域网可用 `http://本机IP:7864` 访问。
若被防火墙拦截，用管理员身份执行一次放行：

```powershell
New-NetFirewallRule -DisplayName "WorkBuddy Manager 7864" -Direction Inbound -Protocol TCP -LocalPort 7864 -Action Allow
```

### 环境变量怎么设置（PowerShell 与 bash 的差异）

Linux 教程里常见这种写法，**PowerShell 不支持**：

```bash
WB_ADMIN_PASSWORD=xxx \
WB_DATA_DIR=./data \
python -m uvicorn server.main:app
```

PowerShell 的等价写法是 `$env:` 前缀，且不能用 `\` 续行：

```powershell
$env:WB_ADMIN_PASSWORD = 'xxx'
$env:WB_DATA_DIR = './data'
.\venv\Scripts\python.exe -m uvicorn server.main:app --port 7864
```

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
| 原版管理端 | v1.0.11（对应 commit `00d623c`） |
| 上游 workbuddy2api | 最新 main 分支 |
| 验证环境 | Windows 11 + Python 3.12 + Node 24 + Docker Desktop 29 |

> 原版后续升级后，若这两处代码未变，补丁仍可直接应用；
> 若已变动导致冲突，请重新按本文「原理说明」自行调整。

---

## 上游与致谢

- 管理端原版：[ithtelab/workbuddy-manager](https://github.com/ithtelab/workbuddy-manager)
- 上游反代：[Sliverkiss/workbuddy2api](https://github.com/Sliverkiss/workbuddy2api)
- 本仓库许可：MIT（同原版）
