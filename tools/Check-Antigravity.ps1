<#
.SYNOPSIS
    Antigravity 全维健康检验与统一诊断脚本 (Check-Antigravity)
.DESCRIPTION
    全面检测 Antigravity 客户端、代理补丁、启动器快捷方式、宿主汉化补丁、
    运行态连接、智能体规则策略以及 Agent Skill 注册状态。
    基于统一协议输出结构化项 (ID, Name, Source, Status, Evidence, RepairStatus)，
    支持生成持久化健康快照 outputs/health-runs/<run-id>/summary.json & summary.md。
#>

[CmdletBinding()]
param (
    [string]$AppDir = '',
    [string]$ExpectedDllHash = '40F037232A180DA8DFF7611021270549FCC4E208580D8BF0F70BC9975F871B5F',
    [string]$ExpectedProxyHost = '127.0.0.1',
    [int]$ExpectedProxyPort = 65532,
    [string]$RunId = '',
    [switch]$Quiet,
    [switch]$ForLaunch
)

$ErrorActionPreference = 'Stop'
$toolsDir = $PSScriptRoot
$projectRoot = Split-Path $toolsDir -Parent
$nodeScript = Join-Path $toolsDir 'patch-asar.cjs'
$discoveryScript = Join-Path $toolsDir 'EnvironmentDiscovery.ps1'

# 1. 动态加载环境探测事实
$envData = & $discoveryScript -AppDir $AppDir -PreferredProxyPort $ExpectedProxyPort -NoCache:$ForLaunch
if (-not $AppDir) {
    $AppDir = $envData.Antigravity.AppDir
}
if (-not $ExpectedProxyPort -and $envData.Proxy.TargetPort) {
    $ExpectedProxyPort = $envData.Proxy.TargetPort
}

if (-not $RunId) {
    $RunId = 'run-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
}
$checkTime = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')

# 统一检查项目清单 (Check Items)
$checkItems = [System.Collections.Generic.List[PSCustomObject]]::new()
$issues = [System.Collections.Generic.List[string]]::new()

function Add-CheckItem {
    param (
        [string]$Id,
        [string]$Name,
        [string]$Source = 'external',
        [string]$Status = 'pass',
        [string]$Evidence = '',
        [string]$Issue = '',
        [string]$RepairStatus = 'not_needed'
    )

    $item = [PSCustomObject]@{
        Id           = $Id
        Name         = $Name
        Source       = $Source
        Status       = $Status
        Evidence     = $Evidence
        Issue        = $Issue
        RepairStatus = $RepairStatus
        CheckTime    = $checkTime
    }
    $checkItems.Add($item)

    if ($Status -eq 'fail' -or $Status -eq 'warning') {
        $desc = if ($Issue) { $Issue } else { "$Name 检验未通过" }
        $issues.Add("[$Id] $desc")
    }

    if (-not $Quiet) {
        $icon = switch ($Status) {
            'pass'    { "  [OK]   " }
            'warning' { "  [WARN] " }
            'fail'    { "  [FAIL] " }
            'skipped' { "  [SKIP] " }
            default   { "  [UNK]  " }
        }
        $color = switch ($Status) {
            'pass'    { "Green" }
            'warning' { "Yellow" }
            'fail'    { "Red" }
            'skipped' { "DarkGray" }
            default   { "Cyan" }
        }
        Write-Host "$icon $Name" -NoNewline -ForegroundColor $color
        if ($Evidence) {
            Write-Host " - $Evidence" -ForegroundColor Gray
        } else {
            Write-Host ""
        }
    }
}

function Log-Section([string]$title) {
    if (-not $Quiet) {
        Write-Host "`n==== $title ====" -ForegroundColor Cyan
    }
}

$report = [ordered]@{
    RunId             = $RunId
    CheckTime         = $checkTime
    AppDir            = $AppDir
    Version           = 'Unknown'
    IsInstalled       = $false
    ProxyFiles        = [ordered]@{}
    Shortcuts         = [ordered]@{}
    Localization      = [ordered]@{}
    Runtime           = [ordered]@{}
    AgentEnvironment  = [ordered]@{}
    Items             = $checkItems
    Issues            = $issues
    Status            = 'Healthy'
}

