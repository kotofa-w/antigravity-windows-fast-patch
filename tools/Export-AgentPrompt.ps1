<#
.SYNOPSIS
    Antigravity Agent 动态任务提示词生成器 (Export-AgentPrompt)
.DESCRIPTION
    读取最近一次健康诊断报告与环境发现数据，自动生成结构化、精确、包含上下文
    的 Agent 接管提示词 (agent-prompt.md)，并支持复制到 Windows 剪贴板。
#>

[CmdletBinding()]
param (
    [string]$RunId = '',
    [string]$ReportJsonPath = '',
    [string]$OutputFile = '',
    [string]$ActionsTaken = '尚未执行修复，由用户或脚本主动请求 Agent 接入协同。',
    [switch]$CopyToClipboard,
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$templateFile = Join-Path $projectRoot 'templates\agent-prompt.md'
$discoveryScript = Join-Path $projectRoot 'tools\EnvironmentDiscovery.ps1'

# 1. 尝试获取最近一次诊断报告
$reportData = $null
if ($ReportJsonPath -and (Test-Path -LiteralPath $ReportJsonPath)) {
    try {
        $reportData = Get-Content -LiteralPath $ReportJsonPath -Raw -Encoding utf8 | ConvertFrom-Json
    } catch {}
}

if (-not $reportData) {
    # 查找 outputs/health-runs 下最新的运行记录
    $runsDir = Join-Path $projectRoot 'outputs\health-runs'
    if (Test-Path -LiteralPath $runsDir) {
        $latestRunDir = Get-ChildItem -Path $runsDir -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($latestRunDir) {
            $sumJson = Join-Path $latestRunDir.FullName 'summary.json'
            if (Test-Path -LiteralPath $sumJson) {
                try {
                    $reportData = Get-Content -LiteralPath $sumJson -Raw -Encoding utf8 | ConvertFrom-Json
                    if (-not $RunId) { $RunId = $latestRunDir.Name }
                    if (-not $ReportJsonPath) { $ReportJsonPath = $sumJson }
                } catch {}
            }
        }
    }
}

# 2. 如果依然没有诊断报告，调用 EnvironmentDiscovery 获取环境事实
$envData = $null
if (Test-Path -LiteralPath $discoveryScript) {
    try {
        $envData = & $discoveryScript
    } catch {}
}

# 3. 提取或初始化变量
if (-not $RunId) {
    $RunId = 'run-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
}

$checkTime = if ($reportData -and $reportData.CheckTime) { $reportData.CheckTime } else { (Get-Date).ToString('yyyy-MM-dd HH:mm:ss') }
$status = if ($reportData -and $reportData.Status) { $reportData.Status } else { 'NeedsInitialAudit' }

$agVersion = if ($reportData -and $reportData.Version -and $reportData.Version -ne 'Unknown') {
    $reportData.Version
} elseif ($envData -and $envData.Antigravity.Version) {
    $envData.Antigravity.Version
} else { 'Unknown' }

$agAppDir = if ($reportData -and $reportData.AppDir) {
    $reportData.AppDir
} elseif ($envData -and $envData.Antigravity.AppDir) {
    $envData.Antigravity.AppDir
} else { 'C:\Users\123\AppData\Local\Programs\antigravity' }

$agCoreStatus = if ($reportData -and $reportData.IsInstalled) {
    "安装目录就绪，核心二进制完整"
} elseif ($envData -and $envData.Antigravity.IsInstalled) {
    "已安装，核心主程序存在"
} else { "未检测到已安装的 Antigravity 客户端" }

$proxyTarget = if ($envData -and $envData.Proxy) {
    "$($envData.Proxy.TargetHost):$($envData.Proxy.TargetPort)"
} else { "127.0.0.1:65532" }

$proxyStatus = if ($reportData -and $reportData.ProxyFiles) {
    $pDll = $reportData.ProxyFiles.'version.dll'.Match
    $pCfg = $reportData.ProxyFiles.'config.json'.Valid
    if ($pDll -and $pCfg) { "正常注入且规则有效" } else { "代理 DLL 或配置文件异常" }
} else { "待体检核验" }

$shortcutStatus = if ($reportData -and $reportData.Shortcuts) {
    $dOk = $reportData.Shortcuts.Desktop.Valid
    $sOk = $reportData.Shortcuts.StartMenu.Valid
    if ($dOk -and $sOk) { "桌面与开始菜单快捷方式均已配置代理启动" } else { "快捷方式未指向代理启动器" }
} else { "待体检核验" }

$locStatus = if ($reportData -and $reportData.Localization) {
    if ($reportData.Localization.IsPatched) { "已注入汉化补丁并保持外置结构" } else { "未注入汉化或已被官方覆盖" }
} else { "待体检核验" }

$runtimeStatus = if ($reportData -and $reportData.Runtime) {
    "Antigravity 进程数: $($reportData.Runtime.AntigravityCount), TCP 连接数: $($reportData.Runtime.ProxyTcpConnections)"
} else { "待检测" }

$agentStatus = if ($reportData -and $reportData.AgentEnvironment) {
    "插件: $($reportData.AgentEnvironment.PluginInstalled), 规则同步: $($reportData.AgentEnvironment.RulesSynced), 自动策略: $($reportData.AgentEnvironment.PolicyAuto)"
} else { "待检测" }

# 组织 Issues 清单
$issuesList = ""
if ($reportData -and $reportData.Issues -and $reportData.Issues.Count -gt 0) {
    $issuesList = ($reportData.Issues | ForEach-Object { "- [ ] **异常**：$_" }) -join "`n"
} else {
    $issuesList = "- [ ] **提示**：未运行诊断或前置体检未发现异常，需 Agent 执行首次完整体检与规则审查。"
}

$summaryMdPath = if ($ReportJsonPath) {
    $ReportJsonPath.Replace('.json', '.md')
} else {
    Join-Path $projectRoot "outputs\health-runs\$RunId\summary.md"
}
$summaryJsonPath = if ($ReportJsonPath) { $ReportJsonPath } else { Join-Path $projectRoot "outputs\health-runs\$RunId\summary.json" }

# 4. 填充模板
if (-not (Test-Path -LiteralPath $templateFile)) {
    throw "未找到提示词模板文件: $templateFile"
}
$templateContent = Get-Content -LiteralPath $templateFile -Raw -Encoding utf8

$promptContent = $templateContent `
    -replace '\{\{PROJECT_ROOT\}\}', $projectRoot `
    -replace '\{\{RUN_ID\}\}', $RunId `
    -replace '\{\{CHECK_TIME\}\}', $checkTime `
    -replace '\{\{STATUS\}\}', $status `
    -replace '\{\{SUMMARY_MD_PATH\}\}', $summaryMdPath `
    -replace '\{\{SUMMARY_JSON_PATH\}\}', $summaryJsonPath `
    -replace '\{\{AG_VERSION\}\}', $agVersion `
    -replace '\{\{AG_APP_DIR\}\}', $agAppDir `
    -replace '\{\{AG_CORE_STATUS\}\}', $agCoreStatus `
    -replace '\{\{PROXY_STATUS\}\}', $proxyStatus `
    -replace '\{\{PROXY_TARGET\}\}', $proxyTarget `
    -replace '\{\{SHORTCUT_STATUS\}\}', $shortcutStatus `
    -replace '\{\{LOCALIZATION_STATUS\}\}', $locStatus `
    -replace '\{\{RUNTIME_STATUS\}\}', $runtimeStatus `
    -replace '\{\{AGENT_STATUS\}\}', $agentStatus `
    -replace '\{\{ISSUES_LIST\}\}', $issuesList `
    -replace '\{\{ACTIONS_TAKEN\}\}', $ActionsTaken

# 5. 保存到目标文件
if (-not $OutputFile) {
    $runDir = Join-Path $projectRoot "outputs\health-runs\$RunId"
    if (-not (Test-Path -LiteralPath $runDir)) {
        New-Item -ItemType Directory -Path $runDir -Force | Out-Null
    }
    $OutputFile = Join-Path $runDir 'agent-prompt.md'
}

$parentDir = Split-Path -Parent $OutputFile
if ($parentDir -and (-not (Test-Path -LiteralPath $parentDir))) {
    New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
}

$promptContent | Set-Content -LiteralPath $OutputFile -Encoding utf8

# 根目录同时也写一份方便用户直接打开
$rootPromptPath = Join-Path $projectRoot 'agent-prompt.md'
$promptContent | Set-Content -LiteralPath $rootPromptPath -Encoding utf8

# 6. 复制到剪贴板支持 (采用纯托管 API，避免 clip.exe 挂起)
$copied = $false
if ($CopyToClipboard) {
    try {
        [System.Windows.Forms.Clipboard]::SetText($promptContent)
        $copied = $true
    } catch {
        try {
            Set-Clipboard -Value $promptContent -ErrorAction Stop
            $copied = $true
        } catch {
            $copied = $false
        }
    }
}

if (-not $Quiet) {
    Write-Host "`n>>> [提示词生成成功]" -ForegroundColor Green
    Write-Host "  运行标识: $RunId" -ForegroundColor Gray
    Write-Host "  产物路径: $OutputFile" -ForegroundColor Cyan
    Write-Host "  便捷路径: $rootPromptPath" -ForegroundColor Cyan
    if ($CopyToClipboard) {
        if ($copied) {
            Write-Host "  [OK] 提示词已成功复制到 Windows 剪贴板！可直接在 AI 聊天窗口粘贴。" -ForegroundColor Green
        } else {
            Write-Host "  [WARN] 未能直接写入剪贴板，请手动打开上述文件复制。" -ForegroundColor Yellow
        }
    }
}

return [PSCustomObject]@{
    RunId = $RunId
    PromptFile = $OutputFile
    CopiedToClipboard = $copied
    ContentLength = $promptContent.Length
}
