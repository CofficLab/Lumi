# EditorBottomReferencesPlugin

Editor Panel 子插件：Panel Bottom 引用面板。

## 职责

展示当前符号的引用（Find References）结果。

## 挂载位置

- **类型**：`LumiPanelBottomTabItem`
- **Slot**：`panelBottom`
- **Order**：1
- **Activation**：optOut

## 依赖

- `LumiCoreKit`
- `LumiUI`
- `EditorService`

## 目录结构

```
EditorBottomReferencesPlugin/
├── Package.swift
├── README.md
├── .gitignore
├── Sources/
│   └── EditorBottomReferencesPlugin.swift
├── Resources/
│   └── Localizable.xcstrings
└── Tests/
```

## 注册

在 `Packages/LumiPluginRegistry/Sources/LumiPluginRegistry/LumiPluginRegistry.swift` 的 `allPlugins` 数组中注册 `EditorBottomReferencesPanelPlugin.self`。

## 相关插件

- Rail 薄封装：`EditorRailReferencesPlugin`
