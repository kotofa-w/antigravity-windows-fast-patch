# Antigravity 环境维护与修复任务书 (Agent 专用)

## 0. 任务概览与上下文

你现在是接入本机 Antigravity 环境维护系统的专业运维/开发 Agent。
本机维护工具在自动执行环境体检或修复过程中，检测到了需要 Agent 介入分析、修复或确认的问题。

- **项目根目录**：`{{PROJECT_ROOT}}`
- **运行 ID (RunId)**：`{{RUN_ID}}`
- **诊断时间**：`{{CHECK_TIME}}`
- **诊断状态**：`{{STATUS}}`
- **诊断报告文件**：`{{SUMMARY_MD_PATH}}`
- **结构化数据**：`{{SUMMARY_JSON_PATH}}`

---

## 1. 当前环境特征

| 检查维度 | 检测事实 | 目标状态 |
| --- | --- | --- |
| **客户端版本** | `{{AG_VERSION}}` (`{{AG_APP_DIR}}`) | 已安装且版本受控 |
| **受保护核心程序** | `{{AG_CORE_STATUS}}` | `Antigravity.exe` 与 `language_server.exe` 完整且未被非法篡改 |
| **代理注入 (v2.4)** | `{{PROXY_STATUS}}` (`{{PROXY_TARGET}}`) | `version.dll` 就绪，`config.json` 指向代理端口 |
| **快捷方式启动器** | `{{SHORTCUT_STATUS}}` | 快捷方式指向 `launch-antigravity-*.vbs` 代理启动脚本 |
| **宿主汉化补丁** | `{{LOCALIZATION_STATUS}}` | `app.asar` 正确注入，保持 `chrome-devtools-mcp` 外置解包结构 |
| **运行态连接** | `{{RUNTIME_STATUS}}` | 进程正常，保持代理端口 TCP 活跃连接 |
| **智能体规则与插件** | `{{AGENT_STATUS}}` | `AGENTS.md` 全局规则同步，`chinese-toolkit` 就绪，策略为 `AGENT_PERMISSION_PRESET_AUTO` |

---

## 2. 检测到的异常与待处理问题 (Issues)

{{ISSUES_LIST}}

---

## 3. 已尝试的修复与操作记录

{{ACTIONS_TAKEN}}

---

## 4. Agent 核心工作准则与安全红线

1. **核心二进制防篡改**：`Antigravity.exe` 与 `resources\bin\language_server.exe` 属于受保护核心二进制，严禁篡改或覆盖，修复前后必须核验 SHA256。
2. **前置快照备份**：对 `app.asar`、代理 DLL 或快捷方式进行写操作前，必须自动保留快照备份。
3. **ASAR 结构保护**：汉化合成必须严格维持 `{ unpack: '**/chrome-devtools-mcp/**' }` 外置标记，禁止损坏新版扩展依赖。
4. **优先复用现有工具**：优先调用项目已有脚本（`tools/Check-Antigravity.ps1`、`tools/Fix-Antigravity.ps1`、`tools/Rollback-Antigravity.ps1`），不得重复造轮子。
5. **闭环验证**：完成修改后必须重新运行健康检查脚本进行复验，确认问题彻底解决。

---

## 5. 建议执行的工作流与指令

### 步骤 A：读取当前状态真源与最新诊断
```powershell
# 1. 检查最新健康报告
Get-Content -LiteralPath "{{SUMMARY_MD_PATH}}" -Raw

# 2. 读取项目状态真源
Get-Content -LiteralPath "{{PROJECT_ROOT}}\02_STATUS.md" -Raw
```

### 步骤 B：使用自包含工具执行针对性修复
```powershell
# 若代理或快捷方式异常，执行安全修复（不关进程热修复）：
powershell.exe -ExecutionPolicy Bypass -File "{{PROJECT_ROOT}}\tools\Fix-Antigravity.ps1"

# 若需要完整重装汉化或更新补丁（需退出客户端）：
powershell.exe -ExecutionPolicy Bypass -File "{{PROJECT_ROOT}}\tools\Fix-Antigravity.ps1" -CloseRunningProcess -LaunchAfterFix
```

### 步骤 C：执行复检与状态落盘
```powershell
powershell.exe -ExecutionPolicy Bypass -File "{{PROJECT_ROOT}}\tools\Check-Antigravity.ps1"
```

请根据上述异常事实开始排查并实施修复，完成验证后向用户汇报处理结果。
