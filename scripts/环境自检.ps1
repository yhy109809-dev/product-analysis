# 环境自检：挂梯子前后各跑一次，对比结果即可判断有没有被影响
# 用法：.\环境自检.ps1

$ErrorActionPreference = 'SilentlyContinue'
$ok = @()
$bad = @()

Write-Host "===== Docker / Memos 环境自检 =====" -ForegroundColor Cyan
Write-Host ("时间: " + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
Write-Host ""

# 1. Docker 引擎
$ver = docker info --format '{{.ServerVersion}}' 2>$null
if ($ver) { Write-Host "[OK] Docker 引擎 $ver" -ForegroundColor Green } else { Write-Host "[FAIL] Docker 引擎未就绪" -ForegroundColor Red; $bad += 'engine' }

# 2. 容器
$ps = docker ps --format '{{.Names}}|{{.Status}}|{{.Ports}}' 2>$null
if ($ps -match 'memos') { Write-Host "[OK] $ps" -ForegroundColor Green } else { Write-Host "[FAIL] memos 容器未运行" -ForegroundColor Red; $bad += 'memos' }

# 3. 端口监听与发布
$listen = Get-NetTCPConnection -LocalPort 5230 -State Listen -ErrorAction SilentlyContinue
if ($listen) { Write-Host ("[OK] 5230 正在监听: " + ($listen | Select-Object -First 1).LocalAddress) -ForegroundColor Green } else { Write-Host "[FAIL] 5230 没有监听" -ForegroundColor Red; $bad += 'listen' }

# 4. 本机访问
$code = $null
try { $code = (Invoke-WebRequest "http://localhost:5230" -TimeoutSec 8 -UseBasicParsing).StatusCode } catch { }
if ($code -eq 200) { Write-Host "[OK] http://localhost:5230 -> 200" -ForegroundColor Green } else { Write-Host "[FAIL] localhost:5230 无法访问" -ForegroundColor Red; $bad += 'http' }

# 5. 局域网地址
$ip = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias WLAN -ErrorAction SilentlyContinue).IPAddress
if ($ip) { Write-Host "[OK] WLAN 地址: $ip  ->  http://${ip}:5230" -ForegroundColor Green } else { Write-Host "[WARN] 未获取到 WLAN 地址" -ForegroundColor Yellow }

# 6. 防火墙放行规则（Docker 自动创建）
$rules = Get-NetFirewallRule -DisplayName 'com.docker.backend.exe' -ErrorAction SilentlyContinue | Where-Object Enabled -eq 'True'
if ($rules) { Write-Host ("[OK] Docker 程序级放行规则: " + $rules.Count + " 条已启用") -ForegroundColor Green } else { Write-Host "[WARN] Docker 放行规则未启用，局域网将无法访问 5230" -ForegroundColor Yellow; $bad += 'firewall' }

# 7. 系统代理状态（只影响 Docker 启动阶段）
$k = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
$pe = (Get-ItemProperty $k).ProxyEnable
$srv = (Get-ItemProperty $k).ProxyServer
if ($pe -eq 0) { Write-Host "[OK] 系统代理未启用" -ForegroundColor Green } else { Write-Host "[注意] 系统代理已启用: $srv （启动 Docker 前建议关闭，或改用 启动Memos.ps1）" -ForegroundColor Yellow }

# 8. WSL 网络模式
$wc = "$env:USERPROFILE\.wslconfig"
$mode = if (Test-Path $wc) { (Select-String -Path $wc -Pattern 'networkingMode' -ErrorAction SilentlyContinue | Select-Object -First 1).Line } else { '默认(NAT)' }
Write-Host "[信息] WSL 网络模式: $mode"

Write-Host ""
if ($bad.Count -eq 0) {
    Write-Host "结论: 环境正常，可以正常访问 Memos" -ForegroundColor Green
} else {
    Write-Host ("结论: 存在问题 -> " + ($bad -join ', ')) -ForegroundColor Red
    Write-Host "可尝试执行 .\启动Memos.ps1 自动修复" -ForegroundColor Yellow
}
