# EditorBottomSearchPlugin

Editor Panel 子插件：Panel Bottom 搜索面板。

## 职责

在工作区内搜索文本/正则，展示匹配结果。

## 挂载位置

- **类型**：`LumiPanelBottomTabItem`
- **Slot**：`panelBottom`
- **Order**：2
- **Activation**：optOut

## 依赖

- `LumiCoreKit`
- `LumiUI`
- `EditorService`

## 目录结构

```
EditorBottomSearchPlugin/
├── Package.swift
├── README.md
├── .gitignore
├── Sources/
│   └── EditorBottomSearchPlugin.swift
├── Resources/
│   └── Localizable.xcstrings
└── Tests/
```

## 注册

在 `Packages/LumiPluginRegistry/Sources/LumiPluginRegistry/LumiPluginRegistry.swift` 的 `allPlugins` 数组中注册 `EditorBottomSearchPanelPlugin.self`。

## 相关插件

- Rail 薄封装：`EditorRailSearchPlugin`
