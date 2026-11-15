<div align="center">

<h1>Antigravity Windows 统一环境维护系统 (Agent Fast Patch Suite)</h1>

<p>面向 Google Antigravity (AGY) 客户端的开源全维环境体检、闭环精准修复、动态 Agent 协同与原子回滚套件</p>

<p>
  <img src="https://img.shields.io/badge/Windows-0078D4?style=flat-square" alt="Windows">
  <img src="https://img.shields.io/badge/Antigravity-4285F4?style=flat-square" alt="Antigravity">
  <img src="https://img.shields.io/badge/PowerShell-5391FE?style=flat-square" alt="PowerShell">
  <img src="https://img.shields.io/badge/License-MIT-green?style=flat-square" alt="License">
</p>

<p><strong>中文</strong> &nbsp;/&nbsp; <a href="README.en.md">English</a></p>

<p>
  <a href="#核心能力">核心能力</a> &nbsp;·&nbsp;
  <a href="#使用方法">使用方法</a> &nbsp;·&nbsp;
  <a href="#agent-协作与协同模式">Agent 协作</a> &nbsp;·&nbsp;
  <a href="#开源依赖与上游致谢">开源上游</a> &nbsp;·&nbsp;
  <a href="#安全规范">安全规范</a>
</p>

</div>

---

针对 Google Antigravity 官方客户端频繁更新导致代理 DLL 丢失、快捷方式重置、ASAR 汉化被覆盖及智能体规则漂移等问题，本项目提供了一站式、开箱即用的统一维护解决方案。
支持全自动环境发现、统一协议健康体检、快照安全备份、AST 语法级精准补丁合成、动态 Agent 任务提示词生成与一键原子回滚。

## 核心能力

| 功能维度 | 统一检查项 (ID) | 诊断依据 | 处置策略 |
| --- | --- | --- | --- |
| **客户端核心安装** | `CORE-BIN-01/02/03` | 核验安装目录完整性与程序未篡改 SHA256 | 确保受保护官方程序不被恶意篡改 |
| **网络代理注入** | `PROXY-01/02/03` | 检查 `version.dll` (v2.4) 与 `config.json` | 部署代理注入 DLL，子进程及语言服务器流量导向本地代理端口（默认 `127.0.0.1:65532`） |
| **快捷方式修复** | `SHORTCUT-01/02` | 检查桌面与开始菜单 LNK 启动目标 | 重新定向至 `launch-antigravity-*.vbs`；支持免退客户端的零停机热修复 |
| **宿主界面汉化** | `ASAR-01/02` | 校验 `resources\app.asar` 状态 | 精准增量合成 UI 脚本，通过 AST 语法编译校验，不破坏新版功能 |
| **外置扩展保护** | `ASAR-03` | 检查 `chrome-devtools-mcp` | 严格保留 `{ unpack: '**/chrome-devtools-mcp/**' }` 外置标记，防止插件依赖崩溃 |
| **运行态连接** | `RUNTIME-01/02` | 进程活跃度与 TCP 代理连接快照 | 监测客户端进程与代理端口活跃连接状态 |
| **智能体环境与规则** | `AGENT-01/02/03`, `SKILL-01` | 检查 `chinese-toolkit` 插件与 `AGENTS.md` | 同步中文交互规范、对齐全局规则、核准自动执行策略并自动注册 Agent Skill |

---

## 使用方法

### 1. 双击一键使用 (交互式主控)

直接双击运行根目录下的 **`一键检验与修复.bat`**，进入统一交互控制台：

```text
===================================================================
          Antigravity 统一环境维护系统 (Agent 增强版)
===================================================================

  [1] 一键检查与修复 (自动检测并修复异常项)
  [2] 仅检查环境 (全维只读体检，输出诊断报告)
  [3] 生成 Agent 提示词 (导出接管提示词并可复制到剪贴板)
  [4] 安装或更新 Agent Skill (向 Antigravity 全局注册维护技能)
  [5] 查看诊断报告 (浏览最近一次体检 Markdown 报告)
  [6] 回滚 (安全还原至官方原版 ASAR 与原始快捷方式)
  [0] 退出
===================================================================
```

### 2. 命令行调用 (PowerShell)

脚本支持全参数化静默调用，适合脚本编排或 CI 自动化：

```powershell
# 仅执行全维体检（只读无副作用，输出 summary.json 与 summary.md）
.\Check-And-Fix-Antigravity.ps1 -CheckOnly

# 执行一键闭环修复（自动备份、退出进程、修复异常并在完成后拉起应用）
.\Check-And-Fix-Antigravity.ps1 -Fix -CloseProcess -Launch

# 导出本次体检的 Agent 结构化接管提示词并复制到剪贴板
.\Check-And-Fix-Antigravity.ps1 -ExportPrompt -CopyToClipboard

# 自动安装注册 Agent Skill 到当前用户的 Antigravity 环境
.\Check-And-Fix-Antigravity.ps1 -InstallSkill

# 完整一键维护流程 (体检 -> 修复 -> 复检 -> 技能注册)
.\Check-And-Fix-Antigravity.ps1 -FullMaintenance -CloseProcess

# 一键安全原子回滚至官方纯净原版
.\Check-And-Fix-Antigravity.ps1 -Rollback -CloseProcess
```

