# 当前状态

更新：2026-11-15（Asia/Hong_Kong；统一环境维护系统、环境自适应发现、动态 Agent 提示词生成器、统一检查协议及开源多模式运行全维通过）。

## 当前结论

2026-11-15 完成统一环境维护系统与开源发行架构升级：
1. **环境自适应发现 (EnvironmentDiscovery)**：开发 `tools/EnvironmentDiscovery.ps1`，消除开发机硬编码，支持动态识别 Windows 架构、用户目录、Antigravity 实际安装位置（2.32.1 / 44.9.1）、代理端口、运行时工具链及智能体配置，输出标准化 `outputs/environment.json`。
2. **统一检查协议与结构化报告**：重构 `tools/Check-Antigravity.ps1`，建立统一协议检查点（涵盖核心二进制、代理、快捷方式、ASAR 汉化、外置解包保护、运行态连接、智能体规则与 Skill 注册共 17 项），持久化输出 `outputs/health-runs/<run-id>/summary.json`、`summary.md` 及 `latest-run.json`。
3. **动态 Agent 任务提示词生成 (Export-AgentPrompt)**：开发 `tools/Export-AgentPrompt.ps1` 与模板 `templates/agent-prompt.md`，从最近诊断中提取事实、已知异常、工作准则与处置指令，生成 `agent-prompt.md` 并支持通过纯托管 API 复制至 Windows 剪贴板。
4. **Agent Skill 自动安装与注册 (Install-AgentSkill)**：开发 `tools/Install-AgentSkill.ps1`，实现将项目自带维护技能自动注册部署到全局 Agent 配置中（Junction/副本验证就绪）。
5. **统一主控与多模式菜单**：升级 `Check-And-Fix-Antigravity.ps1` 与 `一键检验与修复.bat`，提供 6 大标准菜单模式，自动修复未决时支持无缝触发 Agent 提示词移交分支，全面支持命令行静默参数（`-CheckOnly`、`-Fix`、`-ExportPrompt`、`-InstallSkill`、`-FullMaintenance`、`-Rollback`）。
6. **运行态核验保持**：当前环境在 Antigravity 2.32.1 真实运行下，17 项统一检查点全部 **PASS**，状态确认为 **Healthy（全维健康）**。

---

## 核心受保护与运行态指标核验证据

1. **核心受保护二进制**：
   - 主程序 `Antigravity.exe` SHA256：`AEAF47C28AC1B7406F27AE610DDED0E4C8E2F972F553D8840CDEE7DB767BF1E8`，未篡改。
   - 语言服务器 `resources\bin\language_server.exe` SHA256：`65CDB8D132FC61056625081BE7D07D4D22F57EBA485DE7EDF0D24D98E77C891F`，未篡改。
2. **代理补丁交付 (v2.4)**：
   - 代理 DLL `version.dll` SHA256：`40F037232A180DA8DFF7611021270549FCC4E208580D8BF0F70BC9975F871B5F`（上游：`yuaotian/antigravity-proxy`）。
   - 代理配置 `config.json` 规则生效，目标指向 HTTP `127.0.0.1:65532`。
   - VBS 启动脚本 `launch-antigravity-65532.vbs` 正常存在。
3. **快捷方式指向**：
   - 桌面快捷方式与开始菜单快捷方式均正确指向 `C:\Windows\System32\wscript.exe` 并携带 VBS 启动脚本参数。
4. **宿主汉化补丁与 ASAR 资源**：
   - 当前已安装 `resources\app.asar` SHA256：`88204F4B7C4B8D0C68246B76B9E6965345FA7036340310BAAAC10A1A5608169C`。
   - ASAR 包含 1208 个条目，外置解包规则 `{ unpack: '**/chrome-devtools-mcp/**' }` 正确生效，经语法校验通过。
5. **运行态连接快照**：
   - Antigravity 客户端与 `language_server.exe` 运行正常，实测与 `127.0.0.1:65532` 保持活跃 TCP 代理连接。
6. **智能体环境、规则与技能**：
   - 智能体中文交互插件 `chinese-toolkit` 已安装就绪。
   - 全局规则 `AGENTS.md` 已同步权威真源。
   - 权限策略已核准为 `AGENT_PERMISSION_PRESET_AUTO` 与 `CASCADE_COMMANDS_AUTO_EXECUTION_AUTO`。
   - 维护技能 `antigravity-windows-fast-patch` 已成功注册至全局技能库。

---

## 恢复入口与使用方式

- **桌面双击交互入口**：直接双击 `一键检验与修复.bat`。
- **全维只读体检**：`.\Check-And-Fix-Antigravity.ps1 -CheckOnly`
- **一键闭环修复**：`.\Check-And-Fix-Antigravity.ps1 -Fix -CloseProcess -Launch`
- **导出 Agent 提示词**：`.\Check-And-Fix-Antigravity.ps1 -ExportPrompt -CopyToClipboard`
- **注册 Agent 技能**：`.\Check-And-Fix-Antigravity.ps1 -InstallSkill`
- **完整一键维护**：`.\Check-And-Fix-Antigravity.ps1 -FullMaintenance -CloseProcess`
- **一键原子回滚**：`.\Check-And-Fix-Antigravity.ps1 -Rollback -CloseProcess`
- **最近健康报告**：`outputs/health-runs/<run-id>/summary.md` 与 `outputs/latest-run.json`。