# 1. 检查客户端基础安装与核心二进制完整性
Log-Section "1. 客户端安装与受保护核心二进制检查"
$appDirExists = Test-Path -LiteralPath $AppDir
if ($appDirExists) {
    $report.IsInstalled = $true
    Add-CheckItem -Id "CORE-BIN-01" -Name "客户端安装目录" -Source "external" -Status "pass" -Evidence "存在: $AppDir"
} else {
    Add-CheckItem -Id "CORE-BIN-01" -Name "客户端安装目录" -Source "external" -Status "fail" -Evidence "缺失: $AppDir" -Issue "客户端安装目录未找到" -RepairStatus "manual_required"
}

$mainExe = Join-Path $AppDir 'Antigravity.exe'
$langExe = Join-Path $AppDir 'resources\bin\language_server.exe'
$mainExeExists = Test-Path -LiteralPath $mainExe
$langExeExists = Test-Path -LiteralPath $langExe

if ($mainExeExists) {
    $mainEvidence = if ($ForLaunch) { "存在: $mainExe" } else {
        $mainHash = (Get-FileHash -LiteralPath $mainExe -Algorithm SHA256).Hash
        "完整且受保护 (SHA256: $mainHash)"
    }
    Add-CheckItem -Id "CORE-BIN-02" -Name "主程序 (Antigravity.exe)" -Source "external" -Status "pass" -Evidence $mainEvidence
} else {
    Add-CheckItem -Id "CORE-BIN-02" -Name "主程序 (Antigravity.exe)" -Source "external" -Status "fail" -Evidence "文件缺失: $mainExe" -Issue "主程序核心二进制缺失" -RepairStatus "manual_required"
}

if ($langExeExists) {
    $langEvidence = if ($ForLaunch) { "存在: $langExe" } else {
        $langHash = (Get-FileHash -LiteralPath $langExe -Algorithm SHA256).Hash
        "存在 (SHA256: $langHash)"
    }
    Add-CheckItem -Id "CORE-BIN-03" -Name "语言服务器 (language_server.exe)" -Source "external" -Status "pass" -Evidence $langEvidence
} else {
    Add-CheckItem -Id "CORE-BIN-03" -Name "语言服务器 (language_server.exe)" -Source "external" -Status "fail" -Evidence "文件缺失: $langExe" -Issue "语言服务器核心程序缺失" -RepairStatus "manual_required"
}

# 2. 检查代理补丁与启动脚本
Log-Section "2. 代理补丁 (v2.4) 与启动脚本检查"
$dllPath = Join-Path $AppDir 'version.dll'
$cfgPath = Join-Path $AppDir 'config.json'
$vbsPath = Join-Path $AppDir "launch-antigravity-$ExpectedProxyPort.vbs"

if (Test-Path -LiteralPath $dllPath) {
    $dllHash = (Get-FileHash -LiteralPath $dllPath -Algorithm SHA256).Hash
    $dllMatch = ($dllHash -eq $ExpectedDllHash)
    $report.ProxyFiles['version.dll'] = @{ Exists = $true; Hash = $dllHash; Match = $dllMatch }
    if ($dllMatch) {
        Add-CheckItem -Id "PROXY-01" -Name "代理注入 DLL (version.dll)" -Source "external" -Status "pass" -Evidence "SHA256 匹配受控基线 ($dllHash)"
    } else {
        Add-CheckItem -Id "PROXY-01" -Name "代理注入 DLL (version.dll)" -Source "external" -Status "warning" -Evidence "当前哈希: $dllHash (非默认基线 $ExpectedDllHash)" -Issue "version.dll 哈希与基线不一致" -RepairStatus "fixed"
    }
} else {
    $report.ProxyFiles['version.dll'] = @{ Exists = $false; Match = $false }
    Add-CheckItem -Id "PROXY-01" -Name "代理注入 DLL (version.dll)" -Source "external" -Status "fail" -Evidence "文件缺失: $dllPath" -Issue "缺少代理注入 DLL" -RepairStatus "fixed"
}

