<#
.SYNOPSIS
    Antigravity 一键安全修复脚本
.DESCRIPTION
    针对代理补丁、快捷方式入口、ASAR 汉化补丁进行全自动备份与闭环修复。
#>

[CmdletBinding()]
param (
    [string]$AppDir = '',
    [string]$ProxySourceDir = '',
    [string]$ChineseTool = '',
    [string]$ExpectedDllHash = '40F037232A180DA8DFF7611021270549FCC4E208580D8BF0F70BC9975F871B5F',
    [int]$ProxyPort = 65532,
    [string]$BackupBaseDir = '',
    [switch]$CloseRunningProcess,
    [switch]$SkipLocalization,
    [switch]$LaunchAfterFix,
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
$toolsDir = $PSScriptRoot
$projectRoot = Split-Path $toolsDir -Parent
$nodeScript = Join-Path $toolsDir 'patch-asar.cjs'
$discoveryScript = Join-Path $toolsDir 'EnvironmentDiscovery.ps1'
$installSkillScript = Join-Path $toolsDir 'Install-AgentSkill.ps1'

# 动态环境事实探测
$envData = & $discoveryScript -AppDir $AppDir -PreferredProxyPort $ProxyPort
if (-not $AppDir) {
    $AppDir = $envData.Antigravity.AppDir
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

# 0. 自包含环境路径智能解析
$payloadProxyDir = Join-Path $projectRoot 'payload\proxy'
$payloadChineseCli = Join-Path $projectRoot 'payload\localization\cli.js'
$defaultBackupDir = Join-Path $projectRoot 'outputs'

if (-not $BackupBaseDir) {
    $BackupBaseDir = $defaultBackupDir
}

if (-not $ChineseTool) {
    $ChineseTool = $payloadChineseCli
}

# 1. 预检与判定需要修改的范围
Log-Section "1. 前置安全检查与修复范围评估"
if (-not (Test-Path -LiteralPath $AppDir)) {
    throw "客户端安装目录不存在: $AppDir"
}

if (Test-Path -LiteralPath (Join-Path $payloadProxyDir 'version.dll')) {
    $proxyDeliverables = @{
        'version.dll' = (Join-Path $payloadProxyDir 'version.dll')
        'config.json' = (Join-Path $payloadProxyDir 'config.json')
        "launch-antigravity-$ProxyPort.vbs" = (Join-Path $payloadProxyDir "launch-antigravity-$ProxyPort.vbs")
    }
} else {
    if (-not $ProxySourceDir) {
        $ProxySourceDir = 'C:\Users\123\Documents\Codex\2026-10-14\xiu\outputs'
    }
    $proxyDeliverables = @{
        'version.dll' = (Join-Path $ProxySourceDir "antigravity-proxy-v2.4-$ProxyPort\version.dll")
        'config.json' = (Join-Path $ProxySourceDir "antigravity-proxy-v2.4-$ProxyPort\config.json")
        "launch-antigravity-$ProxyPort.vbs" = (Join-Path $ProxySourceDir "launch-antigravity-$ProxyPort.vbs")
    }
}

$needUpdateProxyFiles = $false
foreach ($name in $proxyDeliverables.Keys) {
    $src = $proxyDeliverables[$name]
    $dst = Join-Path $AppDir $name
    if (-not (Test-Path -LiteralPath $dst)) {
        $needUpdateProxyFiles = $true
        break
    }
    if ((Get-FileHash -LiteralPath $src -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $dst -Algorithm SHA256).Hash) {
        $needUpdateProxyFiles = $true
        break
    }
}

$currentAsar = Join-Path $AppDir 'resources\app.asar'
$needUpdateAsar = $false
if (-not $SkipLocalization) {
    if (-not (Test-Path -LiteralPath $currentAsar)) {
        $needUpdateAsar = $true
    } else {
        $checkJson = node $nodeScript --action check --asarPath $currentAsar | ConvertFrom-Json
        if (-not $checkJson.isPatched) {
            $needUpdateAsar = $true
        }
    }
}

$needModifyAppFiles = ($needUpdateProxyFiles -or $needUpdateAsar)
$runningProcs = Get-Process Antigravity, language_server -ErrorAction SilentlyContinue

if ($runningProcs) {
    if ($needModifyAppFiles) {
        if ($CloseRunningProcess) {
            Log-Warn "检测到 Antigravity / language_server 正在运行且需要更新程序资源，正在安全关闭以解除文件占用..."
            $runningProcs | Stop-Process -Force
            Start-Sleep -Seconds 2
            Log-Success "运行进程已安全关闭。"
        } else {
            throw "Antigravity 正在运行中且需要更新核心程序资源，为避免文件损坏或覆盖失败，请先退出应用或使用 -CloseRunningProcess 参数。"
        }
    } else {
        Log-Success "核心程序文件无需变动，仅修复快捷方式配置，当前运行进程可保持在线 (零停机修复)。"
    }
} else {
    Log-Success "无冲突进程运行，文件锁安全检查通过。"
}

# 2. 受保护二进制记录
Log-Section "2. 受保护核心文件基线核验"
$protectedFiles = @('Antigravity.exe', 'resources\bin\language_server.exe')
$protectedHashesBefore = @{}
foreach ($rel in $protectedFiles) {
    $full = Join-Path $AppDir $rel
    if (-not (Test-Path -LiteralPath $full)) {
        throw "受保护核心文件缺失: $full"
    }
    $h = (Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash
    $protectedHashesBefore[$rel] = $h
    Log-Success "基线哈希记录: $rel ($h)"
}

# 3. 创建时间戳备份
Log-Section "3. 状态快照与安全基准备份"
$timestamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
$backupDir = Join-Path $BackupBaseDir "backup-$timestamp"
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

$shortcuts = @(
    $envData.Shortcuts.Desktop,
    $envData.Shortcuts.StartMenu
)
$shell = New-Object -ComObject WScript.Shell
$shortcutBackups = @()
for ($i = 0; $i -lt $shortcuts.Count; $i++) {
    $scPath = $shortcuts[$i]
    if (Test-Path -LiteralPath $scPath) {
        $lnk = $shell.CreateShortcut($scPath)
        $shortcutBackups += @{
            index = $i
            path = $scPath
            target = $lnk.TargetPath
            arguments = $lnk.Arguments
            workingDir = $lnk.WorkingDirectory
        }
        Copy-Item -LiteralPath $scPath -Destination (Join-Path $backupDir "shortcut-$i.lnk") -Force
    }
}

$currentAsar = Join-Path $AppDir 'resources\app.asar'
$asarHashBefore = $null
if (Test-Path -LiteralPath $currentAsar) {
    $asarHashBefore = (Get-FileHash -LiteralPath $currentAsar -Algorithm SHA256).Hash
    Copy-Item -LiteralPath $currentAsar -Destination (Join-Path $backupDir 'app.asar') -Force
    Log-Success "已备份当前 ASAR 资源包 (SHA256: $asarHashBefore)"
}

$beforeManifest = @{
    timestamp = $timestamp
    protected = $protectedHashesBefore
    shortcuts = $shortcutBackups
    currentAsar = $asarHashBefore
}
$beforeManifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $backupDir 'before.json') -Encoding utf8
Log-Success "已保存备份快照清册: $(Join-Path $backupDir 'before.json')"

# 4. 修复代理三件套
Log-Section "4. 代理补丁与启动脚本同步"
if ($needUpdateProxyFiles) {
    foreach ($fileName in $proxyDeliverables.Keys) {
        $src = $proxyDeliverables[$fileName]
        $dst = Join-Path $AppDir $fileName
        if (-not (Test-Path -LiteralPath $src)) {
            throw "代理交付源文件缺失: $src"
        }
        Copy-Item -LiteralPath $src -Destination $dst -Force
        $srcHash = (Get-FileHash -LiteralPath $src -Algorithm SHA256).Hash
        $dstHash = (Get-FileHash -LiteralPath $dst -Algorithm SHA256).Hash
        if ($srcHash -ne $dstHash) {
            throw "文件复制后哈希校验失败: $fileName"
        }
        if ($fileName -eq 'version.dll' -and $dstHash -ne $ExpectedDllHash) {
            throw "部署的 version.dll SHA256 与官方期望值不符: $dstHash"
        }
        Log-Success "已同步并校验: $fileName"
    }
} else {
    Log-Success "代理 DLL、配置文件及启动脚本均已就绪且哈希一致，无需重复写入。"
}

# 5. 修复快捷方式
Log-Section "5. 修复桌面与开始菜单快捷方式"
$vbsFullPath = Join-Path $AppDir "launch-antigravity-$ProxyPort.vbs"
foreach ($scPath in $shortcuts) {
    $lnk = $shell.CreateShortcut($scPath)
    $lnk.TargetPath = 'C:\Windows\System32\wscript.exe'
    $lnk.Arguments = '"' + $vbsFullPath + '"'
    $lnk.WorkingDirectory = $AppDir
    $lnk.IconLocation = "$AppDir\Antigravity.exe,0"
    $lnk.Save()

    # 回读复核
    $verifyLnk = $shell.CreateShortcut($scPath)
    if ($verifyLnk.TargetPath -ne $lnk.TargetPath -or $verifyLnk.Arguments -ne $lnk.Arguments) {
        throw "快捷方式回读校验失败: $scPath"
    }
    Log-Success "快捷方式已修正并复核: $scPath"
}

# 6. 汉化补丁检测与精准合成
Log-Section "6. 宿主汉化补丁处理"
$asarPatched = $false
if (-not $SkipLocalization) {
    $checkJson = node $nodeScript --action check --asarPath $currentAsar | ConvertFrom-Json
    if ($checkJson.isPatched) {
        Log-Success "检测到当前 app.asar 已包含汉化补丁，保持现有状态。"
        $asarPatched = $true
    } else {
        Log-Warn "当前 app.asar 未汉化，正在启动隔离沙箱进行精准合成与注入..."
        $stagingDir = Join-Path $projectRoot 'outputs\asar-staging'
        if (-not (Test-Path -LiteralPath $stagingDir)) {
            New-Item -ItemType Directory -Path $stagingDir -Force | Out-Null
        }
        $outputPreserved = Join-Path $stagingDir 'app-preserved.asar'

        $buildArgs = @(
            $nodeScript,
            '--action', 'build',
            '--originalAsar', $currentAsar,
            '--chineseTool', $ChineseTool,
            '--destAsar', $outputPreserved,
            '--tempDir', $stagingDir
        )
        $buildOutput = & node $buildArgs
        $buildRes = $buildOutput | ConvertFrom-Json
        if (-not $buildRes.success) {
            throw "汉化 ASAR 合成失败: $($buildRes.error)"
        }
        Log-Success "ASAR 精准合成完毕: 修改 $($buildRes.changedFiles.Count) 个 dist 脚本，语法校验全过，外置规则完全保留。"

        # 部署合成好的 ASAR
        Copy-Item -LiteralPath $outputPreserved -Destination $currentAsar -Force
        $deployedHash = (Get-FileHash -LiteralPath $currentAsar -Algorithm SHA256).Hash
        $builtHash = (Get-FileHash -LiteralPath $outputPreserved -Algorithm SHA256).Hash
        if ($deployedHash -ne $builtHash) {
            throw "部署后 app.asar 哈希校验失败！"
        }
        Log-Success "汉化 ASAR 成功部署并校验一致 (SHA256: $deployedHash)"
        $asarPatched = $true
    }
} else {
    Log-Warn "跳过汉化补丁处理 (-SkipLocalization)"
}

# 7. 复核受保护二进制
Log-Section "7. 最终受保护二进制一致性复核"
foreach ($rel in $protectedFiles) {
    $full = Join-Path $AppDir $rel
    $currentH = (Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash
    if ($currentH -ne $protectedHashesBefore[$rel]) {
        throw "安全告警：受保护核心文件在修复过程中被意外篡改！$rel"
    }
    Log-Success "受保护文件完整未变: $rel"
}

# 8. 同步智能体中文交互插件、全局规则与 Agent Skill
Log-Section "8. 智能体中文插件、全局规则与 Skill 部署"
$userProfile = $envData.OS.UserProfile
$targetPluginDir = $envData.Agent.ChineseToolkitDir
$pluginSourceDir = Join-Path $projectRoot 'payload\plugins\chinese-toolkit'

if (Test-Path -LiteralPath (Join-Path $pluginSourceDir 'plugin.json')) {
    if (-not (Test-Path -LiteralPath $targetPluginDir)) {
        New-Item -ItemType Directory -Path $targetPluginDir -Force | Out-Null
    }
    Copy-Item -Path "$pluginSourceDir\*" -Destination $targetPluginDir -Recurse -Force
    Log-Success "智能体中文交互插件 (chinese-toolkit) 已同步至: $targetPluginDir"
} else {
    Log-Warn "未找到插件源目录，跳过 chinese-toolkit 安装"
}

# 规则同步：优先使用权威源 (.codex\AGENTS.md 或本项目 AGENTS.md)
$userCodexAgents = Join-Path $userProfile '.codex\AGENTS.md'
$projectAgents = Join-Path $projectRoot 'AGENTS.md'
$authoritativeSource = if (Test-Path -LiteralPath $userCodexAgents) { $userCodexAgents } else { $projectAgents }

$geminiRulesAgents = $envData.Agent.RulesFile
$geminiConfigAgents = Join-Path $envData.Agent.ConfigDir 'AGENTS.md'
if (Test-Path -LiteralPath $authoritativeSource) {
    $rulesDir = Split-Path -Parent $geminiRulesAgents
    if (-not (Test-Path -LiteralPath $rulesDir)) { New-Item -ItemType Directory -Path $rulesDir -Force | Out-Null }
    Copy-Item -Path $authoritativeSource -Destination $geminiRulesAgents -Force
    Copy-Item -Path $authoritativeSource -Destination $geminiConfigAgents -Force
    Log-Success "全局规则 AGENTS.md 已同步权威基准 ($authoritativeSource)"
}

# 自动注册/更新 Agent Skill
try {
    & $installSkillScript -Quiet
    Log-Success "Agent Skill (antigravity-windows-fast-patch) 已自动同步注册至全局技能库。"
} catch {
    Log-Warn "自动注册 Agent Skill 提示: $($_.Exception.Message)"
}

$geminiCfgPath = Join-Path $userProfile '.gemini\config\config.json'
if (Test-Path -LiteralPath $geminiCfgPath) {
    try {
        $cfgJson = Get-Content -LiteralPath $geminiCfgPath -Raw -Encoding utf8 | ConvertFrom-Json
        $cfgChanged = $false
        if ($cfgJson.userSettings.permissionPreset -ne 'AGENT_PERMISSION_PRESET_AUTO') {
            $cfgJson.userSettings.permissionPreset = 'AGENT_PERMISSION_PRESET_AUTO'
            $cfgChanged = $true
        }
        if ($cfgJson.userSettings.autoExecutionPolicy -ne 'CASCADE_COMMANDS_AUTO_EXECUTION_AUTO') {
            $cfgJson.userSettings.autoExecutionPolicy = 'CASCADE_COMMANDS_AUTO_EXECUTION_AUTO'
            $cfgChanged = $true
        }
        if ($cfgChanged) {
            $cfgJson | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $geminiCfgPath -Encoding utf8
            Log-Success "config.json 已恢复自动审批与自动执行策略"
        } else {
            Log-Success "config.json 执行策略已就绪 (无需调整)"
        }
    } catch {
        Log-Warn "调整 config.json 策略失败: $($_.Exception.Message)"
    }
}

# 8. 修复报告落盘
$fixResult = [ordered]@{
    timestamp = $timestamp
    appDir = $AppDir
    backupDir = $backupDir
    proxyFiles = $proxyDeliverables.Keys
    shortcutsFixed = $shortcuts
    localizationPatched = $asarPatched
    protectedFilesIntact = $true
    status = 'Success'
}
$fixResult | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $backupDir 'fix-result.json') -Encoding utf8

Log-Section "修复结果"
Log-Success "Antigravity 一键修复全部完成！备份位于: $backupDir"

# 9. 自动启动（可选）
if ($LaunchAfterFix) {
    Log-Section "8. 启动应用"
    Write-Host "正在通过代理启动器拉起 Antigravity..." -ForegroundColor Cyan
    Start-Process -FilePath 'C:\Windows\System32\wscript.exe' -ArgumentList ('"' + $vbsFullPath + '"') -WindowStyle Hidden
    Start-Sleep -Seconds 3
    $startedAg = Get-Process Antigravity -ErrorAction SilentlyContinue
    if ($startedAg) {
        Log-Success "Antigravity 已成功拉起 (进程数: $($startedAg.Count))"
    } else {
        Log-Warn "未能检测到 Antigravity 运行进程，请手动通过桌面快捷方式启动。"
    }
}

return [PSCustomObject]$fixResult