---

## Agent 协作与协同模式

系统支持三大轻量化 Agent 协作入口，无需复杂的第三方中间服务：

1. **脚本独立运行**：用户运行脚本自动修复；若遇到复杂冲突或未决异常，脚本自动汇总事实并生成 `agent-prompt.md` 提示词。
2. **脚本移交 Agent**：用户主动生成提示词（选项 `[3]` 或参数 `-ExportPrompt`），一键复制到剪贴板并粘贴到任意 AI 助手（Antigravity、Codex、Claude Code 等）中接管排查。
3. **Agent 自主运行**：用户直接向支持本地命令调用的 AI 助手发送指令：
   ```text
   使用 antigravity-windows-fast-patch，体检当前 Antigravity 状态，若有更新导致的异常先做备份再修复。
   ```
   智能体将依照项目自带的 `SKILL.md` 规范，自主调用现有脚本完成闭环。

---

## 目录结构

```text
D:\Agent\Antigravity\环境修复\
├── 01_PROJECT.md                # 项目目标、范围与真源规范
├── 02_STATUS.md                 # 唯一当前状态真源 (单源事实)
├── 03_HISTORY.md                # 演进历史与操作留痕
├── 04_FILE_INDEX.md             # 限定范围内的完整文件索引
├── AGENTS.md                    # 本项目专用规则与防篡改门禁
├── SKILL.md                     # Agent Skill 规范入口
├── 一键检验与修复.bat            # 便捷双击入口 (防闪退)
├── Check-And-Fix-Antigravity.ps1# 统一主控调度脚本
├── agent-prompt.md              # 动态生成的 Agent 任务提示词
├── templates/                   # 提示词模板 (agent-prompt.md)
├── tools/                       # 核心维护工具集
│   ├── EnvironmentDiscovery.ps1 # 全维环境自适应发现引擎
│   ├── Check-Antigravity.ps1    # 统一协议只读健康体检
│   ├── Fix-Antigravity.ps1      # 快照备份与闭环修复引擎
│   ├── Rollback-Antigravity.ps1 # 官方原版原子回滚脚本
│   ├── Export-AgentPrompt.ps1   # 动态提示词生成器
│   ├── Install-AgentSkill.ps1   # Skill 自动部署与注册器
│   └── patch-asar.cjs           # Node.js ASAR 精准打包与 AST 校验引擎
├── payload/                     # 自包含交付载荷 (proxy, localization, plugins)
├── references/                  # 技术实现与排错专题文档
└── outputs/                     # 历史报告、交接凭据与状态快照备份
    ├── environment.json         # 动态环境发现快照
    ├── latest-run.json          # 最近一次体检结构化数据
    └── health-runs/<run-id>/    # 各次运行的 summary.json, summary.md 与 prompt
```

---

## 开源依赖与上游致谢

本项目由社区共同构建，核心架构与关键能力得益于以下优秀开源项目的贡献与启发：

1. **网络代理注入组件 (version.dll 与子进程流量路由)**：
   - 上游仓库：[yuaotian/antigravity-proxy](https://github.com/yuaotian/antigravity-proxy)
   - 感谢 `yuaotian` 提供的 Windows Winsock DLL 注入方案与本地 HTTP 代理路由配置。
2. **Windows 自动化维护工作流与 Agent 技能架构范式**：
   - 上游仓库：[chen0416ccc-cpu/codex-windows-fast-patch-skill](https://github.com/chen0416ccc-cpu/codex-windows-fast-patch-skill)
   - 感谢 `chen0416ccc-cpu` 在自动化体检、快照安全修复、零停机热修复机制以及标准 Agent Skill 工作流设计上带来的开创性启发。
3. **ASAR 资源打包与解包引擎**：
   - 基于官方 `@electron/asar` 库封装，保障了资源注入与外置目录结构保护的可靠性。

---

## 安全规范与核心文件防篡改

- **受保护二进制防篡改**：`Antigravity.exe` 与 `resources\bin\language_server.exe` 属于受保护的官方核心二进制程序。本项目在所有修复与回滚操作前后均强制核验其 SHA256 哈希，绝不修改、覆盖或篡改任何官方主程序二进制。
- **快照优先**：任何对 ASAR 资源或快捷方式的改动，均会在 `outputs/` 下自动建立时间戳快照并保留原版备份。
- **隐私合规**：环境发现与诊断提示词生成绝不包含用户密码、Cookie、Token 或任何隐私会话数据。

---

## 开源协议

本项目采用 [MIT License](LICENSE) 授权。
