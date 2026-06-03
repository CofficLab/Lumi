# VerbosityPlugin

响应详细程度切换插件。

## 功能

在右侧栏底部工具栏注入简洁/正常/详细切换按钮。通过 `AppLLMVM` 读写当前详细程度状态。

## 配置

该插件为 `alwaysOn` 模式，默认启用且不可手动关闭。

## 结构

```
Sources/
├── VerbosityPlugin.swift       # 插件入口
└── Resources/
    └── Verbosity.xcstrings
```
