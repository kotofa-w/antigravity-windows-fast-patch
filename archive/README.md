# Antigravity 补丁一键检验与修复套件 (独立产物包)

这是一个完全自包含、可独立分发的 Antigravity 环境维护套件。所有必需的代理交付二进制、配置文件、启动器、汉化词典及离线 Node.js 打包依赖均已完整封装在 `payload/` 目录内，不再依赖任何外部历史临时路径。

---

## 目录结构

```text
antigravity-patch-toolkit/
├── 一键检验与修复.bat                # [推荐] 双击一键运行入口（防闪退）
├── Check-And-Fix-Antigravity.ps1     # 主控 PowerShell 脚本（支持参数与交互）
├── manifest.json                     # 产物元数据清册与交付文件哈希
├── README.md                         # 本技术与操作指南
├── tools/                            # 模块化核心逻辑
│   ├── Check-Antigravity.ps1         # 全维只读健康体检
│   ├── Fix-Antigravity.ps1           # 自动快照备份与闭环修复
│   ├── Rollback-Antigravity.ps1      # 原版 ASAR 与快捷方式安全回滚
│   └── patch-asar.cjs                # Node.js ASAR 精准合成与结构校验引擎
└── payload/                          # 内置自包含资源库
    ├── proxy/                        # 代理 v2.4 交付三件套 (version.dll, config.json, vbs)
    └── localization/                 # 汉化引擎与全量离线依赖 (@electron/asar 等)
```

---

## 使用方式

### 1. 双击一键使用（推荐）
直接双击运行 `一键检验与修复.bat`：
- 脚本自动执行体检；
- 全绿时直接提示健康并显示活跃连接；
- 发现异常时列出待修复项，并提示选择一键修复。

### 2. 命令行调用（PowerShell）
```powershell
# 仅执行全维体检（只读无副作用）
.\Check-And-Fix-Antigravity.ps1 -CheckOnly

# 自动修复异常项并拉起应用（遇进程占用自动安全退出）
.\Check-And-Fix-Antigravity.ps1 -Fix -CloseProcess -Launch

# 一键安全回滚至官方纯净原版（卸载汉化）
.\Check-And-Fix-Antigravity.ps1 -Rollback -CloseProcess
```

---

## 核心技术机制

1. **零外部散落依赖**：
   - 代理 DLL、HTTP 65532 配置、VBS 启动器均内置于 `payload/proxy/`。
   - 汉化工具与 `@electron/asar` 均内置于 `payload/localization/`，无需联网重新安装 npm 模块。
2. **自动备份快照机制**：
   - 执行任何修复前，自动在产物包内的 `backups/backup-<timestamp>/` 目录创建完整快照，包含当前 `app.asar`、桌面与开始菜单快捷方式副本以及 `before.json` 哈希清册。
3. **零停机动态修复**：
   - 当仅快捷方式异常（如原生更新重置了入口）且程序文件完好时，修复逻辑仅更新快捷方式，不强行关闭正在工作的 Antigravity 客户端。
4. **ASAR 结构保护与语法验证**：
   - 提取汉化脚本后通过 `new vm.Script()` 语法编译校验；
   - 严格继承 `{ unpack: '**/chrome-devtools-mcp/**' }` 外置打包规则；
   - 校验生成包条目数与 unpacked 外置标志一致性，避免旧汉化工具损坏新版外置资源。
5. **受保护二进制防篡改核验**：
   - 修复前后强制复核 `Antigravity.exe` 与 `resources\bin\language_server.exe` SHA256 哈希，确保核心二进制完整无损。
