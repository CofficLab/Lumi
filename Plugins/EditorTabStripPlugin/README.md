# EditorTabStripPlugin

Editor Panel 子插件：Panel Header 标签栏。


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
| **职责** | 管理已打开文件的 Tab 列表、切换与关闭；并导出 Agent 工具供 EditorPanelPlugin 使用。 |
| **注册目标** | `EditorExtensionRegistry`（经 `LumiPluginRegistry` → `EditorExtensionsBootstrap`） |
| **上游依赖** | `EditorService`、`LumiCoreKit`（详见 `Package.swift`） |
| **边界** | 不得依赖其他 Plugin 实现；通过 `SuperEditor*` 协议贡献能力 |

## 职责

管理已打开文件的 Tab 列表、切换与关闭；并导出 Agent 工具供 EditorPanelPlugin 使用。

## 挂载位置

- **类型**：`LumiPanelHeaderItem`
- **Slot**：`panelHeader`
- **Order**：80
- **Activation**：alwaysOn

## 依赖

- `LumiCoreKit`
- `LumiUI`
- `EditorService`

## 目录结构

```
EditorTabStripPlugin/
├── Package.swift
├── README.md
├── .gitignore
├── Sources/
│   ├── StripPlugin.swift               # 插件入口
│   ├── StripCoordinator.swift
│   ├── StripStore.swift
│   ├── StripEvents.swift
│   ├── HeaderView.swift
│   ├── ItemView.swift
│   ├── DragPreview.swift
│   ├── Tools/
│   │   ├── GetCurrentFileTool.swift
│   │   └── SetCurrentFileTool.swift
│   └── Localizable.xcstrings
└── Tests/
```

## 注册

在 `Packages/LumiPluginRegistry/Sources/LumiPluginRegistry/LumiPluginRegistry.swift` 的 `allPlugins` 数组中注册 `StripHeaderPlugin.self`。

## 相关插件

- 被 `EditorPanelPlugin` 依赖（Agent 工具）
