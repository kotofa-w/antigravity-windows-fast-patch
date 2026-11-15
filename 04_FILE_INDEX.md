# 文件索引

初始化日期：2026-11-15（Asia/Hong_Kong）。根目录：`D:\Agent\Antigravity\环境修复`。

当前结论与状态以 `02_STATUS.md` 为唯一真源，最新交接报告为 `outputs/antigravity-20261115/交接说明.md`。
本项目采用自包含设计，所有代理组件、汉化离线运行时及离线依赖已内置于 `payload/`，脚本引擎维护于 `tools/`。

扫描范围：排除 `payload/localization/node_modules/` 细粒度三方包及任何临时缓存，纳入核心文档、自动化脚本、交付载荷、验收报告与备份快照。

| 相对路径 | 类型 | 职责说明 |
| --- | --- | --- |
| `01_PROJECT.md` | .md | 项目目标、验收标准、目录职责与真源边界 |
| `02_STATUS.md` | .md | 项目唯一当前状态真源（包含当前版本、健康快照、恢复入口与后续边界） |
| `03_HISTORY.md` | .md | 重要历史演进、失败留痕、反思与关键版本节点 |
| `04_FILE_INDEX.md` | .md | 限定范围内的项目完整文件索引清单 |
| `AGENTS.md` | .md | 本项目专用规则（真源读取、受保护二进制防篡改、快照备份门禁） |
| `SKILL.md` | .md | Agent Skill 规范入口（声明自适应体检、安全修复、提示词协同与回滚工作流） |
| `README.md` | .md | 项目开源说明文档（中文版，含开源上游致谢与使用说明） |
| `README.en.md` | .md | 项目开源说明文档（英文版） |
| `SECURITY.md` | .md | 安全策略与受保护二进制防篡改规范说明 |
| `.gitignore` | 配置 | Git 忽略规则 |
| `.gitattributes` | 配置 | Git 换行符与二进制文件属性配置 |
| `references/asar-patch-engine.md` | .md | ASAR 汉化精准合成与结构保护技术专题 |
| `references/proxy-dll-injection.md` | .md | 代理 DLL 劫持与子进程流量路由机制专题 |
| `references/shortcut-restoration.md` | .md | 快捷方式修复与零停机热修复机制专题 |
| `一键检验与修复.bat` | .bat | 双击运行的一键体验与交互式控制台入口（带防闪退机制） |
| `Check-And-Fix-Antigravity.ps1` | .ps1 | 主控自动化调度脚本，支持 6 大模式与全参数化调用 |
| `run-check-and-fix.bat` | .bat | 命令行批处理调度入口 |
| `agent-prompt.md` | .md | 最近动态生成的 Agent 任务接管提示词 |
| `templates/agent-prompt.md` | .md | Agent 接管提示词标准化模板 |
| `tools/EnvironmentDiscovery.ps1` | .ps1 | 全维环境自动发现与配置管理引擎（消除硬编码） |
| `tools/Check-Antigravity.ps1` | .ps1 | 统一协议只读健康体检脚本（17 项检查点与结构化输出） |
| `tools/Fix-Antigravity.ps1` | .ps1 | 自动快照备份、零停机快捷方式更新、安全关进程与闭环修复引擎 |
| `tools/Rollback-Antigravity.ps1` | .ps1 | 官方原生纯净原版一键原子还原脚本 |
| `tools/Export-AgentPrompt.ps1` | .ps1 | 动态 Agent 接管提示词生成器（支持剪贴板托管复制） |
| `tools/Install-AgentSkill.ps1` | .ps1 | Agent Skill 自动安装与全局注册器 |
| `tools/patch-asar.cjs` | .cjs | Node.js ASAR 资源精准解包、补丁合并与打包校验引擎 |
| `payload/proxy/version.dll` | .dll | 代理注入核心动态链接库 (v2.4，源自 yuaotian/antigravity-proxy) |
| `payload/proxy/config.json` | .json | 代理路由与端口配置文件 (127.0.0.1:65532) |
| `payload/proxy/launch-antigravity-65532.vbs` | .vbs | VBS 启动脚本（设置进程环境代理并传参启动） |
| `payload/localization/cli.js` | .js | 汉化补丁打包与注入引擎入口 |
| `payload/localization/package.json` | .json | 汉化引擎项目配置 |
| `payload/localization/core/` | 目录 | 汉化核心逻辑模块（运行时注入、CDP 客户端、VSCode 补丁） |
| `payload/localization/dict/` | 目录 | 汉化词典源数据与中英映射表 |
| `payload/localization/node_modules/` | 目录 | 离线预编译依赖库（包含 `@electron/asar` 等） |
| `payload/plugins/chinese-toolkit/` | 目录 | 智能体中文交互配套插件与技能资产 |
| `outputs/environment.json` | .json | 动态环境自动发现事实快照 |
| `outputs/latest-run.json` | .json | 最近一次体检结构化数据软链/快照 |
| `outputs/health-runs/` | 目录 | 历次体检的 summary.json、summary.md 与 agent-prompt.md |
| `outputs/antigravity-20261115/交接说明.md` | .md | 2026-11-15 Antigravity 2.32.1 修复恢复部署交接凭据 |
| `outputs/antigravity-20261115/deployment.json` | .json | 2026-11-15 部署事务记录与时间戳凭据 |
| `outputs/antigravity-20261115/asar-validation.json` | .json | 2026-11-15 ASAR 资源结构与语法校验记录 |
| `outputs/antigravity-20261115/backup/app.asar` | .asar | 2026-11-15 官方 2.32.1 原版 ASAR 资源快照备份 |
| `outputs/antigravity-20261115/backup/before.json` | .json | 2026-11-15 修复前原始文件与快捷方式哈希基线 |
| `outputs/antigravity-20261115/backup/shortcut-*.lnk` | .lnk | 2026-11-15 修复前快捷方式原始备份 |
| `outputs/antigravity-20261111/修复记录.md` | .md | 2026-11-11 历史维护套件封装与修复记录 |
| `outputs/antigravity-20261111/deployment.json` | .json | 2026-11-11 部署凭据 |
| `outputs/antigravity-20261111/asar-validation.json` | .json | 2026-11-11 ASAR 校验凭据 |
| `archive/manifest.json` | .json | 独立套件元数据清单与组件哈希记录 |
| `archive/README.md` | .md | 独立维护套件原说明文档与操作指南归档 |