if (Test-Path -LiteralPath $cfgPath) {
    $cfgValid = $false
    $targetDesc = ''
    try {
        $cfgJson = Get-Content -LiteralPath $cfgPath -Raw -Encoding utf8 | ConvertFrom-Json
        $pHost = $cfgJson.proxy.host
        $pPort = $cfgJson.proxy.port
        $pType = $cfgJson.proxy.type
        $targetDesc = "${pHost}:${pPort} (${pType})"
        if ($pHost -eq $ExpectedProxyHost -and [int]$pPort -eq $ExpectedProxyPort) {
            $cfgValid = $true
        }
    } catch {
        $targetDesc = "解析错误: $($_.Exception.Message)"
    }
    $report.ProxyFiles['config.json'] = @{ Exists = $true; Valid = $cfgValid; Target = $targetDesc }
    if ($cfgValid) {
        Add-CheckItem -Id "PROXY-02" -Name "代理配置 (config.json)" -Source "external" -Status "pass" -Evidence "目标有效: $targetDesc"
    } else {
        Add-CheckItem -Id "PROXY-02" -Name "代理配置 (config.json)" -Source "external" -Status "fail" -Evidence "当前配置: $targetDesc (期望: ${ExpectedProxyHost}:${ExpectedProxyPort})" -Issue "config.json 未正确指向目标代理端口" -RepairStatus "fixed"
    }
} else {
    $report.ProxyFiles['config.json'] = @{ Exists = $false; Valid = $false }
    Add-CheckItem -Id "PROXY-02" -Name "代理配置 (config.json)" -Source "external" -Status "fail" -Evidence "文件缺失: $cfgPath" -Issue "缺少代理配置文件" -RepairStatus "fixed"
}

if (Test-Path -LiteralPath $vbsPath) {
    $vbsContent = Get-Content -LiteralPath $vbsPath -Raw
    $vbsValid = ($vbsContent -match "${ExpectedProxyHost}:${ExpectedProxyPort}")
    $report.ProxyFiles['vbs'] = @{ Exists = $true; Valid = $vbsValid }
    if ($vbsValid) {
        Add-CheckItem -Id "PROXY-03" -Name "VBS 启动脚本" -Source "external" -Status "pass" -Evidence "端口就绪: $vbsPath"
    } else {
        Add-CheckItem -Id "PROXY-03" -Name "VBS 启动脚本" -Source "external" -Status "fail" -Evidence "未匹配目标端口: $ExpectedProxyPort" -Issue "VBS 启动脚本未指向正确端口" -RepairStatus "fixed"
    }
} else {
    $report.ProxyFiles['vbs'] = @{ Exists = $false; Valid = $false }
    Add-CheckItem -Id "PROXY-03" -Name "VBS 启动脚本" -Source "external" -Status "fail" -Evidence "文件缺失: $vbsPath" -Issue "缺少代理启动脚本" -RepairStatus "fixed"
}

