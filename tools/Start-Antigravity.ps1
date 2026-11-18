[CmdletBinding()]
param (
    [string]$AppDir = '',
    [int]$ProxyPort = 65532
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$repair = Join-Path $projectRoot 'run-check-and-fix.bat'

try {
    $check = & (Join-Path $PSScriptRoot 'Check-Antigravity.ps1') -AppDir $AppDir -ExpectedProxyPort $ProxyPort -ForLaunch -Quiet
    if ($check.Ready) {
        $wscript = Join-Path $env:WINDIR 'System32\wscript.exe'
        Start-Process -FilePath $wscript -ArgumentList ('"' + $check.Launcher + '"') -WorkingDirectory $check.AppDir
        return
    }
} catch {
    Write-Warning $_.Exception.Message
}

Start-Process -FilePath $env:ComSpec -ArgumentList ('/d /c ""' + $repair + '""') -WorkingDirectory $projectRoot -WindowStyle Normal
