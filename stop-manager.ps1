# WorkBuddy Manager 停止脚本（Windows）

$ErrorActionPreference = 'Stop'
$Root    = $PSScriptRoot
$PidFile = Join-Path $Root 'data\manager.pid'

if (-not (Test-Path $PidFile)) {
    Write-Host "未找到 PID 文件，管理端可能未在运行" -ForegroundColor Yellow
    exit 0
}

$procId = (Get-Content $PidFile -Raw).Trim()

# 顺带停掉子进程（uvicorn 在 Windows 上会再派生一个进程）
$children = Get-CimInstance Win32_Process -Filter "ParentProcessId=$procId" -ErrorAction SilentlyContinue
foreach ($c in $children) {
    Write-Host "停止子进程 $($c.ProcessId)" -ForegroundColor DarkGray
    Stop-Process -Id $c.ProcessId -Force -ErrorAction SilentlyContinue
}

$p = Get-Process -Id $procId -ErrorAction SilentlyContinue
if ($p) {
    Stop-Process -Id $procId -Force
    Write-Host "管理端已停止（PID $procId）" -ForegroundColor Green
} else {
    Write-Host "进程 $procId 已不存在" -ForegroundColor Yellow
}

Remove-Item -LiteralPath $PidFile -Force -ErrorAction SilentlyContinue

# 兜底：清理仍占用 7864 端口的残留进程
Start-Sleep -Seconds 2
$left = Get-NetTCPConnection -LocalPort 7864 -State Listen -ErrorAction SilentlyContinue
foreach ($conn in $left) {
    Write-Host "清理残留监听进程 $($conn.OwningProcess)" -ForegroundColor DarkYellow
    Stop-Process -Id $conn.OwningProcess -Force -ErrorAction SilentlyContinue
}