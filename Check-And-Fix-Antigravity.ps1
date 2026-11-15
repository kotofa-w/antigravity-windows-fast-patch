<#
.SYNOPSIS
    Antigravity 环境维护系统主控程序 (Check-And-Fix-Antigravity)
.DESCRIPTION
    支持全维体检、自动快照备份修复、动态 Agent 提示词生成、
    内置 Skill 部署注册、结构化诊断报告合并展示与一键原子回滚。
#>

[CmdletBinding()]
param (
    [switch]$CheckOnly,
    [switch]$Fix,
    [switch]$ExportPrompt,
    [switch]$InstallSkill,
    [switch]$FullMaintenance,
    [switch]$Rollback,
    [switch]$CloseProcess,
    [switch]$Launch,
    [switch]$CopyToClipboard,
    [string]$AppDir = '',
    [int]$ProxyPort = 65532,
    [switch]$NoPrompt
)

$ErrorActionPreference = 'Stop'
$projectRoot = $PSScriptRoot
$toolsDir = Join-Path $projectRoot 'tools'
$checkScript = Join-Path $toolsDir 'Check-Antigravity.ps1'
$fixScript = Join-Path $toolsDir 'Fix-Antigravity.ps1'
$rollbackScript = Join-Path $toolsDir 'Rollback-Antigravity.ps1'
$promptScript = Join-Path $toolsDir 'Export-AgentPrompt.ps1'
$installSkillScript = Join-Path $toolsDir 'Install-AgentSkill.ps1'
$discoveryScript = Join-Path $toolsDir 'EnvironmentDiscovery.ps1'

function Show-Banner {
    Write-Host @"
===================================================================
          Antigravity 统一环境维护系统 (Agent 增强版)
===================================================================
"@ -ForegroundColor Cyan
}

function Show-Menu {
    Write-Host @"

  [1] 一键检查与修复 (自动检测并修复异常项)
  [2] 仅检查环境 (全维只读体检，输出诊断报告)
  [3] 生成 Agent 提示词 (导出接管提示词并可复制到剪贴板)
  [4] 安装或更新 Agent Skill (向 Antigravity 全局注册维护技能)
  [5] 查看诊断报告 (浏览最近一次体检 Markdown 报告)
  [6] 回滚 (安全还原至官方原版 ASAR 与原始快捷方式)
  [0] 退出
===================================================================
"@ -ForegroundColor Yellow
}

function Handle-FailurePrompt([string]$runId, [string]$actionsTaken = '自动维护未能完全解决问题。') {
    Write-Host "`n===================================================================" -ForegroundColor Red
    Write-Host "  自动维护未能完全解决问题。" -ForegroundColor Yellow
    Write-Host "`n  已自动生成：" -ForegroundColor Cyan
    Write-Host "  - 诊断报告 (outputs/health-runs/$runId/summary.md)" -ForegroundColor White
    Write-Host "  - Agent 接管提示词 (agent-prompt.md)" -ForegroundColor White
    Write-Host "===================================================================" -ForegroundColor Red
    Write-Host "  [1] 复制提示词到剪贴板" -ForegroundColor White
    Write-Host "  [2] 打开提示词文件" -ForegroundColor White
    Write-Host "  [3] 返回主菜单" -ForegroundColor White
    Write-Host "  [0] 退出" -ForegroundColor Gray
    Write-Host "===================================================================" -ForegroundColor Red

    $subChoice = Read-Host "请选择操作 [1/2/3/0, 默认 1]"
    if ([string]::IsNullOrWhiteSpace($subChoice)) { $subChoice = '1' }

    $promptRes = & $promptScript -RunId $runId -ActionsTaken $actionsTaken -CopyToClipboard:($subChoice -eq '1')
    switch ($subChoice) {
        '1' {
            Write-Host "`n[OK] 提示词已写入剪贴板，请直接粘贴到 AI 助手对话框中！" -ForegroundColor Green
        }
        '2' {
            $pPath = Join-Path $projectRoot 'agent-prompt.md'
            Start-Process notepad.exe $pPath
        }
        Default {}
    }
}

Show-Banner

# 命令行直接调用分支

if ($Rollback) {
    Write-Host "`n>>> 正在启动安全回滚流程..." -ForegroundColor Magenta
    & $rollbackScript -AppDir $AppDir -CloseRunningProcess:$CloseProcess
    return
}

if ($InstallSkill) {
    Write-Host "`n>>> 正在安装/注册 Agent Skill..." -ForegroundColor Cyan
    & $installSkillScript
    return
}

if ($ExportPrompt) {
    Write-Host "`n>>> 正在生成 Agent 任务提示词..." -ForegroundColor Cyan
    if ($CopyToClipboard) {
        & $promptScript -CopyToClipboard
    } else {
        & $promptScript
    }
    return
}

if ($CheckOnly) {
    Write-Host "`n>>> 正在执行全维环境健康体检..." -ForegroundColor Cyan
    $res = & $checkScript -AppDir $AppDir -ExpectedProxyPort $ProxyPort
    if ($res.Status -eq 'Healthy') { return } else { throw "体检发现未通过项" }
}

if ($Fix) {
    Write-Host "`n>>> 正在执行一键闭环修复..." -ForegroundColor Yellow
    $runId = 'run-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
    $fixRes = & $fixScript -AppDir $AppDir -ProxyPort $ProxyPort -CloseRunningProcess:$CloseProcess -LaunchAfterFix:$Launch
    Write-Host "`n>>> 修复后二次复验：" -ForegroundColor Cyan
    $reCheck = & $checkScript -AppDir $AppDir -ExpectedProxyPort $ProxyPort -RunId $runId
    if ($reCheck.Status -ne 'Healthy') {
        Handle-FailurePrompt -runId $runId -actionsTaken "已运行 Fix-Antigravity.ps1 执行基础修复，但复检依然存在未决异常。"
        throw "修复后复检未完全通过"
    } else {
        Write-Host "`n>>> [恭喜] 修复完毕，环境已恢复全维健康！" -ForegroundColor Green
        return
    }
}

