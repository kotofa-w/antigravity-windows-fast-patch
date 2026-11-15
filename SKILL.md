---
name: antigravity-windows-fast-patch
description: Diagnose and repair Windows Google Antigravity (AGY) client environment after updates, including proxy DLL injection (version.dll v2.4), HTTP proxy routing (port 65532), launcher shortcuts, ASAR Chinese localization with AST syntax check and unpacked chrome-devtools-mcp structural protection, agent rules/toolkit sync, automated diagnostic prompt generation, and atomic rollback.
---

# Antigravity Windows 快速环境维护技能 (Antigravity Windows Fast Patch)

当用户反映 Google Antigravity 客户端因官方更新导致汉化失效、代理断开、快捷方式重置，或需要对 Antigravity 环境执行自适应体检、闭环修复、Agent 接管诊断与一键回滚时，使用此技能。

---

## 平台与自适应环境约束

- **操作系统**：仅支持 Windows 10 / 11 64-bit。
- **客户端根目录**：动态探测，默认位于 `$env:LOCALAPPDATA\Programs\antigravity`。
- **代理端口依赖**：本地 HTTP 代理服务端口（默认 `127.0.0.1:65532`，支持自定义端口）。
- **受保护二进制防篡改**：`Antigravity.exe` 与 `resources\bin\language_server.exe` 属于受保护核心二进制，严禁篡改或覆盖，修复前后必须核验 SHA256。
- **零硬编码原则**：项目采用相对路径与动态环境发现，支持开源分发与跨机迁移。

---

## 核心能力与统一检查协议

本技能维护 6 大维度及 17 项统一协议检查点（状态代码：`pass` / `warning` / `fail` / `skipped` / `unknown`）：

| 检查维度 | 覆盖检查项 ID | 核心根因与处置策略 |
| --- | --- | --- |
| **客户端与核心程序** | `CORE-BIN-01`, `02`, `03` | 核验安装目录与 `Antigravity.exe` / `language_server.exe` 完整性与未篡改哈希 |
| **代理补丁交付 (v2.4)** | `PROXY-01`, `02`, `03` | 重新部署 `version.dll` (v2.4)、校验 `config.json` 规则并确保 VBS 启动脚本就绪 |
| **快捷方式启动器** | `SHORTCUT-01`, `02` | 重新定向桌面与开始菜单快捷方式指向 VBS 启动脚本；支持零停机热修复 |
| **宿主 ASAR 汉化** | `ASAR-01`, `02`, `03` | 增量合成 UI 脚本，通过 AST 编译校验，严格继承 `{ unpack: '**/chrome-devtools-mcp/**' }` 外置标记 |
| **运行态与代理连接** | `RUNTIME-01`, `02` | 检查应用进程与语言服务器活跃状态，核验目标代理端口 TCP 活跃连接数 |
| **智能体规则与 Skill** | `AGENT-01`, `02`, `03`, `SKILL-01` | 同步 `chinese-toolkit` 插件、对齐全局 `AGENTS.md` 规则、核准自动执行策略并确认 Skill 注册状态 |

---

## Agent 三大标准协作工作流

### 工作流 1：自适应只读健康体检 (Health Check)

在执行任何写操作前，Agent 应优先运行只读体检获取当前环境的事实证据：

```powershell
# 定位项目根目录并执行体检
$ProjectRoot = (Get-Item .).FullName
powershell.exe -ExecutionPolicy Bypass -File "$ProjectRoot\Check-And-Fix-Antigravity.ps1" -CheckOnly
```

**诊断结果读取与解析**：
- 结构化 JSON 报告：`outputs/health-runs/<run-id>/summary.json`
- 可读 Markdown 报告：`outputs/health-runs/<run-id>/summary.md`
- 最新状态软链：`outputs/latest-run.json`

### 工作流 2：闭环安全修复 (Safe Fix)

当检测发现异常项且用户明确要求修复时：

```powershell
# 自动创建快照备份、必要时安全退出冲突进程、执行精准修复并在完成后拉起应用
powershell.exe -ExecutionPolicy Bypass -File "$ProjectRoot\Check-And-Fix-Antigravity.ps1" -Fix -CloseProcess -Launch
```

**安全保障准则**：
1. **前置快照备份**：自动在 `outputs/` 下创建时间戳快照（备份原版 `app.asar`、原快捷方式与 `before.json` 基线）；
2. **零停机判定**：若仅快捷方式异常而核心程序文件完好，无需关闭应用，直接原地更新；
3. **AST 编译校验**：修改后的前端脚本必须在内存中通过 `new vm.Script()` 语法编译校验才允许打包；
4. **防篡改门禁**：修复结束后重新校验 `Antigravity.exe` 与 `language_server.exe` 哈希，若有变动立即阻断；
5. **复检闭环**：修复完成后自动重新执行全维体检，确认所有项均恢复为 PASS。

### 工作流 3：脚本失败移交与 Agent 协同 (Agent Prompt)

当自动化脚本在复杂更新或未知环境下未能完全解决问题时：
1. 脚本会自动生成接管提示词并输出至 `agent-prompt.md`；
2. 用户或脚本调用 `tools/Export-AgentPrompt.ps1 -CopyToClipboard` 将上下文写入剪贴板；
3. Agent 读取 `agent-prompt.md` 了解已知异常、已执行步骤及目标状态，直接进行针对性排查，避免重复执行基础步骤。

---

## 一键安全回滚 (Rollback)

若修复后遇到未知崩溃或用户要求还原官方原版：

```powershell
powershell.exe -ExecutionPolicy Bypass -File "$ProjectRoot\Check-And-Fix-Antigravity.ps1" -Rollback -CloseProcess
```

脚本会自动从最近的备份目录中提取对应的原版 `app.asar` 与快捷方式进行原子还原。

---

## 技术专题参考

- [ASAR 汉化合成与结构保护引擎](references/asar-patch-engine.md)
- [代理 DLL 劫持与流量路由机制](references/proxy-dll-injection.md)
- [快捷方式修复与零停机热修复机制](references/shortcut-restoration.md)
