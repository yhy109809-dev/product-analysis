# backup.ps1 — 备份 Memos（SQLite 一致性备份 + 附件 + 清单）
# 用法: .\backup.ps1 -OutDir "D:\memos-backup"

param([string]$OutDir = "D:\memos-backup")
$ErrorActionPreference = 'Stop'

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$dest  = Join-Path $OutDir $stamp
New-Item -ItemType Directory -Path $dest -Force | Out-Null

# 1. 数据库：WAL 模式下必须用 .backup，不能直接复制文件
#    若镜像内没有 sqlite3，改为: docker stop memos; docker cp memos:/var/opt/memos $dest; docker start memos
docker exec memos sh -c 'sqlite3 /var/opt/memos/memos_prod.db ".backup /tmp/memos.db"'
docker cp memos:/tmp/memos.db "$dest\memos_prod.db"

# 2. 附件
docker cp memos:/var/opt/memos/assets "$dest\assets"

# 3. 清单
$manifest = [ordered]@{
    time       = (Get-Date -Format 's')
    version    = (docker inspect memos --format '{{.Config.Image}}')
    digest     = (docker image inspect neosmemo/memos:stable --format '{{index .RepoDigests 0}}')
    dbBytes    = (Get-Item "$dest\memos_prod.db").Length
    assets     = (Get-ChildItem "$dest\assets" -Recurse -File | Measure-Object).Count
}
$manifest | ConvertTo-Json | Out-File "$dest\manifest.json" -Encoding utf8

Write-Host "备份完成: $dest" -ForegroundColor Green