# 3. 检查快捷方式
if (-not $ForLaunch) {
    Log-Section "3. 桌面与开始菜单快捷方式检查"
    $desktopLnk = $envData.Shortcuts.Desktop
    $startMenuLnk = $envData.Shortcuts.StartMenu
    $shortcuts = @(
        @{ Id = 'SHORTCUT-01'; Name = '桌面快捷方式'; Path = $desktopLnk },
        @{ Id = 'SHORTCUT-02'; Name = '开始菜单快捷方式'; Path = $startMenuLnk }
    )
    $wsh = New-Object -ComObject WScript.Shell
    foreach ($s in $shortcuts) {
        $sId = $s.Id
        $sName = $s.Name
        $sPath = $s.Path
        if (Test-Path -LiteralPath $sPath) {
            $lnk = $wsh.CreateShortcut($sPath)
            $targetOk = ($lnk.TargetPath -like '*\wscript.exe')
            $argsOk = ($lnk.Arguments -like "*launch-antigravity-$ExpectedProxyPort.vbs*")
            $shortcutOk = ($targetOk -and $argsOk)
            $report.Shortcuts[$sId] = @{
                Exists = $true
                TargetPath = $lnk.TargetPath
                Arguments = $lnk.Arguments
                Valid = $shortcutOk
            }
            if ($shortcutOk) {
                Add-CheckItem -Id $sId -Name $sName -Source "external" -Status "pass" -Evidence "指向 VBS 启动器 (Target: $($lnk.TargetPath))"
            } else {
                Add-CheckItem -Id $sId -Name $sName -Source "external" -Status "fail" -Evidence "Target: $($lnk.TargetPath) | Args: $($lnk.Arguments)" -Issue "快捷方式未指向代理启动器脚本" -RepairStatus "fixed"
            }
        } else {
            $report.Shortcuts[$sId] = @{ Exists = $false; Valid = $false }
            Add-CheckItem -Id $sId -Name $sName -Source "external" -Status "warning" -Evidence "快捷方式未找到: $sPath" -Issue "快捷方式文件不存在" -RepairStatus "fixed"
        }
    }
}

# 4. 检查汉化补丁与 ASAR 结构
Log-Section "4. 宿主汉化补丁与 ASAR 资源检查"
$asarPath = Join-Path $AppDir 'resources\app.asar'
$unpackedDir = Join-Path $AppDir 'resources\app.asar.unpacked\node_modules\chrome-devtools-mcp'
$asarCheck = $null

if (Test-Path -LiteralPath $asarPath) {
    try {
        $asarJson = node $nodeScript --action check --asarPath $asarPath
        $asarCheck = $asarJson | ConvertFrom-Json
        $report.Version = $asarCheck.version
        Add-CheckItem -Id "ASAR-01" -Name "ASAR 资源包存在" -Source "external" -Status "pass" -Evidence "版本: $($asarCheck.version), 条目数: $($asarCheck.totalEntries)"

        if ($asarCheck.isPatched) {
            Add-CheckItem -Id "ASAR-02" -Name "汉化补丁注入状态" -Source "external" -Status "pass" -Evidence "已注入汉化补丁 (UI 脚本已替换)"
        } else {
            Add-CheckItem -Id "ASAR-02" -Name "汉化补丁注入状态" -Source "external" -Status "fail" -Evidence "当前为官方原版或已被更新覆盖" -Issue "app.asar 未注入汉化补丁" -RepairStatus "fixed"
        }
    } catch {
        Add-CheckItem -Id "ASAR-01" -Name "ASAR 资源包解析" -Source "external" -Status "fail" -Evidence $_.Exception.Message -Issue "app.asar 解析失败" -RepairStatus "manual_required"
        Add-CheckItem -Id "ASAR-02" -Name "汉化补丁注入状态" -Source "external" -Status "unknown" -Evidence "无法解析 ASAR" -Issue "ASAR 状态未知" -RepairStatus "manual_required"
    }
} else {
    Add-CheckItem -Id "ASAR-01" -Name "ASAR 资源包存在" -Source "external" -Status "fail" -Evidence "缺失: $asarPath" -Issue "缺少关键资源 app.asar" -RepairStatus "manual_required"
    Add-CheckItem -Id "ASAR-02" -Name "汉化补丁注入状态" -Source "external" -Status "skipped" -Evidence "ASAR 不存在"
}

$unpackedExists = Test-Path -LiteralPath $unpackedDir
if ($unpackedExists) {
    Add-CheckItem -Id "ASAR-03" -Name "外置扩展保护 (chrome-devtools-mcp)" -Source "external" -Status "pass" -Evidence "目录完整: $unpackedDir"
} else {
    Add-CheckItem -Id "ASAR-03" -Name "外置扩展保护 (chrome-devtools-mcp)" -Source "external" -Status "fail" -Evidence "未找到外置解包目录: $unpackedDir" -Issue "缺少 chrome-devtools-mcp 外置解包目录" -RepairStatus "fixed"
}

