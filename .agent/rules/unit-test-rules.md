# 单元测试规范

> 本规范定义了 Lumi 项目中单元测试的代码组织、目录结构和最佳实践。

---

## 核心原则

**测试代码与业务代码物理隔离，统一放置在项目根目录下的 `Tests/` 目录中。**

遵循 Xcode 的最佳实践，将测试代码独立于主应用（`LumiApp`）存放，可以确保测试文件**永远不会**被误打包进 App，同时免除了在 `project.pbxproj` 中手动维护排除列表（`membershipExceptions`）的繁琐工作。

---

## 目录结构

所有插件的单元测试统一存放在 `Tests/<PluginName>Tests/` 子目录中。

```text
Lumi/
├── LumiApp/              <-- 源码（对应 Lumi Target）
│   └── Plugins/
│       ── AgentEditorPlugin/
│           └── ...       <-- 插件源码
├── Tests/                <-- 测试代码（对应 LumiTests Target）
│   ├── AgentEditorPluginTests/
│   │   ├── EditorBufferTests.swift
│   │   └── EditorSessionTests.swift
│   └── InputPluginTests/
│       └── InputPluginTests.swift
└── Lumi.xcodeproj
```

---

## 命名规范

| 类型 | 命名规范 | 示例 |
|------|---------|------|
| 测试目录 | `<PluginName>Tests` | `AgentEditorPluginTests` |
| 测试文件 | `<SourceFileName>Tests.swift` | `EditorBufferTests.swift` |
| 测试类 | `<SourceClassName>Tests` | `EditorBufferTests` |

---

## 迁移指南

对于已存在的插件内测试目录（如 `LumiApp/Plugins/AgentEditorPlugin/Tests/`），请执行以下迁移：

1.  **移动文件**：将 `LumiApp/Plugins/<PluginName>/Tests/` 下的所有文件移动到 `Tests/<PluginName>Tests/`。
2.  **更新 Xcode 项目**：
    *   在 Xcode 中移除旧的 `Tests` 文件夹引用。
    *   在 `Tests` 目录下创建新的 Group（或 Folder Reference）。
    *   将新的 `Tests` 目录关联到 `LumiTests` Target。
    *   **清理 `project.pbxproj`**：删除旧测试文件对应的 `membershipExceptions` 条目，使配置更加简洁。
3.  **验证**：运行 `xcodebuild test` 确保所有测试用例通过。

---

## Xcode 配置优势

*   **零维护成本**：无需在 `pbxproj` 中维护 `membershipExceptions`，新建测试文件自动被 `LumiTests` Target 识别。
*   **安全性**：测试代码与 `LumiApp` 目录完全隔离，彻底杜绝测试代码被打包进 Release 版本的风险。
*   **清晰度**：开发者可以快速区分源码和测试代码，便于进行代码审查和重构。

---

## 相关规范

*   [插件目录结构规范](./plugin-directory-rules.md) - 规范插件源码的组织方式（注意：插件内部**不**包含 `Tests` 目录）。
*   [中间件开发规范](./middleware-rules.md) - 中间件的可测试性说明。
