# 启动 Memos（挂梯子前后都可安全运行）
# 用法：右键"使用 PowerShell 运行"，或在终端执行  .\启动Memos.ps1

$ErrorActionPreference = 'SilentlyContinue'

# 1) 临时关闭系统代理，避免 Docker 启动阶段被 WSL 代理问题卡住
$k = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
$oldProxy = (Get-ItemProperty $k).ProxyEnable
if ($oldProxy -ne 0) {
    Set-ItemProperty $k -Name ProxyEnable -Value 0
    Write-Host "[1/4] 已临时关闭系统代理" -ForegroundColor Yellow
} else {
    Write-Host "[1/4] 系统代理本来就没开" -ForegroundColor DarkGray
}

# 2) 确保 Docker Desktop 在运行
$exe = "$env:LOCALAPPDATA\Programs\DockerDesktop\Docker Desktop.exe"
if (-not (Get-Process 'com.docker.backend' -ErrorAction SilentlyContinue)) {
    Write-Host "[2/4] 正在启动 Docker Desktop..." -ForegroundColor Cyan
    Start-Process -FilePath $exe
} else {
    Write-Host "[2/4] Docker Desktop 已在运行" -ForegroundColor DarkGray
}

$ok = $false
for ($i = 0; $i -lt 60; $i++) {
    Start-Sleep -Seconds 3
    docker info --format '{{.ServerVersion}}' 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) { $ok = $true; break }
}

# 3) 恢复系统代理设置（只在启动阶段需要关闭）
if ($oldProxy -ne 0) {
    Set-ItemProperty $k -Name ProxyEnable -Value $oldProxy
    Write-Host "[3/4] 已恢复系统代理设置" -ForegroundColor DarkGray
}

if (-not $ok) {
    Write-Host "[失败] Docker 引擎 180 秒内未就绪，请查看 Docker Desktop 窗口的报错" -ForegroundColor Red
    exit 1
}

# 4) 启动 Memos 容器并验证
docker start memos 2>$null | Out-Null
Start-Sleep -Seconds 8

$status = docker ps --format '{{.Names}} {{.Status}} {{.Ports}}' 2>$null
$code = $null
try { $code = (Invoke-WebRequest "http://localhost:5230" -TimeoutSec 8 -UseBasicParsing).StatusCode } catch { }

Write-Host ""
Write-Host "容器: $status"
if ($code -eq 200) {
    Write-Host "本机访问: HTTP 200  ->  http://localhost:5230" -ForegroundColor Green
    Write-Host "局域网访问: 见 环境自检.ps1 输出的 WLAN 地址" -ForegroundColor Green
} else {
    Write-Host "本机访问失败，尝试重建容器：" -ForegroundColor Red
    Write-Host '  docker rm -f memos; docker run -d --name memos -p 5230:5230 -v "C:\Users\DingSuYa\.memos:/var/opt/memos" neosmemo/memos:stable'
}
