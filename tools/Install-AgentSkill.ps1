<#
.SYNOPSIS
    Antigravity Agent Skill 自动安装与注册工具 (Install-AgentSkill)
.DESCRIPTION
    将本项目自带的环境体检与快速维护 Skill 自动安装部署到本机 Antigravity
    全局配置目录 (~/.gemini/config/skills) 或指定工作区目录，支持 Junction 链接与目录同步。
#>

[CmdletBinding()]
param (
    [string]$TargetSkillsDir = '',
    [string]$SkillName = 'antigravity-windows-fast-patch',
    [switch]$ForceCopy,
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$sourceSkillFile = Join-Path $projectRoot 'SKILL.md'

if (-not (Test-Path -LiteralPath $sourceSkillFile)) {
    throw "项目根目录下未找到技能定义文件: $sourceSkillFile"
}

# 1. 动态定位目标 Skills 目录
if (-not $TargetSkillsDir) {
    $userProfile = [System.Environment]::GetFolderPath('UserProfile')
    $geminiConfig = Join-Path $userProfile '.gemini\config'
    $TargetSkillsDir = Join-Path $geminiConfig 'skills'
}

if (-not (Test-Path -LiteralPath $TargetSkillsDir)) {
    New-Item -ItemType Directory -Path $TargetSkillsDir -Force | Out-Null
}

$destSkillPath = Join-Path $TargetSkillsDir $SkillName

# 2. 检查当前安装状态
$installMode = 'None'
$isUpToDate = $false

if (Test-Path -LiteralPath $destSkillPath) {
    $item = Get-Item -LiteralPath $destSkillPath
    if ($item.LinkType -eq 'Junction' -or $item.LinkType -eq 'SymbolicLink') {
        $target = $item.Target
        if ($target -and ($target.TrimEnd('\') -eq $projectRoot.TrimEnd('\'))) {
            $isUpToDate = $true
            $installMode = "ExistingLink ($($item.LinkType))"
        } else {
            # 链接存在但指向其他位置，需要更新
            Remove-Item -LiteralPath $destSkillPath -Force
        }
    } else {
        # 存在普通目录
        if ($ForceCopy) {
            $installMode = 'DirectoryCopy'
        } else {
            # 若不是 ForceCopy，则保留或替换
            $installMode = 'Directory'
        }
    }
}

# 3. 执行安装或更新
$actionResult = 'Unchanged'
if (-not $isUpToDate) {
    if ($ForceCopy) {
        if (Test-Path -LiteralPath $destSkillPath) {
            Remove-Item -LiteralPath $destSkillPath -Recurse -Force
        }
        New-Item -ItemType Directory -Path $destSkillPath -Force | Out-Null
        Copy-Item -LiteralPath $sourceSkillFile -Destination (Join-Path $destSkillPath 'SKILL.md') -Force
        $actionResult = 'Copied'
    } else {
        # 优先使用 Windows Junction (目录联接，不需要管理员权限)
        try {
            cmd /c mklink /J "$destSkillPath" "$projectRoot" >nul 2>&1
            if (Test-Path -LiteralPath (Join-Path $destSkillPath 'SKILL.md')) {
                $actionResult = 'JunctionCreated'
                $isUpToDate = $true
            } else {
                throw "Junction 创建后验证失败"
            }
        } catch {
            # 回退到文件同步拷贝
            if (Test-Path -LiteralPath $destSkillPath) {
                Remove-Item -LiteralPath $destSkillPath -Recurse -Force
            }
            New-Item -ItemType Directory -Path $destSkillPath -Force | Out-Null
            Copy-Item -LiteralPath $sourceSkillFile -Destination (Join-Path $destSkillPath 'SKILL.md') -Force
            $actionResult = 'FallbackCopied'
            $isUpToDate = $true
        }
    }
}

# 4. 验证安装结果
$verifyOk = $false
$installedSkillFile = Join-Path $destSkillPath 'SKILL.md'
if (Test-Path -LiteralPath $installedSkillFile) {
    $skillContent = Get-Content -LiteralPath $installedSkillFile -Raw -Encoding utf8
    if ($skillContent -match 'name:\s*antigravity-windows-fast-patch') {
        $verifyOk = $true
    }
}

if (-not $Quiet) {
    Write-Host "`n==== Antigravity Agent Skill 自动安装与注册 ====" -ForegroundColor Cyan
    Write-Host "  源技能路径: $projectRoot" -ForegroundColor Gray
    Write-Host "  安装目标目录: $destSkillPath" -ForegroundColor Gray
    Write-Host "  操作结果: $actionResult" -ForegroundColor Yellow
    if ($verifyOk) {
        Write-Host "  [OK] Skill 验证成功！智能体已能够自动发现并调用本维护技能。" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] Skill 安装后未能通过元数据有效性核验。" -ForegroundColor Red
    }
}

return [PSCustomObject]@{
    SkillName = $SkillName
    SourcePath = $projectRoot
    InstalledPath = $destSkillPath
    ActionResult = $actionResult
    IsValid = $verifyOk
}
