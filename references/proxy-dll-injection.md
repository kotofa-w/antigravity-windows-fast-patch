# 代理 DLL 劫持与子进程流量路由机制

## 1. 架构定位

Google Antigravity 客户端在特定网络环境下，主进程与语言服务器（`language_server.exe`）需要无感通过本地 HTTP 代理通信。本项目交付的代理套件基于 `yuaotian/antigravity-proxy` v2.4 编译产物，配合 VBS 进程环境注入。

## 2. 劫持与通信组件

- `version.dll` (SHA256: `40F037232A180DA8DFF7611021270549FCC4E208580D8BF0F70BC9975F871B5F`)：
  - 利用 Windows 动态链接库搜索顺序，将自定义 `version.dll` 放置在 `Antigravity.exe` 同级目录下。
  - 应用启动时，操作系统优先加载该 DLL，实现对 Winsock API 的钩子拦截。
- `config.json`：
  - 指定代理模式为 HTTP，目标地址为 `127.0.0.1:65532`。
  - 启用 `child_injection: true`，拦截目标包含 `agy.exe`, `language_server.exe`, `node.exe` 等子进程，确保全链路通信均能被代理感知。
- `launch-antigravity-65532.vbs`：
  - 通过 WScript.Shell 为启动进程显式注入环境变量：
    - `HTTP_PROXY = http://127.0.0.1:65532`
    - `HTTPS_PROXY = http://127.0.0.1:65532`
    - `ALL_PROXY = http://127.0.0.1:65532`
    - `NO_PROXY = localhost,127.0.0.1,::1`
  - 并向 `Antigravity.exe` 传递启动参数 `--proxy-server=http://127.0.0.1:65532`。

## 3. 防篡改核验要求

代理劫持不直接修改任何客户端既有二进制。修复前后必须严格比对 `Antigravity.exe` 与 `resources\bin\language_server.exe` 的原始 SHA256，严禁替换或二次篡改官方官方二进制。
