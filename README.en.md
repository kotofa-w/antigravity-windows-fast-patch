<div align="center">

<h1>Antigravity Windows Fast Patch Skill</h1>

<p>Agent Skill & Maintenance Toolkit for Google Antigravity (AGY) Client on Windows</p>

<p>
  <img src="https://img.shields.io/badge/Windows-0078D4?style=flat-square" alt="Windows">
  <img src="https://img.shields.io/badge/Antigravity-4285F4?style=flat-square" alt="Antigravity">
  <img src="https://img.shields.io/badge/PowerShell-5391FE?style=flat-square" alt="PowerShell">
  <img src="https://img.shields.io/badge/License-MIT-green?style=flat-square" alt="License">
</p>

<p><a href="README.md">中文</a> &nbsp;/&nbsp; <strong>English</strong></p>

</div>

---

A community Agent Skill and self-contained maintenance toolkit designed for Google Antigravity on Windows. It addresses regression issues frequently caused by upstream updates, including lost proxy configurations, overwritten ASAR localization, and reset desktop shortcuts.

## Key Capabilities

- **Winsock DLL Hijacking (`version.dll` v2.4)**: Routes all traffic from Antigravity and its child processes (`language_server.exe`, `agy.exe`) to local HTTP proxy `127.0.0.1:65532`.
- **Zero-Downtime Shortcut Restoration**: Restores desktop and start menu shortcuts to `launch-antigravity-65532.vbs` without restarting active client processes if binaries are intact.
- **AST-Verified Incremental ASAR Localization**: Merges UI script translations with in-memory `vm.Script` syntax checks before repacking.
- **Unpacked Dependency Protection**: Strictly preserves `{ unpack: '**/chrome-devtools-mcp/**' }` packing rules to prevent MCP extensions from crashing.
- **Tamper-Proof Binary Verification**: Validates SHA256 hashes of `Antigravity.exe` and `language_server.exe` before and after modifications.

## Usage

### 1. Interactive Batch Launcher (Recommended)
Double-click `一键检验与修复.bat` in the root directory for automated diagnostic and interactive remediation.

### 2. PowerShell CLI
```powershell
# Read-only health check
.\Check-And-Fix-Antigravity.ps1 -CheckOnly

# Automatic snapshot backup and remediation
.\Check-And-Fix-Antigravity.ps1 -Fix -CloseProcess -Launch

# Atomic rollback to vanilla official ASAR
.\Check-And-Fix-Antigravity.ps1 -Rollback -CloseProcess
```

## References

- [ASAR Patching & Structural Protection](references/asar-patch-engine.md)
- [Proxy DLL Injection & Routing](references/proxy-dll-injection.md)
- [Shortcut Restoration & Zero-Downtime Fixing](references/shortcut-restoration.md)

## License

Released under the [MIT License](LICENSE).
