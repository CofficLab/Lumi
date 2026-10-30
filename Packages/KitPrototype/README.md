# KitPrototype

产品原型设计器的核心 Kit：原型工程的数据模型、画板尺寸、HTML 校验与导出。

## 结构

```
Sources/KitPrototype/
├── PrototypeModels.swift        # 画板 / 屏幕 / 导航拓扑模型
├── PrototypeDocumentStore.swift # 原型工程读写
├── PrototypeTemplateFactory.swift
├── PrototypeHTMLLinter.swift    # HTML 合法性校验
├── PrototypeHTMLExporter.swift  # 导出
└── PrototypeAssetImporter.swift # 资源导入
```

## 尺寸约定

原型画板使用**逻辑点（CSS px）**：与 HTML/CSS 的视口一致，
导出像素 = 逻辑尺寸 × `scale`。

这与 `KitAppStorePromo` 的「固定 App Store 枚举尺寸」不同——原型需要支持任意设备，
因此尺寸由用户在建工程时选定，而非从固定枚举中选择。
