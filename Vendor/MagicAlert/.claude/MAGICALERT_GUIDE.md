# MagicAlert 开发指南

本文档整合了 MagicAlert Swift Package 的所有开发规范和最佳实践。

## 项目概述

MagicAlert 是一个 Swift Package Library，提供基于 SwiftUI 的 Toast 通知系统。

### 核心功能

- **Toast 通知系统** - 显示临时消息给用户
- **多种 Toast 类型** - 成功、错误、警告、信息和加载状态
- **灵活的显示模式** - overlay、banner、bottom、corner
- **全局函数 API** - 简洁的 `alert_` 前缀函数
- **错误处理组件** - 内置详细的错误视图

### 技术栈

- **Swift** - 5.9+
- **SwiftUI** - UI 框架
- **iOS/macOS** - 跨平台支持

### 平台支持

- macOS 14.0+
- iOS 17.0+

## 开发原则

### 第一步：理解项目架构

在开发任何功能前：

1. 查看项目根目录的 README.md 和 README_zh.md
2. 理解模块化目录结构：
   - `Sources/MagicAlert/` - 源代码
   - `ToastManager.swift` - 核心 Toast 管理器（单例）
   - `ToastModel.swift` - Toast 数据模型
   - `ToastContainer.swift` - Toast 容器视图
   - `ToastView.swift` - Toast 主视图
   - `ToastCommonView.swift` - 通用 Toast 视图
   - `ToastErrorView.swift` - 错误详情视图
   - `GlobalAlertFunctions.swift` - 全局 `alert_` 函数 API
   - `Extension+View.swift` - SwiftUI View 扩展
   - `Extension+Error.swift` - Error 扩展
   - `Extension+Image.swift` - Image 扩展

### 第二步：代码编写规范

**文件组织：**
- 每个 struct/class/extension 放在独立文件中
- 使用 MARK 分组组织代码
- 相关文件放在同一目录
- 公共 API 必须标记为 `public`
- 实现细节使用 `internal` 或 `private`

**代码质量：**
- 添加详细的中文代码注释
- 遵循 SwiftUI 最佳实践
- 添加适当的错误处理
- 避免 SwiftUI 视图中的内存泄漏

**命名规范：**
- 使用清晰、描述性的名称
- 扩展文件命名：`Type+Feature.swift`（如 `Extension+View.swift`）
- 全局函数使用 `alert_` 前缀（如 `alert_success`）
- 布尔值使用 `is`、`has` 前缀

### 第三步：遵循规范

1. **代码组织** - 独立文件、相关目录、MARK 分组
2. **MARK 分组顺序** - Properties → Initialization → Body → Actions → Event Handlers → Preview
3. **全局函数优先** - 优先使用 `alert_` 全局函数 API
4. **预览代码** - 添加 `#if DEBUG` 预览

## 核心模式

### 1. 单例模式

MagicAlert 使用单例模式管理 Toast：

```swift
public class MagicToastManager: ObservableObject {
    public static let shared = MagicToastManager()

    @Published private(set) var toasts: [ToastModel] = []

    private init() {}
}
```

### 2. 全局函数 API

简洁的全局函数设计：

```swift
// GlobalAlertFunctions.swift
public func alert_success(_ title: String, subtitle: String? = nil, duration: TimeInterval = 3.0) {
    MagicMessageProvider.shared.success(title, subtitle: subtitle, duration: duration)
}
```

### 3. MARK 分组规范

```swift
// MARK: - Properties
// MARK: - Initialization
// MARK: - Body
// MARK: - Actions
// MARK: - Event Handlers
// MARK: - Preview
```

### 4. View 扩展模式

```swift
// Extension+View.swift
public extension View {
    func withMagicToast() -> some View {
        // 返回包含 ToastContainer 的视图
    }
}
```

## 开发工作流

1. **规划阶段** - 使用 `/plan` 命令规划复杂功能
2. **开发阶段** - 遵循本指南的规范
3. **构建验证** - 运行 `swift build` 验证代码
4. **提交阶段** - 使用 `/commit` 命令生成 commit message
5. **Git 管理** - 遵循 `.claude/GIT_WORKFLOW.md` 中定义的分支策略

### Git 分支管理

MagicAlert 使用 **GitHub Flow** 工作流：

- **main** - 生产就绪，始终可部署（自动打版本标签）
- **feature/*** - 功能开发分支（从 main 创建，通过 PR 合并回 main）

详细的 Git 工作流程、提交规范、版本发布流程，请参阅：
📘 **[Git 工作流程指南](.claude/GIT_WORKFLOW.md)**

## 关键注意事项

### Swift Package 特定

- ✅ 没有 AppDelegate 或 SceneDelegate
- ✅ 使用 `#if DEBUG` 条件编译预览代码
- ✅ 公共 API 必须标记为 `public`
- ✅ 内部实现使用 `internal` 或 `private`
- ✅ 注意 @MainActor 和线程安全

### SwiftUI 组件开发

- ✅ 使用 `@Published` 标记可观察属性
- ✅ 避免 View 中的复杂计算（使用 computed properties）
- ✅ 在 `.task { }` 中处理视图出现时的加载
- ✅ 使用适当的动画效果

### 性能优化

- ✅ 自动清理过期的 Toast
- ✅ 避免在 View 中创建新对象
- ✅ 使用定时器自动消失

### 内存管理

- ✅ 在 Toast 消失时清理定时器
- ✅ 使用 `[weak self]` 避免循环引用
- ✅ 及时释放不需要的资源

## 常见命令

```bash
# 构建验证
swift build

# 运行测试
swift test

# 清理构建
swift package clean

# 在 Xcode 中打开
open Package.swift
```

## API 使用示例

```swift
import SwiftUI
import MagicAlert

struct ContentView: View {
    var body: some View {
        VStack {
            Button("显示成功") {
                alert_success("操作成功")
            }

            Button("显示错误") {
                alert_error("操作失败", autoDismiss: false)
            }

            Button("显示加载") {
                alert_loading("正在处理...")
            }

            Button("隐藏加载") {
                alert_dismiss_loading()
            }
        }
        .withMagicToast()
    }
}
```

## 可用的全局函数

- `alert_info(_ title: String, subtitle: String? = nil, duration: TimeInterval = 3.0)` - 显示信息提示
- `alert_success(_ title: String, subtitle: String? = nil, duration: TimeInterval = 3.0)` - 显示成功提示
- `alert_warning(_ title: String, subtitle: String? = nil, duration: TimeInterval = 4.0)` - 显示警告提示
- `alert_error(_ title: String, subtitle: String? = nil, duration: TimeInterval = 0, autoDismiss: Bool = false)` - 显示错误文本
- `alert_error(_ error: Error, title: String? = nil, duration: TimeInterval = 0, autoDismiss: Bool = false)` - 显示错误对象
- `alert_loading(_ title: String, subtitle: String? = nil)` - 显示加载中提示
- `alert_dismiss_loading()` - 隐藏加载中提示
- `alert_dismiss_all()` - 隐藏所有提示

## 参考资料

- [Swift Package Manager](https://www.swift.org/package-manager/)
- [SwiftUI](https://developer.apple.com/documentation/swiftui/)
- [GitHub Flow](https://docs.github.com/en/get-started/quickstart/github-flow)
