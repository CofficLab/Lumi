# macOS 菜单栏图标外观规范

本文档基于 **Apple 官方文档**、**开源项目实践** 与 **Lumi v2/v3 历史实现** 整理，用于指导菜单栏（`NSStatusItem`）图标的外观行为。

---

## 核心结论

| 场景 | 推荐方案 |
|------|----------|
| 静态单色图标（简单 App） | `button.image` + `NSImage.isTemplate = true` |
| 动态复合内容（Lumi：Logo + CPU + 网速） | `NSHostingView` 子视图 + **钉住** `button.effectiveAppearance` |
| 纯 SwiftUI、无插件架构的简单应用 | `MenuBarExtra` + `.renderingMode(.template)` |

**Lumi 实测**：`ImageRenderer` 烘焙 template 图在壁纸自适应菜单栏下**不可靠**；v2/v3 使用的 `NSHostingView` + 外观同步方案稳定。

---

## Apple 官方依据

### NSStatusItem / NSStatusBarButton

- [`NSStatusItem`](https://developer.apple.com/documentation/appkit/nsstatusitem)：通过 `button` 属性自定义状态栏项外观与行为。
- [`NSStatusBarButton`](https://developer.apple.com/documentation/appkit/nsstatusbarbutton)：10.10+ 推荐入口；应使用 `button.image` 而非 `statusItem.view`。
- `statusItem.view`（自定义 `NSView`）在 10.10 已 **deprecated**，因为系统有 30+ 种菜单栏着色状态，自定义视图无法全部覆盖。

### NSImage.isTemplate

[`NSImage.isTemplate`](https://developer.apple.com/documentation/appkit/nsimage/1520017-istemplate)：

> Template images should consist of **only black and clear colors**. … They are always mixed with other content and processed to create the desired appearance.

要点：

1. 图像内容只能是 **黑色 + 透明**（可用 alpha 调节不透明度）。
2. 设为 template 后，由 **AppKit 根据菜单栏上下文自动着色**（浅色/深色壁纸、活跃/非活跃屏幕等）。
3. 在 Asset Catalog 中也可将图片设为 **Template Image**（Render As → Template Image）。

### MenuBarExtra（SwiftUI，macOS 13+）

[`MenuBarExtra`](https://developer.apple.com/documentation/swiftui/menubarextra) 是 SwiftUI 原生菜单栏场景。标签图标应使用 template 渲染：

```swift
MenuBarExtra {
    ContentView()
} label: {
    Image(systemName: "star.fill")
        .renderingMode(.template)
}
```

Lumi 使用插件化 `NSStatusItem` 架构，不迁移到 `MenuBarExtra`，但 **template 着色原则相同**。

### 外观变化通知

系统外观变化时，AppKit 会要求窗口/视图重绘。对 **template image** 赋给 `button.image` 时，**通常无需**监听 `AppleInterfaceThemeChangedNotification` 手动换色——系统会自动重新处理 template。

若内容本身需要更新（CPU 数据、网速），才需要定时刷新 `button.image`。

---

## 开源项目实践

### YosemiteMenuBar（Apple DTS 工程师推荐模式）

仓库：[noahsmartin/YosemiteMenuBar](https://github.com/noahsmartin/YosemiteMenuBar)

[Stack Overflow 回答](https://stackoverflow.com/questions/24623559/nsstatusitem-change-image-for-dark-tint)（Taylor，Apple 工程师）指出：Yosemite 起应使用 template image，自定义 view 已 deprecated。Noah Martin 的 wrapper 做法：

```objc
// 定时将自定义 view 绘制到 NSImage，再作为 template 赋给 statusItem
[self.customView drawRect:NSMakeRect(0, 0, width, barHeight)];
[image setTemplate:YES];
[self.statusItem setImage:image];
```

**适用**：需要在菜单栏显示动态/复合内容，又不能使用 `statusItem.view` 时。

### Stats（exelban/stats）

仓库：[exelban/stats](https://github.com/exelban/stats)（37k+ stars）

- 每个模块通过 `NSStatusBar.system.statusItem` 创建独立状态项。
- Widget 内容用 AppKit 绘制（`CALayer`、`NSBezierPath` 等），生成单色图后设 `isTemplate`。
- CPU/内存/网络等动态指标走 **重绘 image** 路径，而非 SwiftUI 子视图。
- macOS 26 起需在 **系统设置 → 菜单栏** 中授权应用显示菜单栏项（[#3120](https://github.com/exelban/stats/issues/3120)）。

### 其他常见问题

| 问题 | 来源 | 处理 |
|------|------|------|
| 非活跃屏幕图标不变灰 | [Stats #2131](https://github.com/exelban/stats/issues/2131) | 确保 `button.image` 已设置；无内容时可设 `NSImage()` 占位 |
| 自定义图不显示 | [SO #71158917](https://stackoverflow.com/questions/71158917/nsimage-not-loading-macos-swift) | 确认 bundle 中有资源，并设 `isTemplate = true` |
| 壁纸自适应后颜色错误 | [Apple Forums #662322](https://developer.apple.com/forums/thread/662322) | 使用 template，**不要**用 `UserDefaults AppleInterfaceStyle` 手动切换黑白图 |

---

## Lumi 实现规范（v2/v3 验证方案）

### 根因

`ThemeWindowAppearanceSync.syncAllWindows()` 曾把 Lumi 主题的 `NSAppearance`（`aqua` / `darkAqua`）写到 **包括菜单栏在内的所有 `NSApp.windows`**，覆盖系统对壁纸自适应菜单栏的着色。v3 时代尚无此逻辑，故表现正常。

### 架构

```
Plugin menuBarContentItems
        ↓
MenuBarIconView（SwiftUI，使用 .primary / labelColor）
        ↓
MenuBarHostingView（NSHostingView 子视图，点击穿透）
        ↓
statusItem.button.addSubview(hostingView)
        ↓
ThemeWindowAppearanceSync 跳过 `.statusBar` 窗口；定期 restoreMenuBarSystemAppearance()
```

### 关键机制

1. **`ThemeWindowAppearanceSync`**：`isMenuBarOwnedWindow`（`level == .statusBar`）的窗口不参与主题同步。
2. **`MenuBarService.restoreMenuBarSystemAppearance()`**：主题同步后把菜单栏窗口 `appearance` 清回 `nil`，恢复系统壁纸自适应。
3. SwiftUI 内容使用 **`.primary` / `labelColor`**，由菜单栏窗口的有效外观驱动（与 v3 相同）。

### 必须遵守

1. 在 `button` 上挂 `MenuBarHostingView`，**不用** `ImageRenderer` 烘焙 `button.image`。
2. 菜单栏内容使用 **语义色**：`.primary`、`NSColor.labelColor`，**不要**写死 `.black` / `.white`。
3. Logo `statusBar` 场景：单色、无动画；SmartLight 用 `.primary` + `.colorInvert()`（v3 同款）。
4. 图表（`CPUMenuBarChartRenderer`）：`NSColor.labelColor` 填充 + `isTemplate = true`。
5. 动态内容用定时器刷新 `hostingView.rootView`（约 1s）。
6. `MenuBarHostingView.hitTest` 返回 `nil`，让点击穿透到 `NSStatusBarButton`。

### 禁止 / 不推荐

| 做法 | 原因 |
|------|------|
| `ImageRenderer` → `button.image` + `isTemplate` | 程序化 template 在壁纸自适应菜单栏下不着色 |
| 写死 `.foregroundStyle(.black)` | 浅色系统 + 深色壁纸时应为白色 |
| `CGWindowListCreateImage` 屏幕采样 | 脆弱、需权限、重复系统行为 |
| 依赖 `NSApp.effectiveAppearance` | 被 Lumi 主题窗口污染 |
| `button.contentTintColor` | `NSStatusBarButton` 上不可靠（FB8530353） |
| `statusItem.view = customView` | Deprecated API |

### 插件作者指南

贡献 `menuBarContentItems` 时：

```swift
// ✅ 语义色，随 hostingView.appearance 自适应
HStack {
    Image(systemName: "bolt.fill")
    Text("42%")
}
// 继承 .primary 即可，无需显式设色

// ❌ 写死颜色或 App 主题色
.foregroundStyle(.black)
.foregroundColor(theme.info)
```

图表用 `NSColor.labelColor` 绘制并设 `isTemplate = true`。

---

## 参考链接

- [NSStatusItem](https://developer.apple.com/documentation/appkit/nsstatusitem)
- [NSStatusBarButton](https://developer.apple.com/documentation/appkit/nsstatusbarbutton)
- [NSImage.isTemplate](https://developer.apple.com/documentation/appkit/nsimage/1520017-istemplate)
- [MenuBarExtra](https://developer.apple.com/documentation/swiftui/menubarextra)
- [Supporting Dark Mode（外观变化重绘机制）](https://developer.apple.com/documentation/uikit/supporting-dark-mode-in-your-interface)
- [NSStatusItem change image for dark tint（Apple 工程师回答）](https://stackoverflow.com/questions/24623559/nsstatusitem-change-image-for-dark-tint)
- [YosemiteMenuBar](https://github.com/noahsmartin/YosemiteMenuBar)
- [Stats](https://github.com/exelban/stats)
- [TahoeMenuDemo（MenuBarExtra template 示例）](https://github.com/sjhooper/TahoeMenuDemo)
