# FactoryLumiACP

ACP（Agent Client Protocol）专用的 Lumi 装配根。

ACP 与 GUI 共用 `KernelCore`、Provider 与功能插件，但只启动 headless agent 所需的插件目录。
宿主（`LumiACPApp` 或 `ACPBootstrap`）只依赖本工厂，不再各自维护一份 ACP 装配逻辑。

## 结构

```
Sources/FactoryLumiACP/
├── FactoryLumiACP.swift          # 装配入口 + headless 插件目录
├── KernelFactory.swift           # 交付 HostManifest 并驱动共享装配流水线
├── ProviderFactory.swift         # Provider 组装
├── SuperPluginFactory.swift      # headless 插件工厂契约
└── SuperProviderFactory.swift    # Provider 装配契约
```

## 装配方式

容器创建、宿主基线 Provider、历史数据目录迁移、插件启动都交给
`LumiFactory` 的 `KernelBootstrapper` / `KernelAssembler`：本工厂只提供一份 headless
`HostManifest`（`opensMainWindowOnLaunch = false`、`suppressesMainWindowOnLaunch = true`、
`statusBar = nil`、`skipsSharedRootViewWiring = true`），再在 `wireKernel` 里补齐 ACP
需要的会话选中态绑定。基线已注册的区域 Provider 通过 `registerIfAbsent` 跳过，避免
`providerAlreadyRegistered`。

`runACPServer()` **不接管主 runloop**：stdio 上的 JSON-RPC 事件由调用方的常驻主 runloop
驱动（见 `Sources/LumiACPExecutable/main.swift`），Swift 6 下 `RunLoop.run()` 也不允许在
异步上下文中调用。

## 与 FactoryLumi 的差异

`FactoryLumi` 面向 GUI 宿主，装配完整插件目录并包含窗口 / 菜单栏相关能力；
本工厂面向 ACP 宿主，只保留 agent 运行必需的插件，并把装配失败以
`ACP_BOOTSTRAP_FAILED <原因>` 写到 stderr 后退出，便于宿主进程快速定位。
