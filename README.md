<div align="center">

<h1>Antigravity Windows Fast Patch Skill</h1>

<p>为 AI 智能体设计的 Google Antigravity (AGY) 客户端更新后环境体检、代理注入与汉化保护套件</p>

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
  <a href="#架构机制">架构机制</a> &nbsp;·&nbsp;
  <a href="#技术参考">技术参考</a>
</p>

</div>

---

这是为 Google Antigravity 客户端打造的社区 Agent Skill 与独立维护套件。针对官方更新后频繁出现的代理丢失、快捷方式被重置、ASAR 汉化被覆盖等问题，提供全自动只读体检、快照安全备份、AST 语法级精准补丁合成与一键原子回滚能力。

## 核心能力

| 功能维度 | 诊断依据 | 处置策略 |
| --- | --- | --- |
| **网络代理注入** | 检查 `version.dll` 与 `config.json` | 部署 v2.4 劫持 DLL，将进程及语言服务器流量导向 `127.0.0.1:65532` |
| **快捷方式修复** | 检查桌面与开始菜单 LNK 指向 | 重新定向至 `launch-antigravity-65532.vbs`；支持零停机热修复 |
| **宿主界面汉化** | 校验 `resources\app.asar` 状态 | 增量合成 8 个 UI 脚本，通过 AST 语法编译校验，继承外置解包标记 |
| **外置扩展保护** | 检查 `chrome-devtools-mcp` | 严格保留 `{ unpack: '**/chrome-devtools-mcp/**' }` 外置标记，防止插件崩溃 |
| **核心二进制防篡改** | 核验 `Antigravity.exe` SHA256 | 操作前后强制复核官方核心程序哈希，杜绝未授权破坏 |

## 使用方法

### 1. 双击一键使用 (推荐)
直接双击根目录下的 **`一键检验与修复.bat`**：
- 自动执行 6 大核心维度健康体检；
- 全绿时直接提示健康并显示活跃代理连接；
- 发现异常时列出待修复项，并提示选择一键修复。

### 2. 命令行调用 (PowerShell)
```powershell
# 仅执行全维体检（只读无副作用）
.\Check-And-Fix-Antigravity.ps1 -CheckOnly

# 自动修复异常项并在完成后拉起应用
.\Check-And-Fix-Antigravity.ps1 -Fix -CloseProcess -Launch

# 一键安全回滚至官方纯净原版（卸载汉化）
.\Check-And-Fix-Antigravity.ps1 -Rollback -CloseProcess
```

### 3. 作为 Agent Skill 使用
在 Antigravity、Codex 或 Claude Code 中直接向 AI 助手描述：
```text
使用 antigravity-windows-fast-patch，体检当前 Antigravity 状态，
若有更新导致的代理或汉化失效，先做备份再修复。
```

## 目录结构

```text
D:\Agent\Antigravity\环境修复\
├── 01_PROJECT.md                # 项目目标、范围与真源规范
├── 02_STATUS.md                 # 唯一当前状态真源 (单源事实)
├── 03_HISTORY.md                # 演进历史与操作留痕
├── 04_FILE_INDEX.md             # 限定范围内的完整文件索引
├── AGENTS.md                    # 本项目专用规则
├── SKILL.md                     # Agent Skill 规范入口
├── 一键检验与修复.bat            # 便捷双击入口 (防闪退)
├── Check-And-Fix-Antigravity.ps1# 主控自动化脚本
├── tools/                       # 核心维护工具 (体检、修复、回滚、ASAR 引擎)
├── payload/                     # 自包含交付载荷 (proxy, localization, plugins)
├── references/                  # 技术实现与排错专题文档
└── outputs/                     # 历史报告、交接凭据与状态快照备份
```

## 技术参考

- [ASAR 汉化合成与结构保护引擎](references/asar-patch-engine.md)
- [代理 DLL 劫持与流量路由机制](references/proxy-dll-injection.md)
- [快捷方式修复与零停机热修复机制](references/shortcut-restoration.md)

## 开源协议

本项目采用 [MIT License](LICENSE) 授权。
