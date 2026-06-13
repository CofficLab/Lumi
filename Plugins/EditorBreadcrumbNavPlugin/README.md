# EditorBreadcrumbNavPlugin

Editor Panel 子插件：Panel Header 面包屑导航。


## 全局技术架构

Lumi 代码编辑器采用分层 + 插件扩展架构。完整说明见 [docs/editor-architecture.md](../../docs/editor-architecture.md)。

```text
应用装配层 (LumiApp)
    ↓
插件扩展层 (Plugins/Editor*, LSP*)  ← 本 Package
    ↓ 注册 SuperEditor* 贡献者
服务门面层 (EditorService)
    ↓                    ↓
视图层 (EditorSource)   内核逻辑层 (EditorKernel)
    ↓
渲染基础层 (EditorTextView, EditorLanguages, EditorSymbols)
```

## 本 Package 的位置

| 属性 | 值 |
|------|-----|
| **层级** | 插件扩展层 — Panel 子插件（Header） |
| **职责** | 在 Editor Panel 顶部展示当前文件路径面包屑，支持点击跳转。 |
| **注册目标** | `EditorExtensionRegistry`（经 `LumiPluginRegistry` → `EditorExtensionsBootstrap`） |
| **上游依赖** | `EditorService`、`LumiCoreKit`（详见 `Package.swift`） |
| **边界** | 不得依赖其他 Plugin 实现；通过 `SuperEditor*` 协议贡献能力 |

## 职责

在 Editor Panel 顶部展示当前文件路径面包屑，支持点击跳转。

## 挂载位置

- **类型**：`LumiPanelHeaderItem`
- **Slot**：`panelHeader`
- **Order**：70
- **Activation**：alwaysOn

## 依赖

- `LumiCoreKit`
- `LumiUI`
- `EditorService`

## 目录结构

```
EditorBreadcrumbNavPlugin/
├── Package.swift
├── README.md
├── .gitignore
├── Sources/
│   └── EditorBreadcrumbNavPlugin.swift
├── Resources/
│   └── Localizable.xcstrings
└── Tests/
```

## 注册

在 `Packages/LumiPluginRegistry/Sources/LumiPluginRegistry/LumiPluginRegistry.swift` 的 `allPlugins` 数组中注册 `EditorBreadcrumbHeaderPlugin.self`。

## 相关插件

- 父壳：`EditorPanelPlugin`