$report.Localization = @{
    AsarExists = (Test-Path -LiteralPath $asarPath)
    Version = $report.Version
    IsPatched = [bool]($asarCheck -and $asarCheck.isPatched)
    UnpackedExists = $unpackedExists
}

if ($ForLaunch) {
    return [PSCustomObject]@{
        Ready = @($checkItems | Where-Object Status -NE 'pass').Count -eq 0
        AppDir = $AppDir
        Launcher = $vbsPath
        Items = $checkItems.ToArray()
    }
}

# 5. 检查运行态与 TCP 连接
Log-Section "5. 运行状态与代理连接快照"
$procAg = Get-Process Antigravity -ErrorAction SilentlyContinue
$procLs = Get-Process language_server -ErrorAction SilentlyContinue
$isRunning = [bool]($procAg)
$agDesc = if ($isRunning) { "共 $($procAg.Count) 个进程" } else { "未运行" }
$lsRunning = [bool]($procLs)
$lsDesc = if ($lsRunning) { "共 $($procLs.Count) 个进程" } else { "未运行" }

Add-CheckItem -Id "RUNTIME-01" -Name "Antigravity 运行状态" -Source "external" -Status "pass" -Evidence "客户端: $agDesc | 语言服务器: $lsDesc"

$tcpConns = @()
try {
    $tcpConns = Get-NetTCPConnection -RemotePort $ExpectedProxyPort -ErrorAction SilentlyContinue
} catch {}
$tcpCount = if ($tcpConns) { $tcpConns.Count } else { 0 }
$report.Runtime = @{
    IsRunning = $isRunning
    AntigravityCount = if ($procAg) { $procAg.Count } else { 0 }
    LanguageServerCount = if ($procLs) { $procLs.Count } else { 0 }
    ProxyTcpConnections = $tcpCount
}

if ($tcpCount -gt 0) {
    Add-CheckItem -Id "RUNTIME-02" -Name "TCP 代理连接 (Port $ExpectedProxyPort)" -Source "external" -Status "pass" -Evidence "活跃连接数: $tcpCount"
} else {
    $rStatus = if ($isRunning) { "warning" } else { "pass" }
    $rEvidence = if ($isRunning) { "客户端运行中但当前无活跃代理连接" } else { "客户端未运行，无活跃连接属于正常态" }
    Add-CheckItem -Id "RUNTIME-02" -Name "TCP 代理连接 (Port $ExpectedProxyPort)" -Source "external" -Status $rStatus -Evidence $rEvidence
}

# 6. 检查智能体中文插件与全局规则配置
Log-Section "6. 智能体中文插件、规则与 Skill 检查"
$pluginDir = $envData.Agent.ChineseToolkitDir
$pluginManifest = Join-Path $pluginDir 'plugin.json'
$pluginRules = Join-Path $pluginDir 'rules\chinese-interaction-rules.md'
$pluginOk = (Test-Path -LiteralPath $pluginManifest) -and (Test-Path -LiteralPath $pluginRules)
if ($pluginOk) {
    Add-CheckItem -Id "AGENT-01" -Name "智能体中文交互插件 (chinese-toolkit)" -Source "internal" -Status "pass" -Evidence "已就绪: $pluginDir"
} else {
    Add-CheckItem -Id "AGENT-01" -Name "智能体中文交互插件 (chinese-toolkit)" -Source "internal" -Status "warning" -Evidence "未找到或不完整: $pluginDir" -Issue "智能体中文插件缺失，可能影响中文回复规范" -RepairStatus "fixed"
}

# 权威规则对齐检查：优先比对本项目 AGENTS.md 与全局 AGENTS.md
$projectAgents = Join-Path $projectRoot 'AGENTS.md'
$geminiRulesAgents = $envData.Agent.RulesFile
$geminiConfigAgents = Join-Path $envData.Agent.ConfigDir 'AGENTS.md'
$userCodexAgents = Join-Path $envData.OS.UserProfile '.codex\AGENTS.md'

