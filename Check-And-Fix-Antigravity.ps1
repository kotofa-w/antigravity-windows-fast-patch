<#
.SYNOPSIS
    Antigravity 一键检验与修复总控脚本 (独立产物套件版)
.DESCRIPTION
    集成全维体检、自动备份、代理补丁修复、快捷方式修复、精准汉化合成注入及一键回滚。
#>

[CmdletBinding()]
param (
    [switch]$CheckOnly,
    [switch]$Fix,
    [switch]$Rollback,
    [switch]$CloseProcess,
    [switch]$Launch,
    [string]$AppDir = 'C:\Users\123\AppData\Local\Programs\antigravity'
)

$ErrorActionPreference = 'Stop'
$projectDir = $PSScriptRoot
$toolsDir = Join-Path $projectDir 'tools'
$checkScript = Join-Path $toolsDir 'Check-Antigravity.ps1'
$fixScript = Join-Path $toolsDir 'Fix-Antigravity.ps1'
$rollbackScript = Join-Path $toolsDir 'Rollback-Antigravity.ps1'

function Show-Banner {
    Write-Host @"
===================================================================
      Antigravity 补丁环境一键检验与智能修复独立套件
===================================================================
"@ -ForegroundColor Cyan
}

Show-Banner

# 回滚模式分支
if ($Rollback) {
    Write-Host "`n>>> 正在启动安全回滚流程..." -ForegroundColor Magenta
    & $rollbackScript -AppDir $AppDir -CloseRunningProcess:$CloseProcess
    exit 0
}

# 执行全面体检
Write-Host "`n>>> 正在执行全维环境健康体检..." -ForegroundColor Cyan
$checkResult = & $checkScript -AppDir $AppDir

if ($CheckOnly) {
    exit $(if ($checkResult.Status -eq 'Healthy') { 0 } else { 1 })
}

# 判定是否需要修复
if ($checkResult.Status -eq 'Healthy') {
    Write-Host "`n===================================================================" -ForegroundColor Green
    Write-Host "  恭喜！检测未发现任何异常，代理补丁、快捷方式与汉化均处于正常状态！" -ForegroundColor Green
    Write-Host "===================================================================" -ForegroundColor Green
    exit 0
}

# 如果带了 -Fix 参数，直接自动执行修复
if ($Fix) {
    Write-Host "`n>>> 检测到 -Fix 标志，正在自动开始闭环修复..." -ForegroundColor Yellow
    & $fixScript -AppDir $AppDir -CloseRunningProcess:$CloseProcess -LaunchAfterFix:$Launch
    Write-Host "`n>>> 修复后二次复验：" -ForegroundColor Cyan
    & $checkScript -AppDir $AppDir
    exit 0
}

# 交互式提示模式
Write-Host "`n===================================================================" -ForegroundColor Yellow
Write-Host "  检测到以上项需要修复/优化。请选择操作：" -ForegroundColor Yellow
Write-Host "  [1] 立即执行一键自动修复并重启 Antigravity (推荐)" -ForegroundColor White
Write-Host "  [2] 仅执行一键自动修复，稍后手动启动" -ForegroundColor White
Write-Host "  [3] 退出不做改动" -ForegroundColor Gray
Write-Host "===================================================================" -ForegroundColor Yellow

$choice = Read-Host "请输入数字选项 [1/2/3, 默认 1]"
if ([string]::IsNullOrWhiteSpace($choice)) { $choice = '1' }

switch ($choice) {
    '1' {
        Write-Host "`n>>> 开始执行自动修复与拉起..." -ForegroundColor Cyan
        & $fixScript -AppDir $AppDir -CloseRunningProcess -LaunchAfterFix
        Write-Host "`n>>> 修复完成，正在复核状态：" -ForegroundColor Cyan
        & $checkScript -AppDir $AppDir
    }
    '2' {
        Write-Host "`n>>> 开始执行自动修复..." -ForegroundColor Cyan
        & $fixScript -AppDir $AppDir -CloseRunningProcess
        Write-Host "`n>>> 修复完成，正在复核状态：" -ForegroundColor Cyan
        & $checkScript -AppDir $AppDir
    }
    Default {
        Write-Host "`n已取消修复，未做任何更改。" -ForegroundColor Gray
    }
}
