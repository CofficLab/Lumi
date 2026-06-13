# EditorRailFileTreePlugin

Editor Panel 子插件：Editor Rail 文件树。


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
| **层级** | 插件扩展层 — Panel 子插件（Rail / Bottom） |
| **职责** | 在 Editor 左侧 Rail 展示项目文件树（Explorer）。 |
| **注册目标** | `EditorExtensionRegistry`（经 `LumiPluginRegistry` → `EditorExtensionsBootstrap`） |
| **上游依赖** | `EditorService`、`LumiCoreKit`（详见 `Package.swift`） |
| **边界** | 不得依赖其他 Plugin 实现；通过 `SuperEditor*` 协议贡献能力 |

## 职责

在 Editor 左侧 Rail 展示项目文件树（Explorer）。

## 挂载位置

- **类型**：`LumiPanelRailTabItem`
- **Slot**：`editorRail`
- **Order**：0
- **Activation**：alwaysOn

## 依赖

- `LumiCoreKit`
- `LumiUI`
- `EditorService`

## 目录结构

```
EditorRailFileTreePlugin/
├── Package.swift
├── README.md
├── .gitignore
├── Sources/
│   └── EditorRailFileTreePlugin.swift
├── Resources/
│   └── Localizable.xcstrings
└── Tests/
```

## 注册

在 `Packages/LumiPluginRegistry/Sources/LumiPluginRegistry/LumiPluginRegistry.swift` 的 `allPlugins` 数组中注册 `EditorRailFileTreePanelPlugin.self`。

## 相关插件

- App 级布局：`LumiApp/Views/Layout/RailView.swift`
