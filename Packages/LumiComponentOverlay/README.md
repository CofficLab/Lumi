# LumiComponentOverlay

LumiCore 的根层级覆盖层组件包。

## ⚠️ 依赖约束

**此包只能被 LumiCoreKit 依赖，不应被其他任何包直接依赖。**

所有外部模块应通过 `LumiCoreKit` 的 typealias 访问此包中的类型：

```swift
// ✅ 正确：通过 LumiCoreKit 访问
import LumiCoreKit

// ❌ 错误：不应直接依赖此包
import LumiComponentOverlay
```

## 包含模块

- `LumiRootOverlayItem` - 根层级覆盖层项，用于在根视图外层添加全局 overlay
- `LumiOnboardingPagesEnvironmentKey` - 引导页环境键

## 依赖

无外部依赖。

## 架构设计

本包提供根层级 UI 扩展点：

1. **覆盖层项** - `LumiRootOverlayItem` 允许插件在应用根视图外层添加覆盖层，例如：
   - 全局弹窗
   - 引导页
   - 通知 Toast
   - 模态对话框

2. **包装模式** - 通过 `wrap` 闭包包装内容视图，实现灵活的视图组合

3. **排序支持** - 通过 `order` 属性控制多个 overlay 的叠加顺序

该组件遵循 LumiCore 的插件扩展模式，允许插件通过 `LumiPlugin.rootOverlays(context:)` 贡献全局 overlay。