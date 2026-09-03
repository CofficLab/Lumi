---
name: swiftui-standards
description: SwiftUI 开发标准规范，包括代码组织、MARK 分组、日志记录、预览代码和事件监听的统一规范。
---

# SwiftUI 开发标准规范

本技能确保所有 SwiftUI 代码遵循项目的统一开发规范。

## 何时使用

- 编写新的 SwiftUI 视图
- 重构现有 Swift 代码
- 实现事件监听
- 添加日志记录
- 组织代码结构

## 核心规范

### 1. 代码组织原则

- 每个 struct/class 应该放在独立的文件中
- 文件名应与类型名称保持一致
- 相关组件应组织在同一目录下

### 2. MARK 分组规范

所有 SwiftUI 视图文件必须按以下顺序使用 MARK 分组：

```swift
// MARK: - View          - SwiftUI View 主体实现
// MARK: - Action        - 用户交互触发的行为
// MARK: - Setter        - 状态/属性的集中更新方法
// MARK: - Event Handler - 事件处理函数
// MARK: - Preview       - 多尺寸预览
```

### 3. 日志记录

- 统一使用 `SuperLog` + `os.Logger`
- 关键路径（onBoot / 数据加载 / 错误恢复）必须记录日志
- 避免在主线程阻塞 IO

### 4. Preview

- 所有视图提供 `#Preview` 预览
- 预览覆盖明暗外观与常用状态

## 注意事项

- 遵循项目现有规范，不引入新风格
- 迁移后的代码不添加「已迁移」注释