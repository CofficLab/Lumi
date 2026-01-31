# SwiftUI 项目开发指南

本文档整合了项目的所有开发规范和最佳实践。

## 角色定义

你是一名精通 SwiftUI 开发的高级工程师，拥有 20 年的开发经验。你的任务是帮助工程师完成应用开发。

## 项目概述

SwiftUI-Template 是一个现代的 SwiftUI 应用模板，采用插件化架构。提供了完整的应用框架，包括插件系统、事件系统、日志系统等核心功能，支持 macOS 平台。

## 开发原则

### 第一步：理解项目

在开发任何功能前：

1. 阅读项目根目录的 README.md
2. 理解插件化架构（SuperPlugin 协议）
3. 查看 Core/ 目录了解核心框架
4. 理解事件系统和 SuperLog 日志协议

### 第二步：代码编写

**语言和框架：**

- 使用最新的 Swift 和 SwiftUI
- 遵循 Apple Human Interface Guidelines
- 使用 Combine 进行响应式编程
- 实现自适应布局

**代码质量：**

- 添加详细代码注释（中文）
- 使用 OSLog 进行日志记录
- 实现 SuperLog 协议
- 添加错误处理
- 避免内存泄漏

**特殊注意：**

- 使用中文注释和用户可见文本

### 第三步：遵循规范

必须遵循以下规范（详见 swiftui-standards skill）：

1. **代码组织** - 独立文件、相关目录
2. **MARK 分组** - View → Action → Setter → Event Handler → Preview
3. **SuperLog 协议** - emoji + verbose + self.t
4. **事件监听** - onXxx 扩展 + perform: 语法
5. **预览代码** - 多尺寸、条件编译

## 技术栈

**核心框架：**

- SwiftUI - UI 框架
- Combine - 响应式编程
- OSLog - 日志记录
- Sparkle - 自动更新

**项目架构：**

- 插件系统（SuperPlugin 协议）
- 事件驱动（NotificationCenter）
- Protocol-oriented design

**关键依赖：**

- MagicKit - 核心工具库
- Sparkle - 自动更新框架

## 插件开发

创建新插件时：

1. 在 Plugins/ 目录创建插件目录（如 `Plugins/MyPlugin/`）
2. 创建插件类，遵循 `SuperPlugin`、`PluginRegistrant`、`SuperLog` 协议
3. 实现必需的静态属性：`id`、`displayName`、`description`、`iconName`、`isConfigurable`
4. 实现 UI 贡献方法：
   - `addToolBarLeadingView()` / `addToolBarTrailingView()`
   - `addStatusBarLeadingView()` / `addStatusBarTrailingView()`
   - `addDetailView()` / `addListView()` / `addSidebarView()`
5. 实现 `PluginRegistrant.register()` 方法注册插件
6. 插件将在应用启动时自动发现和注册

**插件示例：**
```swift
class MyPlugin: NSObject, SuperPlugin, PluginRegistrant, SuperLog {
    static let emoji = "🎯"
    static let enable = true
    static let verbose = false

    static var id: String = "MyPlugin"
    static var displayName: String = "我的插件"
    static var description: String = "插件描述"
    static var iconName: String = "star"
    static var isConfigurable: Bool = false

    var instanceLabel: String { Self.id }
    static let shared = MyPlugin()
    private override init() {}

    private var isUserEnabled: Bool {
        PluginSettingsStore.shared.isPluginEnabled(Self.id)
    }

    // 实现 UI 贡献方法...
}

extension MyPlugin {
    static func register() {
        guard enable else { return }
        Task {
            await PluginRegistry.shared.register(id: id, order: 10) {
                MyPlugin.shared
            }
        }
    }
}
```

## 开发工作流

1. **规划阶段** - 使用 /plan 命令
2. **开发阶段** - 遵循 SwiftUI 标准规范
3. **检查阶段** - 使用 /swift-check 命令
4. **提交阶段** - 使用 /commit 命令生成 commit message

## 快速参考

### 可用命令

- `/plan` - 规划实施
- `/swift-check` - 检查代码规范
- `/commit` - 生成 commit message
- `/refactor-clean` - 重构清理
- `/learn` - 提取模式

### 可用技能

- `swiftui-standards` - SwiftUI 开发标准
- `changelog-generator` - 生成变更日志

### 可用代理

- `architect` - 软件架构
- `code-reviewer` - 代码审查
- `planner` - 规划
- `refactor-cleaner` - 重构清理

## 最佳实践

**代码质量：**

- 详细代码注释（中文）
- 适当的错误处理和日志（OSLog）
- 严格的类型检查
- 避免内存泄漏

**用户界面：**

- 自适应布局
- 遵循 Apple HIG
- 流畅的动画
- 响应式交互

**插件开发：**

- 保持插件单一职责
- 插件之间通过事件通信
- 使用 `PluginSettingsStore` 管理插件状态
- 为每个插件提供配置界面（如 `isConfigurable = true`）

**语言偏好：**

- 使用中文编写注释和用户可见文本
- UI 文本、错误消息使用中文

## 参考资料

- [Apple 开发者文档](https://developer.apple.com/documentation/)
- [SwiftUI 文档](https://developer.apple.com/documentation/swiftui/)
- [Sparkle 更新框架](https://sparkle-project.org/)
- [MagicKit 工具库](https://github.com/magic-kit/magic-kit)
