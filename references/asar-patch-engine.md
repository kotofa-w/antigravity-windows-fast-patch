# ASAR 汉化合成与结构保护引擎

## 1. 核心挑战与设计背景

Antigravity 客户端（Electron 架构）在版本升级（例如 2.32.1）后，官方会自动覆盖 `resources\app.asar`，导致界面恢复为默认英文。如果简单使用旧版汉化工具做全量解包与重新覆盖，会引入严重回归：
1. **外置依赖损坏**：新版 ASAR 引入了外置解包扩展（如 `app.asar.unpacked\node_modules\chrome-devtools-mcp`）。若打包时不保留精确的 `{ unpack: '**/chrome-devtools-mcp/**' }` 外置标记，将导致 MCP 扩展启动时找不到依赖而崩溃。
2. **新版前端脚本破坏**：官方每次更新可能会修改渲染主进程及扩展视图脚本。全量覆盖旧版 `dist` 脚本会导致新功能异常甚至白屏。

## 2. 精准合成机制 (`tools/patch-asar.cjs`)

本项目采用最小侵入式的增量合成与校验机制：
1. **隔离解包**：在隔离临时目录中解包官方最新版 `app.asar` 与汉化应用产物。
2. **差异过滤**：比对官方原版与汉化版本的脚本差异，仅挑选受影响的 8 个核心 UI 脚本进行替换。
3. **AST 语法编译校验**：在重新打包前，对每一个拟写入的 JavaScript 脚本调用 Node.js 原生 `vm.Script` 编译解析：
   ```javascript
   new vm.Script(code, { filename: scriptPath });
   ```
   若存在语法错误或非法字符，立即阻断打包并抛出异常，杜绝损坏脚本落盘。
4. **严格继承解包规则**：
   重新打包时，调用 `@electron/asar` 并强制传入：
   ```javascript
   await asar.createPackageWithOptions(unpackedDir, targetAsarPath, {
     unpack: '**/chrome-devtools-mcp/**'
   });
   ```
5. **双向条目数与哈希复核**：
   打包完成后，比对新旧 ASAR 内部的目录条目数及文件索引，确保 1208 个资源条目完好无损。
