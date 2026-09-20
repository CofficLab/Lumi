# ProviderEditor

Lumi 编辑器能力契约包，定义编辑器 Provider 协议、跨层数据结构和插件贡献模型，不承载具体 UI 或业务实现。

## Package

- Package: `ProviderEditor`
- Product: `ProviderEditor`
- Platform: macOS 14+
- Swift tools: 6.0

## 提供什么

- 编辑器服务与编辑器表面的 Provider 协议
- 语言、高亮、主题、扩展贡献和上下文菜单等能力契约
- 文档位置、编辑操作和编辑器状态等跨包数据结构

## 依赖与集成

```swift
dependencies: [
    .package(path: "../ProviderEditor"),
],
targets: [
    .target(name: "YourTarget", dependencies: ["ProviderEditor"]),
]
```

契约包保持业务无关；新增实现放入 `Kit*` 或 `Plugin*` 包，不要让本包依赖具体编辑器实现。

## Testing

From this package directory:

```sh
swift test
```
