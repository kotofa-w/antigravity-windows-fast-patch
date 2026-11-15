<div align="center">

<h1>Antigravity Windows Unified Environment Maintenance System (Agent Fast Patch Suite)</h1>

<p>An open-source full-dimensional health check, closed-loop repair, dynamic Agent collaboration, and atomic rollback suite for Google Antigravity (AGY) on Windows.</p>

<p>
  <img src="https://img.shields.io/badge/Windows-0078D4?style=flat-square" alt="Windows">
  <img src="https://img.shields.io/badge/Antigravity-4285F4?style=flat-square" alt="Antigravity">
  <img src="https://img.shields.io/badge/PowerShell-5391FE?style=flat-square" alt="PowerShell">
  <img src="https://img.shields.io/badge/License-MIT-green?style=flat-square" alt="License">
</p>

<p><a href="README.md">中文</a> &nbsp;/&nbsp; <strong>English</strong></p>

<p>
  <a href="#core-capabilities">Capabilities</a> &nbsp;·&nbsp;
  <a href="#usage">Usage</a> &nbsp;·&nbsp;
  <a href="#agent-collaboration">Agent Collaboration</a> &nbsp;·&nbsp;
  <a href="#upstream-acknowledgements">Upstream</a> &nbsp;·&nbsp;
  <a href="#security-policy">Security</a>
</p>

</div>

---

Addressing common issues caused by official Google Antigravity updates—such as missing proxy DLLs, reset shortcuts, overwritten ASAR localization, and drifting agent rules—this toolkit provides an all-in-one, ready-to-run environment maintenance solution.
It features automatic environment discovery, unified health check protocols, snapshot safety backups, AST syntax-level patch synthesis, dynamic Agent task prompt generation, and atomic rollbacks.

## Core Capabilities

| Dimension | Check Item ID | Diagnosis Basis | Repair Strategy |
| --- | --- | --- | --- |
| **Core Installation** | `CORE-BIN-01/02/03` | Verifies install directory and SHA256 integrity | Strictly enforces official binary tamper prevention |
| **Proxy DLL Injection** | `PROXY-01/02/03` | Checks `version.dll` (v2.4) and `config.json` | Injects proxy DLL; routes backend and language server traffic to local proxy (default `127.0.0.1:65532`) |
| **Shortcut Restoration** | `SHORTCUT-01/02` | Verifies desktop and Start Menu LNK targets | Re-routes shortcuts to `launch-antigravity-*.vbs`; supports zero-downtime hot repair |
| **Host ASAR Localization**| `ASAR-01/02` | Validates `resources\app.asar` state | Synthesizes modified UI scripts verified by AST syntax compiler without breaking new features |
| **Unpacked Resource Guard**| `ASAR-03` | Checks `chrome-devtools-mcp` | Strictly preserves `{ unpack: '**/chrome-devtools-mcp/**' }` to avoid extension crashes |
| **Runtime & Connectivity** | `RUNTIME-01/02` | Process activity and TCP proxy connection snapshot | Monitors client processes and active TCP connections on the proxy port |
| **Agent Rules & Skills** | `AGENT-01/02/03`, `SKILL-01` | Checks `chinese-toolkit` and `AGENTS.md` | Syncs interaction standards, aligns global rules, enforces auto-approval, and registers Agent Skill |

---

## Usage

### 1. Interactive Double-Click Launcher

Double-click **`一键检验与修复.bat`** in the project root to open the interactive menu:

```text
===================================================================
          Antigravity 统一环境维护系统 (Agent 增强版)
===================================================================

  [1] 一键检查与修复 (Auto-diagnose and fix anomalies)
  [2] 仅检查环境 (Read-only full check, exports summary report)
  [3] 生成 Agent 提示词 (Export handoff prompt with clipboard support)
  [4] 安装或更新 Agent Skill (Register maintenance skill to Antigravity)
  [5] 查看诊断报告 (View latest Markdown health report)
  [6] 回滚 (Safely restore official clean ASAR and original shortcuts)
  [0] 退出 (Exit)
===================================================================
```

### 2. Command Line (PowerShell)

Supports parameterized and headless invocations:

```powershell
# Read-only health check (outputs summary.json and summary.md)
.\Check-And-Fix-Antigravity.ps1 -CheckOnly

# Closed-loop fix (backups, closes processes, applies fixes, and launches app)
.\Check-And-Fix-Antigravity.ps1 -Fix -CloseProcess -Launch

# Generate and export Agent handoff prompt to clipboard
.\Check-And-Fix-Antigravity.ps1 -ExportPrompt -CopyToClipboard

# Register/update the Agent Skill into user's Antigravity config
.\Check-And-Fix-Antigravity.ps1 -InstallSkill

# Full maintenance pipeline (Check -> Fix -> Verify -> Register Skill)
.\Check-And-Fix-Antigravity.ps1 -FullMaintenance -CloseProcess

# Atomic rollback to clean official release
.\Check-And-Fix-Antigravity.ps1 -Rollback -CloseProcess
```

---

## Agent Collaboration

The toolkit supports three lightweight collaboration paths without requiring dedicated server daemons:

1. **Standalone Script Run**: The script attempts automatic repair; if unresolved anomalies persist, it generates `agent-prompt.md`.
2. **Script-to-Agent Handoff**: Users export the prompt (`-ExportPrompt -CopyToClipboard`) and paste it into any AI coding assistant (Antigravity, Codex, Claude Code, etc.) to resume investigation.
3. **Agent-Direct Execution**: Users instruct their agent:
   ```text
   Use antigravity-windows-fast-patch to check the Antigravity environment, create a backup if needed, and repair anomalies.
   ```
   The agent automatically follows `SKILL.md` and invokes project tools.

---

## Upstream Acknowledgements

This project builds upon work by the open-source community:

1. **Proxy DLL Injection (version.dll & traffic interception)**:
   - Upstream repository: [yuaotian/antigravity-proxy](https://github.com/yuaotian/antigravity-proxy)
   - Special thanks to `yuaotian` for the Winsock DLL hijacking and traffic redirection implementation.
2. **ASAR Packaging & Inspection**:
   - Built with `@electron/asar` for high-performance extraction and repackaging with unpacked layout preservation.

---

## Security Policy & Anti-Tampering

- **Protected Core Binaries**: `Antigravity.exe` and `resources\bin\language_server.exe` are official binaries. SHA256 hashes are verified before and after all operations. No modifications or overlays to official executables are ever made.
- **Snapshot First**: Automatic timestamped backups are created in `outputs/` before modifying ASAR or shortcuts.
- **Privacy Assurance**: Diagnostic prompts and reports never collect passwords, tokens, cookies, or private session data.

---

## License

Licensed under the [MIT License](LICENSE).
