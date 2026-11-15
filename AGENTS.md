# Antigravity 环境修复项目规则

版本：2026-11-15

本项目维护 Windows Google Antigravity 环境诊断、官方更新后补丁恢复、代理注入、宿主汉化保护、快捷方式修复及验收证据。初始化依据：用户要求针对该项目复刻适用于反重力的独立管理版本。

- 会话首次读取 `01_PROJECT.md`、`02_STATUS.md`；当前状态仅维护在 `02_STATUS.md`。历史查 `03_HISTORY.md`，路径查 `04_FILE_INDEX.md`。
- 本机核心应用安装于 `C:\Users\123\AppData\Local\Programs\antigravity`，智能体配置位于 `C:\Users\123\.gemini\config`。本项目为独立工程维护根目录，严禁在未做快照备份前直接覆盖核心程序或用户配置。
- `tools/Check-Antigravity.ps1` 为全维只读健康体检脚本，执行只读检查不修改任何文件，优先使用其获取事实证据。
- 修复操作必须使用具备安全备份机制的工具（如 `Check-And-Fix-Antigravity.ps1` 或 `tools/Fix-Antigravity.ps1`）。在修改 `app.asar`、代理 DLL 或快捷方式前，必须在 `outputs/` 或备份目录中完成状态快照与原始文件哈希锁定。
- 必须严格遵守核心二进制防篡改要求：`Antigravity.exe` 与 `resources\bin\language_server.exe` 属于受保护核心二进制，修复前后必须核验 SHA256，严禁篡改或覆盖。
- 汉化补丁合成必须维持 ASAR 外置结构一致性（保留 `{ unpack: '**/chrome-devtools-mcp/**' }` 外置标志），并在落盘前完成脚本语法编译校验，禁止盲目全量覆盖损坏新版本扩展。
- 代理组件维护：依赖代理端口 `127.0.0.1:65532`，核心交付为 `version.dll` (v2.4)、`config.json` 及 `launch-antigravity-65532.vbs`。
- 回滚操作使用 `tools/Rollback-Antigravity.ps1`，仅允许将对应版本的原版备份安全还原，禁止跨版本套用旧版 ASAR。
- 不因项目初始化自动关闭正在运行的应用或无故重复部署。
