# Windows 部署说明

本项目官方部署脚本 `deploy/install.sh` 面向 Linux + systemd。
Windows 下改用本仓库配套的 PowerShell 脚本完成同等部署。

---

## 一、部署现状

| 组件 | 位置 | 地址 | 说明 |
|---|---|---|---|
| 管理端 | `C:\你的目录\workbuddy-manager` | http://127.0.0.1:7864 | FastAPI + 已构建的静态前端 |
| 上游 workbuddy2api | `C:\你的目录\workbuddy2api` | http://127.0.0.1:7863 | Docker 容器 `workbuddy2api` |

管理端数据目录：`data\`（SQLite、用户与会话密钥，**含敏感信息，勿外传**）

---

## 二、日常操作

```powershell
# 启动（后台运行）
powershell -ExecutionPolicy Bypass -File .\start-manager.ps1 -Daemon

# 启动（前台运行，直接看实时日志）
powershell -ExecutionPolicy Bypass -File .\start-manager.ps1

# 指定端口与初始密码
powershell -ExecutionPolicy Bypass -File .\start-manager.ps1 -Daemon -Port 7864 -AdminPassword 你的密码

# 查看状态
powershell -ExecutionPolicy Bypass -File .\status-manager.ps1

# 停止
powershell -ExecutionPolicy Bypass -File .\stop-manager.ps1
```

> `-AdminPassword` **仅首次启动生效**（首次会生成 `data\users.json`）。
> 之后修改密码请在管理端「设置 → 管理用户」里操作。

---

## 三、环境变量怎么设置

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
若要临时覆盖，可在同一次会话里先执行：

```powershell
$env:WB2API_KEY = '上游密钥'
.\venv\Scripts\python.exe -m uvicorn server.main:app --port 7864
```

---

## 四、首次使用

1. 浏览器打开 http://127.0.0.1:7864
2. 用 `admin` + 初始密码登录（初始密码见下方「获取初始密码」）
3. 进入「账号」页 → 「添加账号」→ 用微信 / QQ 扫码授权
4. 授权成功后自动签到并纳管
5. 进入「密钥」页创建调用密钥，即可通过 `http://127.0.0.1:7864/v1` 调用

### 获取初始密码

- 部署时若已指定 `-AdminPassword`，就是那个密码；
- 否则查看 `data\manager.err.log`，搜索「初始管理员」；
- 历史密码记录在管理端目录 `data\_init_pwd.txt`。

---

## 五、与 Docker 的关系

管理端通过 `docker` 命令操作上游容器（读取日志、重启），因此：

- **Docker Desktop 必须处于运行状态**，否则管理端读不到上游状态；
- 上游容器名为 `workbuddy2api`，可通过 `WB2API_CONTAINER` 修改；
- 管理端配置的端口绑定为 `0.0.0.0`，局域网内其他设备也可访问
  （局域网 IP 形如 `http://192.168.x.x:7864`）。

---

## 六、若部署在公网服务器

本仓库的 Windows 脚本不能直接搬到 Linux 服务器。请改用官方流程：

```bash
git clone https://github.com/ithtelab/workbuddy-manager.git
cd workbuddy-manager
cd web && npm ci && npm run build:export && cd ..
sudo bash deploy/install.sh
```

公网访问**务必**在管理端前配置 HTTPS 反向代理，否则会话 Cookie 与密码会被明文传输。
详见官方 `deploy/README.md`。