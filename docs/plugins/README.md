# 插件系统文档

欢迎来到插件系统文档！这里包含您需要了解的关于插件开发的所有信息。

## 📚 文档目录

### 🚀 [快速入门](plugins/quickstart.md)
**适合：** 第一次创建插件

包含内容：
- 5 步创建第一个插件
- 完整示例代码
- 常用模式参考
- 调试技巧
- 常见问题解答

**预计时间：** 10-15 分钟

---

### 📖 [完整设计文档](plugins/system.md)
**适合：** 深入了解插件系统架构

包含内容：
- 核心架构设计
- 插件注册机制详解
- SuperPlugin 协议完整说明
- 视图系统（工具栏、侧边栏、状态栏）
- 事件系统和通信机制
- 插件生命周期管理
- 最佳实践和设计模式
- 完整插件示例

**预计阅读时间：** 30-45 分钟

---

### 🏗️ [架构图解](plugins/architecture.md)
**适合：** 可视化理解系统设计

包含内容：
- 系统概览图
- 插件注册流程图
- UI 区域映射
- 事件通信系统
- 插件加载顺序
- 条件渲染逻辑
- 性能优化机制
- 类型安全保证
- 线程安全机制

**预计阅读时间：** 15-20 分钟

---

## 🎯 推荐学习路径

### 路径 1：快速上手（适合新手）
```
1. 🚀 快速入门（10分钟）
   ↓
2. 创建你的第一个插件
   ↓
3. 运行并测试
   ↓
4. 根据需要查看完整文档
```

### 路径 2：深入理解（适合有经验开发者）
```
1. 🏗️ 架构图解（15分钟）
   ↓
2. 📖 完整设计文档（45分钟）
   ↓
3. 🚀 快速入门（10分钟）
   ↓
4. 开始构建插件
```

### 路径 3：问题解决（适合调试中）
```
1. 🚀 快速入门 - 查看常用模式
   ↓
2. 📖 完整设计文档 - 查找相关章节
   ↓
3. 🏗️ 架构图解 - 理解系统行为
```

---

## 🔑 核心概念速览

### 什么是插件？

插件是遵循 `SuperPlugin` 协议的类，可以向应用的不同区域贡献 UI 和功能。

### 插件能做什么？

- ✅ 在工具栏添加按钮
- ✅ 在侧边栏显示列表
- ✅ 创建独立标签页
- ✅ 在状态栏显示信息
- ✅ 响应应用事件
- ✅ 与其他插件通信

### 插件的基本结构

```swift
class MyPlugin: SuperPlugin, PluginRegistrant {
    // 元数据
    static let label = "MyPlugin"
    static var displayName = "我的插件"
    static let shared = MyPlugin()

    // 视图贡献
    func addDetailView() -> AnyView? {
        AnyView(MyView())
    }

    // 注册
    static func register() {
        await PluginRegistry.shared.register(id: "MyPlugin") {
            MyPlugin.shared
        }
    }
}
```

---

## 🛠️ 开发工具

### 必需
- **Xcode** 15.0+
- **Swift** 5.9+
- **macOS** 14.0+

### 推荐
- **SF Symbols** - 查找系统图标
- **SwiftUI Preview** - 快速预览视图

---

## 💡 插件示例

项目中的示例插件是最好的学习资源：

| 插件 | 位置 | 功能 |
|------|------|------|
| GitPlugin | `Plugins/Git/GitPlugin.swift` | 核心功能，创建标签页 |
| CommitPlugin | `Plugins/Git-Commit/CommitPlugin.swift` | 侧边栏列表视图 |
| BranchPlugin | `Plugins/Branch/BranchPlugin.swift` | 工具栏控件 |
| ProjectPickerPlugin | `Plugins/ProjectPicker/` | 项目选择器 |

---

## 🤝 贡献指南

如果您发现了文档中的问题或有改进建议：

1. **修正错误**：直接编辑 Markdown 文件
2. **补充示例**：添加更多实用代码示例
3. **改进说明**：让内容更清晰易懂

---

## 📞 获取帮助

- 📖 查看 [常见问题](plugins/quickstart.md#常见问题)
- 💻 查看 [示例插件](../Plugins/)
- 🐛 [报告问题](https://github.com/yourusername/project/issues)

---

## 🎓 进阶主题

完成基础学习后，您可以探索：

- **复杂视图构建** - 多层嵌套的 SwiftUI 视图
- **性能优化** - 大数据集的处理
- **插件间通信** - 高级事件模式
- **状态管理** - 复杂应用状态的处理
- **单元测试** - 插件功能测试

---

**祝您开发愉快！** 🚀

如有任何问题，欢迎查阅相关文档或联系项目维护者。
