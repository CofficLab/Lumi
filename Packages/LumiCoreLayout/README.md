# LumiComponentLayout

LumiCore 的布局功能组件包。

## ⚠️ 依赖约束

**此包只能被 LumiCoreKit 依赖，不应被其他任何包直接依赖。**

所有外部模块应通过 `LumiCoreKit` 的 typealias 访问此包中的类型：

```swift
// ✅ 正确：通过 LumiCoreKit 访问
import LumiCoreKit

let component = LumiCoreKit.LayoutComponent()
let state = LumiCoreKit.LayoutState()

// ❌ 错误：不应直接依赖此包
import LumiComponentLayout
```

## 包含模块

### Layout（布局）
- `LayoutComponent` - 布局功能组件
- `LayoutState` - 布局状态管理
- `LayoutEvents` - 布局事件通知
- `LumiChatSectionLayout` - 聊天区布局档位
- `LumiChatSectionItem` - 聊天区组件项
- `SplitDividerMath` - 分栏计算工具
- `SplitDividerRole` - 分栏角色定义

### Logo（标志）
- `LogoComponent` - Logo 功能组件
- `LogoItem` - Logo 项定义
- `LogoScene` - Logo 显示场景

## 依赖

- SuperLogKit

## 架构设计

```
┌─────────────────────────────────────────────┐
│            LumiCoreKit (门面)                │
│  ┌─────────────────────────────────────┐    │
│  │ LayoutExports.swift (typealias)      │    │
│  └─────────────────────────────────────┘    │
│                     ▲                        │
│     ┌───────────────┴───────────────┐       │
│     │                               │       │
│  LayoutComponent ─────────────── LogoComponent
│  (内部依赖)                       (内部依赖)  │
└─────────────────────────────────────────────┘
         ▲
         │ 只依赖这里
    ┌────┴────┐
    │ 外部模块 │
    │App, Chat│
    │ Plugins │
    └─────────┘
```