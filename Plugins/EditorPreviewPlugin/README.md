# EditorPreviewPlugin

Editor Panel 子插件：Panel Bottom Markdown 预览。

## 职责

为 Markdown 文件提供实时预览 Tab；内含 runtime `EditorPreviewPlugin` actor 处理预览逻辑。

## 挂载位置

- **类型**：`LumiPanelBottomTabItem`
- **Slot**：`panelBottom`
- **Order**：84
- **Activation**：alwaysOn

## 依赖

- `LumiCoreKit`
- `LumiUI`
- `EditorService`

## 目录结构

```
EditorPreviewPlugin/
├── Package.swift
├── README.md
├── .gitignore
├── Sources/
│   └── EditorPreviewPlugin.swift
├── Resources/
│   └── Localizable.xcstrings
└── Tests/
```

## 注册

在 `Packages/LumiPluginRegistry/Sources/LumiPluginRegistry/LumiPluginRegistry.swift` 的 `allPlugins` 数组中注册 `EditorPreviewBottomPanelPlugin.self`。

## 相关插件

- 被 `EditorPanelPlugin` 依赖
