# WorkBuddy Manager 状态检查脚本（Windows）
# 用法：powershell -ExecutionPolicy Bypass -File status-manager.ps1

$Root = $PSScriptRoot

Write-Host "══ WorkBuddy Manager 状态 ══" -ForegroundColor Cyan

# ── 管理端进程与端口 ──────────────────────────────────
$PidFile = Join-Path $Root 'data\manager.pid'
$procId = if (Test-Path $PidFile) { (Get-Content $PidFile -Raw).Trim() } else { '' }
$p = if ($procId) { Get-Process -Id $procId -ErrorAction SilentlyContinue } else { $null }
if ($p) {
    Write-Host "[✓] 管理端进程运行中（PID $procId）" -ForegroundColor Green
} else {
    Write-Host "[✗] 管理端进程未运行" -ForegroundColor Red
}

$listen = Get-NetTCPConnection -LocalPort 7864 -State Listen -ErrorAction SilentlyContinue
if ($listen) {
    Write-Host "[✓] 端口 7864 正在监听（PID $($listen[0].OwningProcess)）" -ForegroundColor Green
} else {
    Write-Host "[✗] 端口 7864 未监听" -ForegroundColor Red
}

# ── 上游连通性 ────────────────────────────────────────
try {
    $r = Invoke-WebRequest "http://127.0.0.1:7864/healthz" -TimeoutSec 10 -UseBasicParsing
    Write-Host "[✓] 管理端健康检查：$($r.Content)" -ForegroundColor Green
} catch {
    Write-Host "[✗] 管理端健康检查失败：$($_.Exception.Message)" -ForegroundColor Red
}

# ── 上游容器 ──────────────────────────────────────────
Write-Host ""
Write-Host "上游容器：" -ForegroundColor Cyan
docker ps -a --filter name=workbuddy2api --format "  {{.Names}} | {{.Status}} | {{.Ports}}"

Write-Host ""
Write-Host "访问地址：http://127.0.0.1:7864" -ForegroundColor Green