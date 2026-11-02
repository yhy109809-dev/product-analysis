# restore.ps1 — 从备份恢复 Memos 并核对
# 用法: .\restore.ps1 -BackupDir "D:\memos-backup\20261108-120000"

param([string]$BackupDir)
$ErrorActionPreference = 'Stop'

if (-not (Test-Path "$BackupDir\memos_prod.db")) { throw "备份目录不完整: $BackupDir" }

# 1. 停容器
docker stop memos | Out-Null

# 2. 回填数据库与附件
docker cp "$BackupDir\memos_prod.db" memos:/var/opt/memos/memos_prod.db
if (Test-Path "$BackupDir\assets") {
    docker cp "$BackupDir\assets" memos:/var/opt/memos/
}

# 3. 启动
docker start memos | Out-Null
Start-Sleep -Seconds 5

# 4. 核对（与 manifest 对比）
$manifest = Get-Content "$BackupDir\manifest.json" -Raw | ConvertFrom-Json
$assets = (docker exec memos sh -c 'find /var/opt/memos/assets -type f | wc -l')
Write-Host "备份附件数: $($manifest.assets)  恢复后: $assets"

$code = (Invoke-WebRequest "http://localhost:5230" -UseBasicParsing -TimeoutSec 10).StatusCode
if ($code -ne 200) { throw "恢复后服务不可用: $code" }
Write-Host "恢复完成，服务 200" -ForegroundColor Green
