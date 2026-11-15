# Antigravity 环境修复

本项目用于维护本机 Windows Google Antigravity (AGY) 客户端更新后的网络代理、宿主汉化补丁、启动器快捷方式、智能体交互套件及相关补丁恢复。目标是在官方版本频繁更新覆盖后，实现一键安全体检、带快照备份的精准闭环修复、结构保护与原子回滚，并完整保存可追溯证据。

## 验收标准

- 修复依据当前 Antigravity 实际版本、manifest、resources 目录结构及真实错误，不套用旧版本不兼容资源。
- 写入前必须自动创建完整状态快照（包含原版 `app.asar`、快捷方式副本及 `before.json`），修复后通过受保护二进制防篡改核验。
- 代理补丁交付包含 DLL 注入（`version.dll` v2.4）、HTTP 65532 代理配置及启动脚本，桌面与开始菜单快捷方式稳定指向 VBS 启动器。
- 汉化合成保持 ASAR 外置解包规则（如 `chrome-devtools-mcp`），汉化脚本经 AST 语法编译校验通过，不损坏新版功能扩展。
- 修复工具完全自包含，核心依赖与载荷全部内置于本项目，脱离外部散落目录依赖。
- 后续会话通过本文件与 `02_STATUS.md` 即可确定当前健康状态、基线证据与下一步行动。

## 目录与职责

| 路径 | 用途 |
| --- | --- |
| `一键检验与修复.bat` | 双击运行的一键体验与交互式修复入口（带防闪退机制） |
| `Check-And-Fix-Antigravity.ps1` | 主控自动化 PowerShell 脚本，支持 `-CheckOnly`、`-Fix`、`-Rollback` 等无缝调用 |
| `tools/Check-Antigravity.ps1` | 全维只读健康体检脚本，输出 6 大维度状态快照及异常清册 |
| `tools/Fix-Antigravity.ps1` | 自动快照备份、零停机快捷方式更新、安全关进程与闭环精准修复引擎 |
| `tools/Rollback-Antigravity.ps1` | 官方原生纯净原版一键原子还原脚本 |
| `tools/patch-asar.cjs` | Node.js ASAR 资源精准解包、补丁合并与打包校验引擎 |
| `payload/proxy/` | 代理 v2.4 交付三件套（`version.dll`, `config.json`, `launch-antigravity-65532.vbs`） |
| `payload/localization/` | 汉化离线运行时引擎、词典与全量离线 node_modules 依赖 |
| `payload/plugins/` | 智能体配套插件（如 `chinese-toolkit`）交付载荷 |
| `outputs/` | 历史与当前版本的修复验收报告、交接记录、部署凭据与状态快照备份 |
| `archive/` | 历史工具元数据清单与套件使用指南归档 |

## 真源和边界

本项目根目录为 `D:/Agent/Antigravity/环境修复`；唯一当前状态为 `02_STATUS.md`。应用真实安装目录位于 `C:\Users\123\AppData\Local\Programs\antigravity`，智能体配置位于 `C:\Users\123\.gemini\config`。本项目内部维护工具与交付载荷，不复制用户隐私会话与账号凭据。

原维护资料从 `C:\Users\123\Documents\Codex\2026-11-11\fang` 迁入并实现了路径自包含重构，消除了外部散落路径依赖。
本项目的操作严格受 `AGENTS.md` 约束，任何对核心程序的写操作必须遵守先备份、后修改、再复核的原子闭环原则。
