# LumiComponentPanelChrome

LumiCore 的面板 UI 元素组件包。

## ⚠️ 依赖约束

**此包只能被 LumiCoreKit 依赖，不应被其他任何包直接依赖。**

所有外部模块应通过 `LumiCoreKit` 的 typealias 访问此包中的类型：

```swift
// ✅ 正确：通过 LumiCoreKit 访问
import LumiCoreKit

// ❌ 错误：不应直接依赖此包
import LumiComponentPanelChrome
```

## 包含模块

- `LumiPanelHeaderItem` - 面板头部项，用于在面板顶部添加自定义视图
- `LumiPanelBottomTabItem` - 面板底部 Tab 项，用于底部标签栏
- `LumiPanelRailTabItem` - 面板侧边 Rail Tab 项，用于侧边导航栏

## 依赖

无外部依赖。

## 架构设计

本包提供面板 UI 扩展点：

1. **头部项** - `LumiPanelHeaderItem` 在面板顶部添加自定义 UI 元素
2. **底部 Tab** - `LumiPanelBottomTabItem` 支持底部标签栏的扩展，包含标题、图标和视图
3. **侧边 Rail Tab** - `LumiPanelRailTabItem` 支持侧边导航栏的扩展

所有项都支持：
- 排序（通过 `order` 属性）
- 标识符（通过 `id` 属性）
- 自定义视图构建（通过 `@ViewBuilder`）

该组件遵循 LumiCore 的插件扩展模式，允许插件通过 `LumiPlugin` 协议贡献面板 UI 元素。