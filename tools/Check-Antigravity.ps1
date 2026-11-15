<#
.SYNOPSIS
    Antigravity 全维健康检验脚本
.DESCRIPTION
    全面检测 Antigravity 客户端、代理补丁、启动器快捷方式、宿主汉化补丁以及运行态连接。
#>

[CmdletBinding()]
param (
    [string]$AppDir = 'C:\Users\123\AppData\Local\Programs\antigravity',
    [string]$ExpectedDllHash = '40F037232A180DA8DFF7611021270549FCC4E208580D8BF0F70BC9975F871B5F',
    [string]$ExpectedProxyHost = '127.0.0.1',
    [int]$ExpectedProxyPort = 65532,
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
$toolsDir = $PSScriptRoot
$nodeScript = Join-Path $toolsDir 'patch-asar.cjs'

$issues = [System.Collections.Generic.List[string]]::new()
$report = [ordered]@{
    CheckTime = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    AppDir = $AppDir
    Version = 'Unknown'
    IsInstalled = $false
    ProxyFiles = [ordered]@{}
    Shortcuts = [ordered]@{}
    Localization = [ordered]@{}
    Runtime = [ordered]@{}
    Issues = $issues
    Status = 'Healthy'
}

function Log-Section([string]$title) {
    if (-not $Quiet) {
        Write-Host "`n==== $title ====" -ForegroundColor Cyan
    }
}

function Log-Item([string]$name, [bool]$pass, [string]$detail) {
    if (-not $Quiet) {
        $icon = if ($pass) { "  [OK]  " } else { "  [FAIL]" }
        $color = if ($pass) { "Green" } else { "Red" }
        Write-Host "$icon $name" -NoNewline -ForegroundColor $color
        if ($detail) {
            Write-Host " - $detail" -ForegroundColor Gray
        } else {
            Write-Host ""
        }
    }
}

# 1. 检查客户端基础安装
Log-Section "1. 客户端安装与受保护二进制检查"
if (Test-Path -LiteralPath $AppDir) {
    $report.IsInstalled = $true
    Log-Item "安装目录存在" $true $AppDir
} else {
    Log-Item "安装目录存在" $false "未找到目录: $AppDir"
    $issues.Add("客户端安装目录不存在: $AppDir")
}

$mainExe = Join-Path $AppDir 'Antigravity.exe'
$langExe = Join-Path $AppDir 'resources\bin\language_server.exe'
$mainExeExists = Test-Path -LiteralPath $mainExe
$langExeExists = Test-Path -LiteralPath $langExe
Log-Item "主程序 (Antigravity.exe)" $mainExeExists $mainExe
Log-Item "语言服务器 (language_server.exe)" $langExeExists $langExe
if (-not $mainExeExists) { $issues.Add("缺少核心二进制: Antigravity.exe") }
if (-not $langExeExists) { $issues.Add("缺少语言服务器二进制: resources\bin\language_server.exe") }

# 2. 检查代理补丁与启动器
Log-Section "2. 代理补丁 (v2.4) 与启动脚本检查"
$dllPath = Join-Path $AppDir 'version.dll'
$cfgPath = Join-Path $AppDir 'config.json'
$vbsPath = Join-Path $AppDir "launch-antigravity-$ExpectedProxyPort.vbs"

if (Test-Path -LiteralPath $dllPath) {
    $dllHash = (Get-FileHash -LiteralPath $dllPath -Algorithm SHA256).Hash
    $dllMatch = ($dllHash -eq $ExpectedDllHash)
    Log-Item "代理 DLL (version.dll)" $dllMatch "SHA256: $dllHash"
    if (-not $dllMatch) { $issues.Add("version.dll 哈希不匹配 (期望: $ExpectedDllHash)") }
    $report.ProxyFiles['version.dll'] = @{ Exists = $true; Hash = $dllHash; Match = $dllMatch }
} else {
    Log-Item "代理 DLL (version.dll)" $false "文件缺失"
    $issues.Add("缺少代理 DLL: version.dll")
    $report.ProxyFiles['version.dll'] = @{ Exists = $false; Match = $false }
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
    Log-Item "代理配置 (config.json)" $cfgValid "目标: $targetDesc"
    if (-not $cfgValid) { $issues.Add("config.json 未正确指向 ${ExpectedProxyHost}:${ExpectedProxyPort}") }
    $report.ProxyFiles['config.json'] = @{ Exists = $true; Valid = $cfgValid; Target = $targetDesc }
} else {
    Log-Item "代理配置 (config.json)" $false "文件缺失"
    $issues.Add("缺少代理配置文件: config.json")
    $report.ProxyFiles['config.json'] = @{ Exists = $false; Valid = $false }
}

if (Test-Path -LiteralPath $vbsPath) {
    $vbsContent = Get-Content -LiteralPath $vbsPath -Raw
    $vbsValid = ($vbsContent -match "${ExpectedProxyHost}:${ExpectedProxyPort}")
    Log-Item "VBS 启动脚本" $vbsValid $vbsPath
    if (-not $vbsValid) { $issues.Add("启动脚本 $vbsPath 未包含目标代理端口 $ExpectedProxyPort") }
    $report.ProxyFiles['vbs'] = @{ Exists = $true; Valid = $vbsValid }
} else {
    Log-Item "VBS 启动脚本" $false "文件缺失: $vbsPath"
    $issues.Add("缺少启动脚本: $vbsPath")
    $report.ProxyFiles['vbs'] = @{ Exists = $false; Valid = $false }
}

# 3. 检查快捷方式
Log-Section "3. 桌面与开始菜单快捷方式检查"
$shortcuts = @(
    @{ Name = 'Desktop'; Path = 'C:\Users\123\Desktop\Antigravity.lnk' },
    @{ Name = 'StartMenu'; Path = 'C:\Users\123\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Antigravity.lnk' }
)
$wsh = New-Object -ComObject WScript.Shell
foreach ($s in $shortcuts) {
    $sName = $s.Name
    $sPath = $s.Path
    if (Test-Path -LiteralPath $sPath) {
        $lnk = $wsh.CreateShortcut($sPath)
        $targetOk = ($lnk.TargetPath -like '*\wscript.exe')
        $argsOk = ($lnk.Arguments -like "*launch-antigravity-$ExpectedProxyPort.vbs*")
        $shortcutOk = ($targetOk -and $argsOk)
        Log-Item "快捷方式 [$sName]" $shortcutOk "Target: $($lnk.TargetPath) | Args: $($lnk.Arguments)"
        if (-not $shortcutOk) {
            $issues.Add("快捷方式 [$sName] 未配置为通过 VBS 脚本启动代理模式")
        }
        $report.Shortcuts[$sName] = @{
            Exists = $true
            TargetPath = $lnk.TargetPath
            Arguments = $lnk.Arguments
            Valid = $shortcutOk
        }
    } else {
        Log-Item "快捷方式 [$sName]" $false "快捷方式不存在: $sPath"
        $issues.Add("快捷方式不存在: $sPath")
        $report.Shortcuts[$sName] = @{ Exists = $false; Valid = $false }
    }
}

# 4. 检查汉化补丁与资源结构
Log-Section "4. 宿主汉化补丁与 ASAR 资源检查"
$asarPath = Join-Path $AppDir 'resources\app.asar'
$unpackedDir = Join-Path $AppDir 'resources\app.asar.unpacked\node_modules\chrome-devtools-mcp'
$asarCheck = $null
if (Test-Path -LiteralPath $asarPath) {
    try {
        $asarJson = node $nodeScript --action check --asarPath $asarPath
        $asarCheck = $asarJson | ConvertFrom-Json
        $report.Version = $asarCheck.version
        $patchStatusText = if ($asarCheck.isPatched) { "已注入汉化补丁" } else { "未检测到汉化补丁 (官方英文版)" }
        Log-Item "ASAR 资源包存在" $true "版本: $($asarCheck.version), 条目数: $($asarCheck.totalEntries)"
        Log-Item "汉化补丁注入状态" $asarCheck.isPatched $patchStatusText
        if (-not $asarCheck.isPatched) {
            $issues.Add("app.asar 未注入汉化补丁 (当前为官方原版或已被更新覆盖)")
        }
    } catch {
        Log-Item "ASAR 解析" $false $_.Exception.Message
        $issues.Add("app.asar 解析失败: $($_.Exception.Message)")
    }
} else {
    Log-Item "ASAR 资源包存在" $false "未找到: $asarPath"
    $issues.Add("缺少关键资源: $asarPath")
}

$unpackedExists = Test-Path -LiteralPath $unpackedDir
Log-Item "外置扩展 (chrome-devtools-mcp)" $unpackedExists $unpackedDir
if (-not $unpackedExists) {
    $issues.Add("缺少外置 unpacked 资源目录: $unpackedDir")
}
$report.Localization = @{
    AsarExists = (Test-Path -LiteralPath $asarPath)
    Version = $report.Version
    IsPatched = [bool]($asarCheck -and $asarCheck.isPatched)
    UnpackedExists = $unpackedExists
}

# 5. 检查运行态与 TCP 连接
Log-Section "5. 运行状态与代理连接快照"
$procAg = Get-Process Antigravity -ErrorAction SilentlyContinue
$procLs = Get-Process language_server -ErrorAction SilentlyContinue
$isRunning = [bool]($procAg)
$agDesc = if ($isRunning) { "共 $($procAg.Count) 个进程" } else { "未运行" }
Log-Item "Antigravity 运行中" $isRunning $agDesc
$lsRunning = [bool]($procLs)
$lsDesc = if ($lsRunning) { "共 $($procLs.Count) 个进程" } else { "未运行" }
Log-Item "language_server 运行中" $lsRunning $lsDesc

$tcpConns = @()
try {
    $tcpConns = Get-NetTCPConnection -RemotePort $ExpectedProxyPort -ErrorAction SilentlyContinue
} catch {}
$tcpCount = if ($tcpConns) { $tcpConns.Count } else { 0 }
Log-Item "TCP 代理连接 (Port $ExpectedProxyPort)" ($tcpCount -gt 0) "当前活跃连接数: $tcpCount"
$report.Runtime = @{
    IsRunning = $isRunning
    AntigravityCount = if ($procAg) { $procAg.Count } else { 0 }
    LanguageServerCount = if ($procLs) { $procLs.Count } else { 0 }
    ProxyTcpConnections = $tcpCount
}

# 6. 检查智能体中文插件与全局规则配置
Log-Section "6. 智能体中文插件与全局规则策略检查"
$userProfile = [System.Environment]::GetFolderPath('UserProfile')
$pluginDir = Join-Path $userProfile '.gemini\config\plugins\chinese-toolkit'
$pluginManifest = Join-Path $pluginDir 'plugin.json'
$pluginRules = Join-Path $pluginDir 'rules\chinese-interaction-rules.md'
$pluginOk = (Test-Path -LiteralPath $pluginManifest) -and (Test-Path -LiteralPath $pluginRules)
Log-Item "智能体中文交互插件 (chinese-toolkit)" $pluginOk $pluginDir
if (-not $pluginOk) {
    $issues.Add("缺少智能体中文交互插件: $pluginDir (可能导致智能体中文回复规范与提示丢失)")
}

$codexAgents = Join-Path $userProfile '.codex\AGENTS.md'
$geminiRulesAgents = Join-Path $userProfile '.gemini\config\rules\AGENTS.md'
$geminiConfigAgents = Join-Path $userProfile '.gemini\config\AGENTS.md'

$rulesSyncOk = $true
if (Test-Path -LiteralPath $codexAgents) {
    $codexHash = (Get-FileHash -LiteralPath $codexAgents -Algorithm SHA256).Hash
    $rHash = if (Test-Path -LiteralPath $geminiRulesAgents) { (Get-FileHash -LiteralPath $geminiRulesAgents -Algorithm SHA256).Hash } else { '' }
    $cHash = if (Test-Path -LiteralPath $geminiConfigAgents) { (Get-FileHash -LiteralPath $geminiConfigAgents -Algorithm SHA256).Hash } else { '' }
    $rulesSyncOk = ($codexHash -eq $rHash -and $codexHash -eq $cHash)
    Log-Item "全局规则同步 (AGENTS.md)" $rulesSyncOk "与权威源 ($codexAgents) 对齐"
    if (-not $rulesSyncOk) {
        $issues.Add("全局规则 AGENTS.md 未与权威真源对齐 (版本或内容可能落后)")
    }
} else {
    Log-Item "全局规则权威源 (.codex\AGENTS.md)" $false "未找到文件"
}

$geminiCfgPath = Join-Path $userProfile '.gemini\config\config.json'
$policyOk = $false
if (Test-Path -LiteralPath $geminiCfgPath) {
    try {
        $gCfg = Get-Content -LiteralPath $geminiCfgPath -Raw -Encoding utf8 | ConvertFrom-Json
        $preset = $gCfg.userSettings.permissionPreset
        $autoPolicy = $gCfg.userSettings.autoExecutionPolicy
        $policyOk = ($preset -eq 'AGENT_PERMISSION_PRESET_AUTO')
        Log-Item "执行策略 (config.json)" $policyOk "Preset: $preset | AutoPolicy: $autoPolicy"
        if (-not $policyOk) {
            $issues.Add("配置执行策略未处于自动审批模式 (当前: $preset)")
        }
    } catch {
        Log-Item "配置策略解析" $false $_.Exception.Message
        $issues.Add("config.json 解析异常")
    }
} else {
    Log-Item "全局配置文件 (config.json)" $false "未找到: $geminiCfgPath"
    $issues.Add("缺少配置文件: $geminiCfgPath")
}

$report.AgentEnvironment = @{
    PluginInstalled = $pluginOk
    RulesSynced = $rulesSyncOk
    PolicyAuto = $policyOk
}

# 总结
Log-Section "检验结果总结"
if ($issues.Count -eq 0) {
    $report.Status = 'Healthy'
    if (-not $Quiet) {
        Write-Host "`n>>> [状态：全维健康] 所有代理配置、快捷方式及汉化补丁均处于正常就绪状态！" -ForegroundColor Green
    }
} else {
    $report.Status = 'NeedsAttention'
    if (-not $Quiet) {
        Write-Host "`n>>> [状态：发现 $($issues.Count) 处待处理项] 详情如下：" -ForegroundColor Yellow
        for ($i = 0; $i -lt $issues.Count; $i++) {
            Write-Host "   $($i + 1). $($issues[$i])" -ForegroundColor Yellow
        }
    }
}

return [PSCustomObject]$report
