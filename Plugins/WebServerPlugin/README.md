# 🌐 WebServerPlugin

本地 Web 服务插件，在内核中注册 `WebServerProviding` 实现，启动一个仅监听 `127.0.0.1` 的 HTTP 服务，聚合所有插件通过 `webRoutes(kernel:)` 贡献的路由。

## 功能

- **本地 HTTP 服务** — 监听 `127.0.0.1:7310`，使插件能力可通过 HTTP API 被本地工具调用
- **路由聚合** — 自动收集各插件声明的 `WebRoute`，按插件整体注册/撤回
- **热插拔** — 插件启用/禁用时路由即时生效/撤回，无需重启服务
- **非致命启动** — 端口被占用等失败不会中断 App，服务保持不可用状态

## 生命周期

| 钩子 | 行为 |
|------|------|
| `onBoot` | 创建 `LumiWebServer` 并注册到内核（`kernel.webServer`） |
| `onReady` / `onEnable` | 启动监听 |
| `onDisable` | 停止服务、释放连接 |

## 依赖

- `KernelLumi` — 插件协议与服务注册
- `WebServerKit` — `LumiWebServer` 实现（基于 SwiftNIO/Hummingbird）

## Policy

`.optOut` — 默认启用，用户可在插件管理中关闭。
