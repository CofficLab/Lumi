# ProviderPanelBottom

Lumi 底部面板（PanelBottom / content footer）Provider。

## Package

- Product: `ProviderPanelBottom`
- Platform: macOS 14+
- Swift tools: 6.0

## 提供什么

底部面板的一排 tab 入口契约（类似 VS Code 底部面板的 PREVIEW / TERMINAL）：

- `PanelBottomItem`：一个入口贡献（id / 标题 / 图标 / 排序 / 归属插件 / 内容视图工厂）。
- `PanelBottomProviding`：注册、撤回、切换入口的最小能力契约。
- `PanelBottomProvider`：默认实现（按 `order` 排序、按 `ownerPluginID` 批量撤回、
  激活入口回退与持久化回调、类型化变更事件）。

宿主（PluginRootView 中的 `PanelBottomPlugin`）负责把入口渲染为
content footer 中的 tab 容器；EditorPreview、Terminal 等插件只贡献入口，
不再直接写入 `RootViewProviding.setContentFooterView`。

## 生命周期约定（消费方必读）

内核运行时禁用插件只调用 `onDisable`，**不会**代撤插件注册到其它 Provider
中的贡献，因此每个消费方必须对称维护自己的入口：

- `onBoot` / `onEnable`：注册入口（`addItems` 按 id 幂等覆盖，可直接重入）；
- `onDisable` / `onShutdown`：`removeItems(ownerPluginID:)` 撤回入口。

入口为空时宿主会自动撤回 footer 容器，无需消费方关心
`RootViewProviding.setContentFooterView`。tab 的 `order` 应派生自插件的
`order`（见 `.agent/rules/plugin-order-rules.md`），使相对顺序由插件目录统一决定。

## 依赖与集成

```swift
dependencies: [
    .package(path: "../ProviderPanelBottom"),
],
targets: [
    .target(name: "YourTarget", dependencies: ["ProviderPanelBottom"]),
]
```

## Testing

From this package directory:

```sh
swift test
```
