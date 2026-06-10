# EditorRailReferencesPlugin

Editor Panel 子插件：Editor Rail 引用（薄封装）。

## 职责

在 Rail 中提供 References 入口，复用 `EditorBottomReferencesPlugin`。

## 挂载位置

- **类型**：`LumiPanelRailTabItem`
- **Slot**：`editorRail`
- **Order**：3
- **Activation**：optOut

## 依赖

- `EditorBottomReferencesPlugin`
- `LumiCoreKit`
- `LumiUI`
- `EditorService`

## 目录结构

```
EditorRailReferencesPlugin/
├── Package.swift
├── README.md
├── .gitignore
├── Sources/
│   └── EditorRailReferencesPlugin.swift
├── Resources/
│   └── Localizable.xcstrings
└── Tests/
```

## 注册

在 `Packages/LumiPluginRegistry/Sources/LumiPluginRegistry/LumiPluginRegistry.swift` 的 `allPlugins` 数组中注册 `EditorRailReferencesPanelPlugin.self`。

## 相关插件

- 核心实现：`EditorBottomReferencesPlugin`
