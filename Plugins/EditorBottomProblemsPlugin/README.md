# EditorBottomProblemsPlugin

Editor Panel 子插件：Panel Bottom 问题面板。

## 职责

展示 LSP 诊断（错误/警告）列表，支持点击跳转到对应位置。

## 挂载位置

- **类型**：`LumiPanelBottomTabItem`
- **Slot**：`panelBottom`
- **Order**：0
- **Activation**：optOut

## 依赖

- `LumiCoreKit`
- `LumiUI`
- `EditorService`

## 目录结构

```
EditorBottomProblemsPlugin/
├── Package.swift
├── README.md
├── .gitignore
├── Sources/
│   └── EditorBottomProblemsPlugin.swift
├── Resources/
│   └── Localizable.xcstrings
└── Tests/
```

## 注册

在 `Packages/LumiPluginRegistry/Sources/LumiPluginRegistry/LumiPluginRegistry.swift` 的 `allPlugins` 数组中注册 `EditorBottomProblemsPanelPlugin.self`。

## 相关插件

- Rail 薄封装：`EditorRailProblemsPlugin`
