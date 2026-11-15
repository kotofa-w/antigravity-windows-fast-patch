# 重要历史

## 2026-11-15 对照原技能仓库完成全套技能架构复刻

用户提供原项目仓库 `https://github.com/chen0416ccc-cpu/codex-windows-fast-patch-skill`，要求继续未完成部分。

1. **技能规范确立与对齐**：
   - 依照原仓库针对 Codex 设计的 `SKILL.md` 架构，为 Antigravity 客户端编写了标准 Agent 技能定义文件 `SKILL.md`（定义 `antigravity-windows-fast-patch` 技能元数据、触发模式、前置只读体检、快照安全修复及原子回滚 3 大标准工作流）。
2. **开源文档与技术参考专题**：
   - 编写中英文双语 `README.md` 与 `README.en.md`。
   - 编写安全防篡改策略声明 `SECURITY.md`，明确受保护二进制防篡改要求。
   - 搭建 `references/` 专题文档体系：[ASAR 汉化精准合成与结构保护](references/asar-patch-engine.md)、[代理 DLL 注入与流量路由机制](references/proxy-dll-injection.md)、[快捷方式修复与零停机热修复](references/shortcut-restoration.md)。
3. **本地版本控制基线建立**：
   - 编写 `.gitignore` 与 `.gitattributes`，完成本地 Git 仓库初始化（`git init -b main`），将项目全部核心组件纳入版本控制。

---

## 2026-11-15 本项目独立初始化与全维健康体检闭环

用户要求“针对该项目，复刻一个适用于反重力的版本”，并指示“先初始化本项目”。工作区位于 `D:\Agent\Antigravity\环境修复`。

1. **项目规范化搭建**：
   - 依照用户全局协作规范，初始化建立核心真源管理体系：`01_PROJECT.md`、`02_STATUS.md`、`03_HISTORY.md`、`04_FILE_INDEX.md` 及本项目专用规则 `AGENTS.md`。
   - 确立以 `02_STATUS.md` 为唯一状态真源，受保护核心二进制防篡改核验机制，以及写入前必须自动快照备份的安全边界。
2. **工具链与交付载荷自包含重构**：
   - 将原存放于外部的历史独立维护套件（`antigravity-patch-toolkit`）及 2026-11-15、2026-11-11 的验收证据平稳迁入本项目。
   - 优化修复与回滚脚本（`Fix-Antigravity.ps1`、`Rollback-Antigravity.ps1`），加入内置自包含路径优先探测逻辑：优先直接使用本项目的 `payload/proxy/`、`payload/localization/` 及 `outputs/`，消除了对外部散落绝对路径的强依赖，实现了真正开箱即用的跨环境独立维护。
3. **只读健康体检实测闭环**：
   - 运行 `tools/Check-Antigravity.ps1`，对当前已安装的 Antigravity 2.32.1 执行全维无副作用健康体检。
   - 实测 6 大核心维度（安装与受保护二进制、代理 v2.4 补丁、启动器快捷方式、ASAR 汉化补丁结构与语法、运行态进程与 41 个 65532 代理 TCP 连接、智能体环境与规则配置）全部 PASS，状态确认为 Healthy。

---

## 2026-11-15 官方 2.32.1 更新后的汉化与代理补丁闭环恢复

1. **更新后症状诊断**：
   - Antigravity 静默更新至 2.32.1 后，代理 DLL（`version.dll`）、`config.json` 及启动器丢失，桌面和开始菜单快捷方式被重置回直接启动原版可执行文件；`app.asar` 汉化补丁被官方原版包覆盖。
2. **闭环修复与结构保护**：
   - 先对 2.32.1 官方纯净原版 `app.asar` 及快捷方式进行快照备份（`outputs/antigravity-20261115/backup/`）。
   - 为避免旧汉化工具全量重新解包破坏新版外置扩展资源，采用精准合成策略：在隔离副本中应用汉化后，仅提取改变的 8 个 `dist` 脚本，并按原始 `{ unpack: '**/chrome-devtools-mcp/**' }` 规则重新打包。
   - 校验 1208 个资源条目及 347 个外置文件布局一致性，通过 AST 语法编译校验。
   - 部署前后核对 `Antigravity.exe` 与 `resources\bin\language_server.exe` 哈希未发生篡改。
3. **运行态验收与交付**：
   - 语言服务器成功初始化，建立与 `127.0.0.1:65532` 的 TCP 代理连接。形成交付说明 `outputs/antigravity-20261115/交接说明.md`。

---

## 2026-11-11 Antigravity 自动化维护套件封装与模块化重构

1. **背景与痛点**：
   - 历史恢复依赖多处散落的下载目录、临时工作区及命令行手动步骤，每次官方更新后恢复成本高、易漏步或破坏外置依赖。
2. **重构交付**：
   - 设计并实现模块化脚本体系：`Check-Antigravity.ps1`（只读体检）、`Fix-Antigravity.ps1`（快照备份与修复）、`Rollback-Antigravity.ps1`（一键还原）及 `patch-asar.cjs`（Node 打包校验引擎）。
   - 封装 `一键检验与修复.bat` 提供双击交互式入口。
   - 内置零停机快捷方式修复逻辑，当仅快捷方式重置而程序文件完好时，无需强行关闭正在工作的客户端。

---

## 2026-10-14 初始代理注入与 65532 端口路由引入

1. **技术方案确立**：
   - 采用 `yuaotian/antigravity-proxy` v2.4 的 DLL 注入机制（`version.dll`），通过拦截 Windows Winsock 与网络连接，将 Antigravity 前端、后端及子进程（`agy.exe`, `language_server.exe` 等）流量无感路由至本地代理端口 `127.0.0.1:65532`。
   - 配套生成 `config.json` 规则并编写 `launch-antigravity-65532.vbs` 启动脚本，解决特定网络环境下的连接受阻问题。
