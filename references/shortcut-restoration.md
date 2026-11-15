# 快捷方式修复与零停机热修复机制

## 1. 快捷方式丢失根因

当 Antigravity 完成自动静默更新或用户手动安装官方更新包时，安装器会默认重建桌面与开始菜单快捷方式，将其直接指向原版可执行文件 `Antigravity.exe`。
这导致用户通过快捷方式双击打开客户端时，绕过了 `launch-antigravity-65532.vbs` 启动脚本，引发代理环境变量缺失。

## 2. 目标重定向

修复逻辑通过 COM 组件 `WScript.Shell` 读取桌面与开始菜单中的快捷方式：
- 目标路径重定向为：`C:\Windows\System32\wscript.exe`
- 运行参数配置为：`"C:\Users\123\AppData\Local\Programs\antigravity\launch-antigravity-65532.vbs"`
- 图标路径保持为：`C:\Users\123\AppData\Local\Programs\antigravity\Antigravity.exe,0`

## 3. 零停机热修复 (Zero-Downtime Fix)

在日常使用中，若客户端正在运行且核心程序文件（`app.asar`、`version.dll` 等）均处于就绪状态，仅快捷方式被系统重置时：
- `Fix-Antigravity.ps1` 智能识别出不需要修改程序文件；
- 脚本跳过进程关闭逻辑，在客户端正常工作的同时静默完成快捷方式更新，保障工作流连续性。
