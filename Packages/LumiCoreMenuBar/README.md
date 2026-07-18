# LumiComponentMenuBar

LumiCore 的菜单栏组件包。

## ⚠️ 依赖约束

**此包只能被 LumiCoreKit 依赖，不应被其他任何包直接依赖。**

所有外部模块应通过 `LumiCoreKit` 的 typealias 访问此包中的类型：

```swift
// ✅ 正确：通过 LumiCoreKit 访问
import LumiCoreKit

// ❌ 错误：不应直接依赖此包
import LumiComponentMenuBar
```

## 包含模块

- `LumiMenuBarPopupItem` - 菜单栏弹出项，用于构建菜单栏弹出视图
- `LumiMenuBarContentItem` - 菜单栏内容项，用于构建菜单栏内容视图
- `MenuBarEvents` - 菜单栏事件定义

## 依赖

无外部依赖。

## 架构设计

本包提供菜单栏 UI 扩展点：

1. **弹出项** - `LumiMenuBarPopupItem` 定义菜单栏弹出的自定义视图，支持排序
2. **内容项** - `LumiMenuBarContentItem` 定义菜单栏内容区域的自定义视图
3. **事件系统** - `MenuBarEvents` 定义菜单栏相关的事件通知

该组件遵循 LumiCore 的插件扩展模式，允许插件通过 `LumiPlugin` 协议贡献菜单栏 UI。