$authoritativeSource = if (Test-Path -LiteralPath $userCodexAgents) { $userCodexAgents } else { $projectAgents }
$rulesSyncOk = $true
if (Test-Path -LiteralPath $authoritativeSource) {
    $authHash = (Get-FileHash -LiteralPath $authoritativeSource -Algorithm SHA256).Hash
    $rHash = if (Test-Path -LiteralPath $geminiRulesAgents) { (Get-FileHash -LiteralPath $geminiRulesAgents -Algorithm SHA256).Hash } else { '' }
    $cHash = if (Test-Path -LiteralPath $geminiConfigAgents) { (Get-FileHash -LiteralPath $geminiConfigAgents -Algorithm SHA256).Hash } else { '' }
    $rulesSyncOk = ($authHash -eq $rHash -and $authHash -eq $cHash)
    if ($rulesSyncOk) {
        Add-CheckItem -Id "AGENT-02" -Name "全局规则一致性 (AGENTS.md)" -Source "internal" -Status "pass" -Evidence "与权威源 ($authoritativeSource) 对齐"
    } else {
        Add-CheckItem -Id "AGENT-02" -Name "全局规则一致性 (AGENTS.md)" -Source "internal" -Status "warning" -Evidence "哈希未对齐权威真源" -Issue "全局规则 AGENTS.md 版本落后或内容未同步" -RepairStatus "fixed"
    }
} else {
    Add-CheckItem -Id "AGENT-02" -Name "全局规则一致性 (AGENTS.md)" -Source "internal" -Status "warning" -Evidence "未找到权威规则源" -Issue "缺少规则基准文件" -RepairStatus "fixed"
}

# 策略检查
$geminiCfgPath = $envData.Agent.ConfigFile
$policyOk = $false
if (Test-Path -LiteralPath $geminiCfgPath) {
    try {
        $gCfg = Get-Content -LiteralPath $geminiCfgPath -Raw -Encoding utf8 | ConvertFrom-Json
        $preset = $gCfg.userSettings.permissionPreset
        $autoPolicy = $gCfg.userSettings.autoExecutionPolicy
        $policyOk = ($preset -eq 'AGENT_PERMISSION_PRESET_AUTO')
        if ($policyOk) {
            Add-CheckItem -Id "AGENT-03" -Name "执行审批策略 (config.json)" -Source "internal" -Status "pass" -Evidence "Preset: $preset | AutoPolicy: $autoPolicy"
        } else {
            Add-CheckItem -Id "AGENT-03" -Name "执行审批策略 (config.json)" -Source "internal" -Status "warning" -Evidence "Preset: $preset" -Issue "智能体执行策略未处于自动模式" -RepairStatus "fixed"
        }
    } catch {
        Add-CheckItem -Id "AGENT-03" -Name "执行审批策略 (config.json)" -Source "internal" -Status "warning" -Evidence "解析异常: $($_.Exception.Message)" -Issue "config.json 格式异常" -RepairStatus "fixed"
    }
} else {
    Add-CheckItem -Id "AGENT-03" -Name "执行审批策略 (config.json)" -Source "internal" -Status "warning" -Evidence "未找到: $geminiCfgPath" -Issue "缺少智能体全局配置文件" -RepairStatus "fixed"
}

# 检查 Agent Skill 是否已注册就绪
$installedSkillLink = Join-Path $envData.Agent.SkillsDir 'antigravity-windows-fast-patch'
$skillRegistered = (Test-Path -LiteralPath (Join-Path $installedSkillLink 'SKILL.md'))
if ($skillRegistered) {
    Add-CheckItem -Id "SKILL-01" -Name "维护 Agent Skill 注册状态" -Source "internal" -Status "pass" -Evidence "已注册就绪: $installedSkillLink"
} else {
    Add-CheckItem -Id "SKILL-01" -Name "维护 Agent Skill 注册状态" -Source "internal" -Status "warning" -Evidence "未注册到全局技能目录: $installedSkillLink" -Issue "Agent Skill 尚未安装到 Antigravity 全局目录" -RepairStatus "fixed"
}

