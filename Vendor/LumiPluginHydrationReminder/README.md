# LumiPluginHydrationReminder

「喝水提醒」插件的共享远程包，供 Lumi、Wakey 等 CofficLab 兄弟应用共同装配。

> 本插件不依赖其他插件。菜单栏、设置、文档和存储均通过 Provider 契约接入；
> 通用提醒能力由 `LumiKitReminder` 提供。

## Package

- Manifest 包名：`LumiPluginHydrationReminder`（与仓库名一致）
- Product / Target：`PluginHydrationReminder`
- Platform：macOS 14+
- Swift tools：6.0

## 提供什么

- 菜单栏喝水提醒控制、状态和间隔选择。
- 设置页提醒间隔管理与自定义间隔。
- 使用手册贡献。
- 多屏幕喝水提醒遮罩。
- 提醒运行状态、每日次数和自定义间隔持久化。
- 系统睡眠唤醒后的到期提醒补触发。

## 依赖与集成

```swift
dependencies: [
    .package(url: "https://github.com/CofficLab/LumiPluginHydrationReminder.git", from: "1.0.0")
]
```

将 product 加入宿主 Factory target：

```swift
.product(name: "PluginHydrationReminder", package: "LumiPluginHydrationReminder")
```

并在插件工厂中装配：

```swift
import PluginHydrationReminder

PluginHydrationReminder()
```

默认插件 id 为 `com.coffic.lumi.plugin.hydration`。宿主可注入自己的品牌 id；
Wakey 传入历史 id `HydrationReminderPlugin`，以保留原有启用状态和插件数据目录：

```swift
PluginHydrationReminder(id: "HydrationReminderPlugin")
```

宿主需提供 `MenuBarProviding`、`SettingViewProviding`、`DocsViewProviding` 和
`StorageProviding`，并使用 `LumiUI` 的共享设置与按钮组件。

## Testing

```sh
swift test
```
