# FactoryLumiACP

ACP（Agent Client Protocol）专用的 Lumi 装配根。

ACP 与 GUI 共用 `KernelCore`、Provider 与功能插件，但只启动 headless agent 所需的插件目录。
宿主（`LumiACPApp` 或 `ACPBootstrap`）只依赖本工厂，不再各自维护一份 ACP 装配逻辑。

## 结构

```
Sources/FactoryLumiACP/
├── FactoryLumiACP.swift          # 装配入口
├── KernelFactory.swift           # Kernel 组装
├── ProviderFactory.swift         # Provider 组装
├── SuperPluginFactory.swift      # headless 插件目录
├── SuperProviderFactory.swift    # Provider 装配
└── PluginDataMigrationCoordinator.swift
```

## 与 FactoryLumi 的差异

`FactoryLumi` 面向 GUI 宿主，装配完整插件目录并包含窗口 / 菜单栏相关能力；
本工厂面向 ACP 宿主，只保留 agent 运行必需的插件，并在进程退出前
通过 `PluginDataMigrationCoordinator` 完成插件数据目录迁移。
