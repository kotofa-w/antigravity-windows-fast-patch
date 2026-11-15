<#
.SYNOPSIS
    Antigravity 环境自动发现与通用配置模块 (EnvironmentDiscovery)
.DESCRIPTION
    动态识别 Windows 平台环境、当前用户目录、Antigravity 安装位置、
    版本信息、运行进程、代理设置、运行时依赖及智能体配置与 Skill 目录。
    消除所有开发者机器硬编码，支持开源分发与全新用户环境零配置初始化。
#>

[CmdletBinding()]
param (
    [string]$AppDir = '',
    [int]$PreferredProxyPort = 65532,
    [switch]$NoCache
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$outputDir = Join-Path $projectRoot 'outputs'

function Get-AntigravityEnvironment {
    [CmdletBinding()]
    param (
        [string]$CustomAppDir = '',
        [int]$ProxyPort = 65532
    )

    $userProfile = [System.Environment]::GetFolderPath('UserProfile')
    $localAppData = [System.Environment]::GetFolderPath('LocalApplicationData')
    $appData = [System.Environment]::GetFolderPath('ApplicationData')
    $desktopDir = [System.Environment]::GetFolderPath('Desktop')
    $programsDir = [System.Environment]::GetFolderPath('Programs')

    # 1. 探测操作系统与 PowerShell 环境
    $osInfo = @{
        OSVersion = [System.Environment]::OSVersion.VersionString
        Is64BitOS = [System.Environment]::Is64BitOperatingSystem
        Is64BitProcess = [System.Environment]::Is64BitProcess
        PSVersion = $PSVersionTable.PSVersion.ToString()
        PSEdition = $PSVersionTable.PSEdition
        UserProfile = $userProfile
        LocalAppData = $localAppData
        AppData = $appData
    }

    # 2. 探测 Antigravity 安装目录
    $candidateDirs = [System.Collections.Generic.List[string]]::new()
    if ($CustomAppDir) { $candidateDirs.Add($CustomAppDir) }
    if ($env:ANTIGRAVITY_APP_DIR) { $candidateDirs.Add($env:ANTIGRAVITY_APP_DIR) }
    $candidateDirs.Add((Join-Path $localAppData 'Programs\antigravity'))
    $candidateDirs.Add((Join-Path $appData 'Programs\antigravity'))
    $candidateDirs.Add('C:\Program Files\Antigravity')

    # 从运行进程探测
    try {
        $runningAg = Get-Process Antigravity -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($runningAg -and $runningAg.Path) {
            $candidateDirs.Add((Split-Path $runningAg.Path -Parent))
        }
    } catch {}

    # 从注册表探测卸载条目
    $regPaths = @(
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    foreach ($rp in $regPaths) {
        try {
            $items = Get-ItemProperty -Path $rp -ErrorAction SilentlyContinue
            foreach ($item in $items) {
                if ($item.DisplayName -match 'Antigravity') {
                    if ($item.InstallLocation -and (Test-Path -LiteralPath $item.InstallLocation)) {
                        $candidateDirs.Add($item.InstallLocation)
                    }
                    if ($item.DisplayIcon) {
                        $iconPath = $item.DisplayIcon.Trim('"')
                        if ($iconPath.EndsWith('.exe', [System.StringComparison]::OrdinalIgnoreCase)) {
                            $candidateDirs.Add((Split-Path $iconPath -Parent))
                        }
                    }
                }
            }
        } catch {}
    }

    $detectedAppDir = ''
    foreach ($cand in $candidateDirs) {
        if ([string]::IsNullOrWhiteSpace($cand)) { continue }
        $mainExe = Join-Path $cand 'Antigravity.exe'
        if (Test-Path -LiteralPath $mainExe) {
            $detectedAppDir = (Get-Item -LiteralPath $cand).FullName
            break
        }
    }
    if (-not $detectedAppDir -and $candidateDirs.Count -gt 0) {
        # 如果均不存在，取默认首选路径用于报告
        $detectedAppDir = $candidateDirs[0]
    }

    # 3. 探测版本
    $detectedVersion = 'Unknown'
    if ($detectedAppDir -and (Test-Path -LiteralPath $detectedAppDir)) {
        # 尝试从 version 文件读取
        $verFile = Join-Path $detectedAppDir 'version'
        if (Test-Path -LiteralPath $verFile) {
            $detectedVersion = (Get-Content -LiteralPath $verFile -Raw).Trim()
        }
        # 尝试从 app-update.yml 读取
        if ($detectedVersion -eq 'Unknown') {
            $updateYml = Join-Path $detectedAppDir 'resources\app-update.yml'
            if (Test-Path -LiteralPath $updateYml) {
                $ymlContent = Get-Content -LiteralPath $updateYml -Raw
                if ($ymlContent -match 'version:\s*([^\r\n]+)') {
                    $detectedVersion = $matches[1].Trim()
                }
            }
        }
        # 尝试从主程序文件版本信息读取
        if ($detectedVersion -eq 'Unknown') {
            $mainExePath = Join-Path $detectedAppDir 'Antigravity.exe'
            if (Test-Path -LiteralPath $mainExePath) {
                $fileVer = (Get-Item -LiteralPath $mainExePath).VersionInfo.ProductVersion
                if ($fileVer) { $detectedVersion = $fileVer.Trim() }
            }
        }
    }

    # 4. 探测代理配置与端口
    $proxySettings = [ordered]@{
        TargetHost = '127.0.0.1'
        TargetPort = $ProxyPort
        Mode = 'DirectOrProxy'
        ConfigFound = $false
        ConfigPath = ''
        EnvProxy = ''
    }

    if ($env:HTTP_PROXY) { $proxySettings.EnvProxy = $env:HTTP_PROXY }
    elseif ($env:ALL_PROXY) { $proxySettings.EnvProxy = $env:ALL_PROXY }

    if ($detectedAppDir) {
        $cfgFile = Join-Path $detectedAppDir 'config.json'
        if (Test-Path -LiteralPath $cfgFile) {
            $proxySettings.ConfigPath = $cfgFile
            $proxySettings.ConfigFound = $true
            try {
                $cfgJson = Get-Content -LiteralPath $cfgFile -Raw -Encoding utf8 | ConvertFrom-Json
                if ($cfgJson.proxy.host) { $proxySettings.TargetHost = $cfgJson.proxy.host }
                if ($cfgJson.proxy.port) { $proxySettings.TargetPort = [int]$cfgJson.proxy.port }
            } catch {}
        }
    }

    # 5. 探测运行时工具依赖
    $runtimes = [ordered]@{}

    # Node.js 探测
    $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
    $runtimes['Node'] = @{
        Installed = [bool]$nodeCmd
        Path = if ($nodeCmd) { $nodeCmd.Source } else { '' }
        Version = if ($nodeCmd) {
            try { (node --version).Trim() } catch { 'Unknown' }
        } else { 'Not Installed' }
    }

    # Git 探测
    $gitCmd = Get-Command git -ErrorAction SilentlyContinue
    $runtimes['Git'] = @{
        Installed = [bool]$gitCmd
        Path = if ($gitCmd) { $gitCmd.Source } else { '' }
        Version = if ($gitCmd) {
            try { (git --version).Trim() } catch { 'Unknown' }
        } else { 'Not Installed' }
    }

    # PowerShell 探测
    $runtimes['PowerShell'] = @{
        Installed = $true
        Path = (Get-Process -Id $PID).Path
        Version = $PSVersionTable.PSVersion.ToString()
    }

    # 6. 探测快捷方式路径
    $shortcuts = [ordered]@{
        Desktop = Join-Path $desktopDir 'Antigravity.lnk'
        StartMenu = Join-Path $programsDir 'Antigravity.lnk'
    }

    # 7. 探测智能体配置、插件与 Skill 目录
    $geminiConfigDir = Join-Path $userProfile '.gemini\config'
    $geminiSkillsDir = Join-Path $geminiConfigDir 'skills'
    $geminiPluginsDir = Join-Path $geminiConfigDir 'plugins'
    $geminiRulesFile = Join-Path $geminiConfigDir 'rules\AGENTS.md'
    $geminiRootRules = Join-Path $geminiConfigDir 'AGENTS.md'
    $geminiConfigFile = Join-Path $geminiConfigDir 'config.json'

    $agentEnvironment = [ordered]@{
        ConfigDir = $geminiConfigDir
        ConfigDirExists = (Test-Path -LiteralPath $geminiConfigDir)
        SkillsDir = $geminiSkillsDir
        SkillsDirExists = (Test-Path -LiteralPath $geminiSkillsDir)
        PluginsDir = $geminiPluginsDir
        PluginsDirExists = (Test-Path -LiteralPath $geminiPluginsDir)
        ChineseToolkitDir = Join-Path $geminiPluginsDir 'chinese-toolkit'
        ChineseToolkitExists = (Test-Path -LiteralPath (Join-Path $geminiPluginsDir 'chinese-toolkit\plugin.json'))
        RulesFile = $geminiRulesFile
        RulesFileExists = (Test-Path -LiteralPath $geminiRulesFile)
        ConfigFile = $geminiConfigFile
        ConfigFileExists = (Test-Path -LiteralPath $geminiConfigFile)
    }

    # 汇总输出
    $envSummary = [ordered]@{
        DiscoveryTime = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        ProjectRoot = $projectRoot
        OS = $osInfo
        Antigravity = [ordered]@{
            AppDir = $detectedAppDir
            IsInstalled = (Test-Path -LiteralPath (Join-Path $detectedAppDir 'Antigravity.exe'))
            Version = $detectedVersion
            LanguageServerExists = (Test-Path -LiteralPath (Join-Path $detectedAppDir 'resources\bin\language_server.exe'))
        }
        Proxy = $proxySettings
        Runtimes = $runtimes
        Shortcuts = $shortcuts
        Agent = $agentEnvironment
    }

    return [PSCustomObject]$envSummary
}

# 导出并保存到 outputs/environment.json
$envData = Get-AntigravityEnvironment -CustomAppDir $AppDir -ProxyPort $PreferredProxyPort

if (-not (Test-Path -LiteralPath $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}
$envJsonPath = Join-Path $outputDir 'environment.json'
$envData | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $envJsonPath -Encoding utf8

return $envData