if ($FullMaintenance) {
    Write-Host "`n>>> 正在执行完整一键维护流程..." -ForegroundColor Cyan
    $runId = 'run-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
    Write-Host "1. 前置健康体检..." -ForegroundColor Gray
    $initialCheck = & $checkScript -AppDir $AppDir -ExpectedProxyPort $ProxyPort -RunId $runId
    if ($initialCheck.Status -ne 'Healthy') {
        Write-Host "`n2. 检测到异常项，开始安全修复..." -ForegroundColor Yellow
        & $fixScript -AppDir $AppDir -ProxyPort $ProxyPort -CloseRunningProcess:$CloseProcess -LaunchAfterFix:$Launch
        Write-Host "`n3. 修复后复查..." -ForegroundColor Gray
        $postCheck = & $checkScript -AppDir $AppDir -ExpectedProxyPort $ProxyPort -RunId $runId
        if ($postCheck.Status -ne 'Healthy') {
            Handle-FailurePrompt -runId $runId -actionsTaken "完整维护流程中执行了自动修复，但仍有残留待解决项。"
            throw "维护后复检未完全通过"
        }
    }
    Write-Host "`n4. 确认 Agent Skill 注册状态..." -ForegroundColor Gray
    & $installSkillScript -Quiet
    Write-Host "`n5. 维护完成，全维健康就绪！" -ForegroundColor Green
    return
}

# 交互式主菜单循环
while ($true) {
    Show-Menu
    $choice = Read-Host "请输入数字选项 [1-6, 0 退出]"
    if ([string]::IsNullOrWhiteSpace($choice)) { $choice = '1' }

    switch ($choice) {
        '1' {
            Write-Host "`n>>> [1] 正在执行一键检查与修复..." -ForegroundColor Cyan
            $runId = 'run-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
            $cRes = & $checkScript -AppDir $AppDir -ExpectedProxyPort $ProxyPort -RunId $runId
            if ($cRes.Status -eq 'Healthy') {
                Write-Host "`n>>> 当前环境处于全维健康状态，无需修复！" -ForegroundColor Green
            } else {
                Write-Host "`n>>> 检测到需要修复的项，开始安全修复..." -ForegroundColor Yellow
                & $fixScript -AppDir $AppDir -ProxyPort $ProxyPort -CloseRunningProcess -LaunchAfterFix
                Write-Host "`n>>> 修复后二次复验：" -ForegroundColor Cyan
                $postRes = & $checkScript -AppDir $AppDir -ExpectedProxyPort $ProxyPort -RunId $runId
                if ($postRes.Status -ne 'Healthy') {
                    Handle-FailurePrompt -runId $runId -actionsTaken "已执行 Fix 修复，复检未全部通过。"
                } else {
                    Write-Host "`n>>> 恭喜，所有异常项均已修复并通过复核！" -ForegroundColor Green
                }
            }
        }
        '2' {
            Write-Host "`n>>> [2] 仅检查环境..." -ForegroundColor Cyan
            $runId = 'run-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
            $cRes = & $checkScript -AppDir $AppDir -ExpectedProxyPort $ProxyPort -RunId $runId
            Write-Host "`n诊断报告已保存至: outputs/health-runs/$runId/summary.md" -ForegroundColor Gray
        }
        '3' {
            Write-Host "`n>>> [3] 正在生成 Agent 提示词..." -ForegroundColor Cyan
            $pRes = & $promptScript -CopyToClipboard
            Write-Host "`n提示词文件: $($pRes.PromptFile)" -ForegroundColor Gray
        }
        '4' {
            Write-Host "`n>>> [4] 正在安装或更新 Agent Skill..." -ForegroundColor Cyan
            & $installSkillScript
        }
        '5' {
            Write-Host "`n>>> [5] 查看最近一次诊断报告..." -ForegroundColor Cyan
            $latestRunJson = Join-Path $projectRoot 'outputs\latest-run.json'
            if (Test-Path -LiteralPath $latestRunJson) {
                $lData = Get-Content -LiteralPath $latestRunJson -Raw -Encoding utf8 | ConvertFrom-Json
                $runId = $lData.RunId
                $sumMd = Join-Path $projectRoot "outputs\health-runs\$runId\summary.md"
                if (Test-Path -LiteralPath $sumMd) {
                    Get-Content -LiteralPath $sumMd -Raw -Encoding utf8 | Write-Host
                } else {
                    Write-Host "未找到报告文件: $sumMd" -ForegroundColor Yellow
                }
            } else {
                Write-Host "尚未执行过体检，请先运行选项 [2] 仅检查环境。" -ForegroundColor Yellow
            }
        }
        '6' {
            Write-Host "`n>>> [6] 正在启动安全回滚流程..." -ForegroundColor Magenta
            & $rollbackScript -AppDir $AppDir -CloseRunningProcess
        }
        '0' {
            Write-Host "`n已退出维护程序。" -ForegroundColor Gray
            exit 0
        }
        Default {
            Write-Host "`n无效选项，请重新输入。" -ForegroundColor Yellow
        }
    }

    Write-Host "`n按任意键继续..." -ForegroundColor Gray
    [System.Console]::ReadKey($true) | Out-Null
}
