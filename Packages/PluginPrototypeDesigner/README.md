# PluginPrototypeDesigner

用相连的 HTML 屏幕草绘产品原型：Agent 可通过工具创建 / 读取 / 校验 / 修改屏幕，
并导出为 PNG。

## 结构

```
Sources/PluginPrototypeDesigner/
├── PrototypeDesignerPlugin.swift
├── PrototypeDesignerRuleContributor.swift
├── PrototypeDesignerSkillContributor.swift
└── ...
```

## 与 KitPrototype 的关系

数据模型、画板尺寸、HTML 校验与导出能力由 `KitPrototype` 承担；
本插件负责 Agent 工具暴露、规则贡献与界面集成。
