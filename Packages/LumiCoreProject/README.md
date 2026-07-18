# LumiComponentProject

LumiCore 的项目功能组件包。

## ⚠️ 依赖约束

**此包只能被 LumiCoreKit 依赖，不应被其他任何包直接依赖。**

所有外部模块应通过 `LumiCoreKit` 的 typealias 访问此包中的类型：

```swift
// ✅ 正确：通过 LumiCoreKit 访问
import LumiCoreKit

let component = LumiCoreKit.ProjectComponent()
let entry = LumiCoreKit.ProjectEntry(name: "demo", path: "/tmp/demo")

// ❌ 错误：不应直接依赖此包
import LumiComponentProject
```

## 包含模块

### Project（项目）
- `ProjectComponent` - 项目功能组件（写操作门面，`ObservableObject`）
- `ProjectState` - 项目状态管理（当前项目 / 项目列表，内存存储）
- `ProjectEntry` - 项目条目模型（含 `Language` 语言标识与向后兼容 Codable）
- `ProjectEvents` - 项目事件通知（`Notification.Name` 扩展与 SwiftUI 监听助手）
- `ProjectLanguageDetector` - 项目语言检测器（按 marker 文件推断，仅打开项目时执行一次）

## 设计说明

- `ProjectState` 的 `currentProject` / `projects` 为 `private(set)`，所有变更必须经 `ProjectComponent` 的方法门面，保证封装边界。
- `ProjectEntry.language` 由 `ProjectLanguageDetector` 在打开项目时填充，供插件在 `agentTools(context:)` 内 O(1) 判断项目类型，绝不在 per-request 路径做文件系统 I/O。
