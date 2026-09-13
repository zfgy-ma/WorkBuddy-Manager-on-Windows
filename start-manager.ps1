# WorkBuddy Manager 管理端启动脚本（Windows）
#
# 用法：
#   powershell -ExecutionPolicy Bypass -File start-manager.ps1            # 前台运行（看实时日志）
#   powershell -ExecutionPolicy Bypass -File start-manager.ps1 -Daemon    # 后台运行（日志落盘）
#
# 说明：本脚本等价于 Linux 版 deploy/install.sh 注册的 systemd 服务，
#       只是把环境变量与启动命令搬到 Windows 上执行。

param(
    # 后台运行
    [switch]$Daemon,
    # 管理端监听端口
    [int]$Port = 7864,
    # 首次启动的初始管理员密码（留空则随机生成并打印一次）
    [string]$AdminPassword = ''
)

$ErrorActionPreference = 'Stop'

# 管理端根目录
$Root        = $PSScriptRoot
# 上游仓库目录（与本项目同级）
$UpstreamDir = Join-Path (Split-Path $Root -Parent) 'workbuddy2api'
$Python      = Join-Path $Root 'venv\Scripts\python.exe'

# ── 本服务 ──────────────────────────────────────────────
$env:WB_MANAGER_HOST   = '0.0.0.0'
$env:WB_MANAGER_PORT   = "$Port"
# 本机 http 访问仍可登录；走 HTTPS 反代时自动加 Secure
$env:WB_SECURE_COOKIE  = 'auto'
$env:WB_SESSION_DAYS   = '7'
$env:WB_CORS_ORIGINS   = ''

# ── 上游 workbuddy2api ──────────────────────────────────
$env:WB2API_BASE      = 'http://127.0.0.1:7863'
# 留空则自动读取上游 config.json 里的 api_key
$env:WB2API_KEY       = ''
$env:WB2API_CONTAINER = 'workbuddy2api'

# ── 上游数据文件（与 workbuddy2api 共享）────────────────
$env:WB_AUTH_DIR        = Join-Path $UpstreamDir 'auths'
$env:WB_UPSTREAM_CONFIG = Join-Path $UpstreamDir 'config.json'
$env:WB_UPSTREAM_DIR    = $UpstreamDir

# ── 本管理端数据 ────────────────────────────────────────
$env:WB_DATA_DIR   = Join-Path $Root 'data'
$env:WB_DB         = Join-Path $Root 'data\manager.db'
$env:WB_USERS_FILE = Join-Path $Root 'data\users.json'
$env:WB_STATIC_DIR = Join-Path $Root 'web\out'

# ── 网络与安全 ──────────────────────────────────────────
$env:WB_UPSTREAM_TIMEOUT   = '120'
$env:WB_TENCENT_TIMEOUT    = '15'
$env:WB_TRUST_PROXY        = '1'
$env:WB_TRUSTED_PROXY_HOPS = '1'
# 生产环境不暴露 /docs 与 openapi.json
$env:WB_ENABLE_DOCS        = '0'
# 留空：内网请求不走系统代理，避免被劫持
$env:WB_HTTP_PROXY         = ''

# 首次启动若传入密码则使用它，否则由服务随机生成并打印一次
if ($AdminPassword) { $env:WB_ADMIN_PASSWORD = $AdminPassword }
# ── 前置检查 ────────────────────────────────────────────
if (-not (Test-Path $Python)) {
    throw "未找到 Python 虚拟环境：$Python`n请先在项目根目录执行：python -m venv venv; .\venv\Scripts\python.exe -m pip install -r server\requirements.txt"
}
if (-not (Test-Path (Join-Path $Root 'web\out\index.html'))) {
    throw "未找到前端产物 web\out，请先在 web 目录执行：npm ci; npm run build:export"
}
if (-not (Test-Path $UpstreamDir)) {
    Write-Warning "未找到上游目录 $UpstreamDir，账号与配置相关功能将不可用"
}

Set-Location $Root

if ($Daemon) {
    # 后台运行：日志写入 data\manager.out.log 与 data\manager.err.log
    $OutLog = Join-Path $Root 'data\manager.out.log'
    $ErrLog = Join-Path $Root 'data\manager.err.log'
    $uvArgs = @('-m', 'uvicorn', 'server.main:app', '--host', '0.0.0.0', '--port', "$Port")
    $proc = Start-Process -FilePath $Python -ArgumentList $uvArgs -WorkingDirectory $Root `
        -RedirectStandardOutput $OutLog -RedirectStandardError $ErrLog `
        -WindowStyle Hidden -PassThru
    Start-Sleep -Seconds 4
    if ($proc.HasExited) {
        Write-Host "启动失败，最近日志：" -ForegroundColor Red
        Get-Content $ErrLog -Tail 30 -ErrorAction SilentlyContinue
        exit 1
    }
    Set-Content -Path (Join-Path $Root 'data\manager.pid') -Value $proc.Id -Encoding ascii
    Write-Host "管理端已后台运行（PID $($proc.Id)）" -ForegroundColor Green
    Write-Host "  访问地址: http://127.0.0.1:$Port"
    Write-Host "  标准日志: $OutLog"
    Write-Host "  错误日志: $ErrLog"
    Write-Host "  停止命令: Stop-Process -Id $($proc.Id)"
} else {
    Write-Host "管理端前台运行中，访问 http://127.0.0.1:$Port （Ctrl+C 停止）" -ForegroundColor Green
    & $Python -m uvicorn server.main:app --host 0.0.0.0 --port $Port
}
