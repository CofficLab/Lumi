# AgentAutoApprovePlugin

## 功能简介

在聊天工具栏右侧提供**自动批准开关**，允许用户一键控制是否自动批准高风险命令（如 Shell 执行等）。开关状态按项目隔离持久化，切换项目时自动恢复。

## 目录结构

```
AgentAutoApprovePlugin/
├── AgentAutoApprovePlugin.swift              # 插件主入口
├── AgentAutoApprovePlugin.xcstrings           # 国际化字符串
├── AgentAutoApprovePluginLocalStore.swift     # 配置存储
├── AgentAutoApprovePluginREADME.md            # 说明文档
└── Views/
    ├── AutoApproveToggle.swift                # 开关视图
    └── AutoApprovePersistenceOverlay.swift    # 持久化覆盖层
```

## 数据流

1. **AutoApproveToggle** — 用户点击开关 → 更新 `ProjectVM.autoApproveRisk`
2. **AutoApprovePersistenceOverlay** — 监听 `autoApproveRisk` 变化 → 调用 `AgentAutoApprovePluginLocalStore` 保存
3. **项目切换** — Overlay 监听 `currentProjectPath` 变化 → 从 Store 恢复该项目的设置

## 存储

- **格式**：Binary Property List
- **路径**：`AppConfig.getDBFolderURL()/AgentAutoApprovePlugin/settings.plist`
- **Key**：项目路径的 Base64 编码
- **线程安全**：`DispatchQueue` 串行队列
