<#
.SYNOPSIS
    Antigravity 一键安全回滚脚本 (独立产物套件版)
.DESCRIPTION
    将 Antigravity 还原到官方纯净原版 ASAR 资源及初始快捷方式状态。
#>

[CmdletBinding()]
param (
    [string]$AppDir = 'C:\Users\123\AppData\Local\Programs\antigravity',
    [string]$BackupDir,
    [switch]$RemoveProxy,
    [switch]$CloseRunningProcess,
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
$toolsDir = $PSScriptRoot
$toolkitDir = Split-Path $toolsDir -Parent

function Get-FileSha256([string]$filePath) {
    if (-not (Test-Path -LiteralPath $filePath)) { return $null }
    $stream = [System.IO.File]::OpenRead($filePath)
    try {
        $sha256 = [System.Security.Cryptography.SHA256]::Create()
        $hashBytes = $sha256.ComputeHash($stream)
        return (-join ($hashBytes | ForEach-Object { '{0:X2}' -f $_ }))
    } finally {
        $stream.Close()
    }
}

function Log-Section([string]$title) {
    if (-not $Quiet) {
        Write-Host "`n==== $title ====" -ForegroundColor Cyan
    }
}

function Log-Success([string]$msg) {
    if (-not $Quiet) {
        Write-Host "  [OK]   $msg" -ForegroundColor Green
    }
}

function Log-Warn([string]$msg) {
    if (-not $Quiet) {
        Write-Host "  [WARN] $msg" -ForegroundColor Yellow
    }
}

# 1. 查找备份源
Log-Section "1. 定位安全基准备份"
if (-not $BackupDir) {
    $searchRoots = @(
        (Join-Path $toolkitDir 'outputs\antigravity-*'),
        (Join-Path $toolkitDir 'outputs\backup-*'),
        (Join-Path $toolkitDir 'backups'),
        (Join-Path $toolkitDir '..\backup-*'),
        (Join-Path $toolkitDir '..\antigravity-*')
    )
    $candidates = @()
    foreach ($r in $searchRoots) {
        $parent = Split-Path $r -Parent
        $leaf = Split-Path $r -Leaf
        if (Test-Path -LiteralPath $parent) {
            $candidates += Get-ChildItem -Path $parent -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like $leaf }
        }
    }
    $candidates = $candidates | Sort-Object LastWriteTime -Descending
    foreach ($cand in $candidates) {
        $p1 = Join-Path $cand.FullName 'app.asar'
        $p2 = Join-Path $cand.FullName 'backup\app.asar'
        if (Test-Path -LiteralPath $p1) {
            $BackupDir = $cand.FullName
            break
        } elseif (Test-Path -LiteralPath $p2) {
            $BackupDir = Join-Path $cand.FullName 'backup'
            break
        }
    }
}

if (-not $BackupDir -or -not (Test-Path -LiteralPath (Join-Path $BackupDir 'app.asar'))) {
    throw "未找到有效的 app.asar 备份目录！请通过 -BackupDir 指定备份路径。"
}
Log-Success "使用备份源: $BackupDir"

# 2. 进程检查
$runningProcs = Get-Process Antigravity, language_server -ErrorAction SilentlyContinue
if ($runningProcs) {
    if ($CloseRunningProcess) {
        Log-Warn "检测到 Antigravity 正在运行，正在关闭进程..."
        $runningProcs | Stop-Process -Force
        Start-Sleep -Seconds 2
        Log-Success "进程已关闭。"
    } else {
        throw "Antigravity 正在运行中，请先退出应用或使用 -CloseRunningProcess。"
    }
}

# 3. 还原 app.asar
Log-Section "2. 还原官方原生 app.asar"
$targetAsar = Join-Path $AppDir 'resources\app.asar'
$sourceAsar = Join-Path $BackupDir 'app.asar'
Copy-Item -LiteralPath $sourceAsar -Destination $targetAsar -Force
$restoredHash = Get-FileSha256 $targetAsar
$srcHash = Get-FileSha256 $sourceAsar
if ($restoredHash -ne $srcHash) {
    throw "还原后 app.asar 哈希校验失败！"
}
Log-Success "已成功还原官方原生 app.asar (SHA256: $restoredHash)"

# 4. 还原快捷方式
Log-Section "3. 还原快捷方式"
$shortcuts = @(
    'C:\Users\123\Desktop\Antigravity.lnk',
    'C:\Users\123\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Antigravity.lnk'
)
$shell = New-Object -ComObject WScript.Shell
$mainExe = Join-Path $AppDir 'Antigravity.exe'

for ($i = 0; $i -lt $shortcuts.Count; $i++) {
    $sc = $shortcuts[$i]
    $backupSc = Join-Path $BackupDir "shortcut-$i.lnk"
    if (Test-Path -LiteralPath $backupSc) {
        Copy-Item -LiteralPath $backupSc -Destination $sc -Force
        Log-Success "从备份副本还原快捷方式: $sc"
    } else {
        # 如果没有备份副本，重设为指向官方 Antigravity.exe
        $lnk = $shell.CreateShortcut($sc)
        $lnk.TargetPath = $mainExe
        $lnk.Arguments = ''
        $lnk.WorkingDirectory = $AppDir
        $lnk.IconLocation = "$mainExe,0"
        $lnk.Save()
        Log-Success "重置快捷方式为官方默认目标: $sc"
    }
}

# 5. 可选清理代理文件
if ($RemoveProxy) {
    Log-Section "4. 移除代理补丁文件"
    $proxyFiles = @('version.dll', 'config.json', 'launch-antigravity-65532.vbs')
    foreach ($f in $proxyFiles) {
        $fp = Join-Path $AppDir $f
        if (Test-Path -LiteralPath $fp) {
            Remove-Item -LiteralPath $fp -Force
            Log-Success "已删除代理文件: $f"
        }
    }
}

Log-Section "回滚完毕"
Log-Success "Antigravity 已恢复至官方原生配置！"