$report.AgentEnvironment = @{
    PluginInstalled = $pluginOk
    RulesSynced = $rulesSyncOk
    PolicyAuto = $policyOk
    SkillRegistered = $skillRegistered
}

# 7. 汇总并生成持久化报告
$hasFail = [bool]($checkItems | Where-Object { $_.Status -eq 'fail' })
$hasWarn = [bool]($checkItems | Where-Object { $_.Status -eq 'warning' })

if ($hasFail) {
    $report.Status = 'NeedsAttention'
} elseif ($hasWarn) {
    $report.Status = 'Warning'
} else {
    $report.Status = 'Healthy'
}

# 落盘到 outputs/health-runs/<run-id>/
$runDir = Join-Path $projectRoot "outputs\health-runs\$RunId"
if (-not (Test-Path -LiteralPath $runDir)) {
    New-Item -ItemType Directory -Path $runDir -Force | Out-Null
}

$summaryJsonPath = Join-Path $runDir 'summary.json'
$report | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $summaryJsonPath -Encoding utf8

# 建立 outputs/latest-run.json
$latestJsonPath = Join-Path $projectRoot 'outputs\latest-run.json'
$report | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $latestJsonPath -Encoding utf8

# 生成 Markdown 摘要报告
$mdContent = @"
# Antigravity 环境健康诊断报告 (Health Check Summary)

- **运行 ID (RunId)**：`$($report.RunId)`
- **检查时间**：`$($report.CheckTime)`
- **客户端版本**：`$($report.Version)`
- **安装路径**：`$($report.AppDir)`
- **健康状态**：`$($report.Status)`

---

## 统一检查项清册 (Check Protocol Items)

| ID | 检查项 | 来源 | 状态 | 证据 / 详情 | 待修复项 |
| --- | --- | --- | --- | --- | --- |
"@

foreach ($item in $checkItems) {
    $sBadge = switch ($item.Status) {
        'pass'    { '✅ PASS' }
        'warning' { '⚠️ WARN' }
        'fail'    { '❌ FAIL' }
        'skipped' { '⏭️ SKIP' }
        default   { '❓ UNK' }
    }
    $ev = $item.Evidence -replace '\|', '\|'
    $iss = if ($item.Issue) { $item.Issue -replace '\|', '\|' } else { '-' }
    $itemId = $item.Id
    $itemName = $item.Name
    $itemSource = $item.Source
    $mdContent += "`n| `$itemId` | $itemName | $itemSource | $sBadge | $ev | $iss |"
}

$mdContent += @"


---

## 异常清单与处理建议

"@

if ($issues.Count -eq 0) {
    $mdContent += "所有检查项均处于正常健康状态，无需任何额外修复。`n"
} else {
    for ($i = 0; $i -lt $issues.Count; $i++) {
        $mdContent += "$($i + 1). $($issues[$i])`n"
    }
}

$summaryMdPath = Join-Path $runDir 'summary.md'
$mdContent | Set-Content -LiteralPath $summaryMdPath -Encoding utf8

# 打印控制台总结
Log-Section "检验结果总结"
if ($report.Status -eq 'Healthy') {
    if (-not $Quiet) {
        Write-Host "`n>>> [状态：全维健康] 所有代理配置、快捷方式、汉化补丁及智能体环境均处于正常就绪状态！" -ForegroundColor Green
    }
} else {
    if (-not $Quiet) {
        Write-Host "`n>>> [状态：$($report.Status)，共 $($issues.Count) 项待处理] 详情如下：" -ForegroundColor Yellow
        for ($i = 0; $i -lt $issues.Count; $i++) {
            Write-Host "   $($i + 1). $($issues[$i])" -ForegroundColor Yellow
        }
        Write-Host "`n  报告已生成: $summaryMdPath" -ForegroundColor Gray
    }
}

return [PSCustomObject]$report
