---
name: antigravity-windows-fast-patch
description: Diagnose and repair Windows Google Antigravity (AGY) client after official updates, including proxy DLL injection (version.dll v2.4), HTTP proxy config (port 65532), VBS launcher and shortcut repair, host ASAR Chinese localization with AST syntax verification and unpacked chrome-devtools-mcp structural protection, agent chinese-toolkit plugin sync, and zero-downtime hot-repair.
---

# Antigravity Windows 快速补丁技能 (Antigravity Windows Fast Patch)

当用户反映 Google Antigravity 客户端因官方自动更新或重新安装导致汉化失效、代理断开、快捷方式重置，或需要对 Antigravity 环境执行健康诊断、补丁闭环恢复与原子回滚时，使用此技能。

---

## 平台与环境约束

- **操作系统**：仅支持 Windows 10 / 11 64-bit。
- **客户端根目录**：默认位于 `$env:LOCALAPPDATA\Programs\antigravity`。
- **代理端口依赖**：本地 HTTP 代理服务端口 `127.0.0.1:65532`。
- **核心二进制防篡改**：`Antigravity.exe` 与 `resources\bin\language_server.exe` 属于受保护核心二进制，严禁篡改或覆盖，修复前后必须核验 SHA256。

---

## 核心能力与覆盖范围

| 异常现象 | 核心根因 | 修复策略 |
| --- | --- | --- |
| **界面恢复默认英文** | 官方更新覆盖 `resources\app.asar` | 备份原版 ASAR，提取汉化脚本进行 AST 语法验证，继承外置解包规则重新打包 |
| **网络代理连接断开** | 更新导致 `version.dll` 或 `config.json` 丢失 | 重新部署已核验的 `version.dll` (v2.4) 与 `config.json` (65532) |
| **双击图标无法走代理** | 快捷方式被重置指向 `Antigravity.exe` | 重新定向快捷方式指向 `launch-antigravity-65532.vbs`（支持零停机热修复） |
| **MCP 插件依赖报错** | ASAR 打包损坏了 `chrome-devtools-mcp` | 严格继承 `{ unpack: '**/chrome-devtools-mcp/**' }` 外置打包配置 |
| **智能体交互规则漂移** | 用户规则或策略配置未对齐 | 自动同步 `chinese-toolkit` 插件与 `AGENTS.md` 全局规则 |

---

## 标准工作流 (Workflows)

### 1. 全维只读健康体检 (Health Check)

在执行任何写操作前，优先运行只读体检获取当前环境的事实依据：

```powershell
& "D:\Agent\Antigravity\环境修复\Check-And-Fix-Antigravity.ps1" -CheckOnly
```

体检涵盖 6 大核心维度：
1. 客户端安装与受保护二进制完整性；
2. 代理组件（`version.dll`、`config.json`、VBS 脚本）哈希核验；
3. 桌面与开始菜单快捷方式指向；
4. `app.asar` 汉化状态与外置解包目录检查；
5. 运行态进程与 65532 代理 TCP 活跃连接数；
6. 智能体中文插件与全局规则策略一致性。

### 2. 闭环安全修复 (Safe Fix)

当检测发现异常项且用户明确要求修复时：

```powershell
# 自动创建快照备份、必要时安全退出冲突进程、执行精准修复并在完成后拉起应用
& "D:\Agent\Antigravity\环境修复\Check-And-Fix-Antigravity.ps1" -Fix -CloseProcess -Launch
```

**安全保障准则**：
- **前置快照备份**：自动在 `outputs/` 下创建时间戳快照（备份原版 `app.asar`、原快捷方式与 `before.json` 基线）；
- **零停机判定**：若仅快捷方式异常而核心程序文件完好，无需关闭应用，直接原地更新；
- **AST 编译校验**：修改后的前端脚本必须在内存中通过 `new vm.Script()` 语法编译校验才允许打包；
- **防篡改门禁**：修复结束后重新校验 `Antigravity.exe` 与 `language_server.exe` 哈希，若有变动立即阻断。

### 3. 一键原子回滚 (Rollback)

若修复后遇到未知崩溃或用户要求还原官方原版：

```powershell
& "D:\Agent\Antigravity\环境修复\Check-And-Fix-Antigravity.ps1" -Rollback -CloseProcess
```

脚本会自动从最近的备份目录中提取对应的原版 `app.asar` 与快捷方式进行原子还原。

---

## 技术专题参考

- [ASAR 汉化合成与结构保护引擎](references/asar-patch-engine.md)
- [代理 DLL 劫持与流量路由机制](references/proxy-dll-injection.md)
- [快捷方式修复与零停机热修复机制](references/shortcut-restoration.md)
