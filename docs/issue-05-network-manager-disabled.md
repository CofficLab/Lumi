# Issue #5: NetworkManagerPlugin 默认禁用

**严重程度**: 🟠 High  
**状态**: Open  
**文件**: `LumiApp/Plugins/NetworkManagerPlugin/NetworkManagerPlugin.swift`

---

## 问题描述

NetworkManagerPlugin 的功能看起来已完成，但默认被禁用 (`enable = false`)。这可能导致：
- 用户不知道该功能存在
- 代码维护负担增加
- 可能存在未完成的 bug 被隐藏

## 当前代码

```swift
actor NetworkManagerPlugin: SuperPlugin, SuperLog {
    nonisolated static let emoji = "🛜"
    static let enable = false  // 问题：功能已完成但默认禁用
    nonisolated static let verbose = true

    static let id = "NetworkManager"
    // ... 完整实现
}
```

## 问题分析

1. **功能完整度**: 插件包含完整的 UI 组件和 NavigationEntry
2. **UI 组件存在**: NetworkStatusBarPopupView、NetworkStatusBarContentView、NetworkDashboardView
3. **Service 依赖**: 依赖 NetworkHistoryService.shared

## 建议修复

**方案一**: 如果功能已完成，默认启用
```swift
static let enable = true
```

**方案二**: 如果不准备发布，移除或标记为 beta
```swift
static let enable = false  // Beta - 待发布
static let isBeta = true
```

**方案三**: 添加配置开关让用户选择启用

## 修复优先级

中 - 影响功能可用性和代码可维护性