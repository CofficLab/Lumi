# 浅色/深色模式适配指南

## 概述

本文档记录了 Lumi 项目从仅支持深色模式到完全支持浅色/深色模式的自动适配迁移过程。

## 问题分析

### 原始问题

**侧边栏文字在浅色模式下显示为白色，导致可见度极差。**

### 根本原因

1. **硬编码的静态颜色**
   ```swift
   // ColorTokens.swift - 原有实现
   let textPrimary = Color(hex: "FFFFFF")  // 永远白色
   let textSecondary = Color(hex: "EBEBF5")  // 永远浅白
   ```

2. **没有响应式适配**
   - 所有组件直接使用静态颜色值
   - 没有使用 `@Environment(\.colorScheme)` 检测当前模式
   - 强制深色模式绕过问题（ThemeSettingView:35）

3. **影响范围**
   - Sidebar.swift: 文本颜色（主要/次要/三级）
   - ContentView.swift: 背景颜色
   - MaterialTokens.swift: 材质效果
   - 以及所有使用 `DesignTokens.Color.semantic.*` 的组件

## 解决方案

### 1. 响应式颜色系统

创建了 `AdaptiveSemanticColors` 结构，根据 `ColorScheme` 动态返回合适的颜色：

```swift
extension DesignTokens {
    enum Color {
        // 新增：响应式语义化颜色
        static let adaptive = AdaptiveSemanticColors()
    }
}

struct AdaptiveSemanticColors {
    // 文本色 - 根据配色方案动态调整
    func textPrimary(for scheme: ColorScheme) -> Color {
        switch scheme {
        case .light:
            Color(hex: "1C1C1E")  // 深色文本（浅色模式）
        case .dark:
            Color(hex: "FFFFFF")  // 白色文本（深色模式）
        }
    }

    // 背景色 - 根据配色方案动态调整
    func deepBackground(for scheme: ColorScheme) -> Color {
        switch scheme {
        case .light:
            Color(hex: "F5F5F7")  // 浅灰紫背景
        case .dark:
            Color(hex: "050508")  // 深色背景
        }
    }

    // ... 更多响应式颜色
}
```

### 2. 组件更新

#### 已更新的核心组件

| 文件 | 更新内容 | 状态 |
|------|---------|-----|
| `ColorTokens.swift` | 添加 `AdaptiveSemanticColors` 结构 | ✅ |
| `Sidebar.swift` | 添加 `@Environment(\.colorScheme)`，使用响应式颜色 | ✅ |
| `ContentView.swift` | 背景色使用 `DesignTokens.Color.adaptive.deepBackground(for:)` | ✅ |
| `MaterialTokens.swift` | 添加 `mysticGlass(for:)` 响应式材质 | ✅ |
| `ThemeSettingView.swift` | 移除强制深色模式，支持自动适配 | ✅ |

#### 更新模式

**旧代码：**
```swift
Text(entry.title)
    .foregroundColor(DesignTokens.Color.semantic.textPrimary)
```

**新代码：**
```swift
@Environment(\.colorScheme) private var colorScheme

Text(entry.title)
    .foregroundColor(DesignTokens.Color.adaptive.textPrimary(for: colorScheme))
```

### 3. 颜色映射表

#### 文本颜色

| 颜色层级 | 深色模式 | 浅色模式 | 说明 |
|---------|---------|---------|-----|
| Primary | `#FFFFFF` (白) | `#1C1C1E` (深灰) | 主要文本 |
| Secondary | `#EBEBF5` (浅白) | `#6B6B7B` (中灰) | 次要文本 |
| Tertiary | `#98989E` (紫灰) | `#98989E` (紫灰) | 三级文本 |
| Disabled | `#48484F` (深灰) | `#BDBDBD` (浅灰) | 禁用文本 |

#### 背景颜色

| 背景类型 | 深色模式 | 浅色模式 | 说明 |
|---------|---------|---------|-----|
| Deep Background | `#050508` | `#F5F5F7` | 主背景 |
| Surface | `#0D0D12` | `#FFFFFF` | 卡片表面 |
| Elevated Surface | `#14141A` | `#FFFFFF` | 悬浮表面 |
| Overlay | `#1A1A22` | `#E5E5EA` | 叠加层 |

#### 材质效果

| 材质 | 深色模式 | 浅色模式 |
|-----|---------|---------|
| 神秘玻璃 | `Color.black.opacity(0.3)` | `Color.white.opacity(0.6)` |
| 光晕强度 | `0.15` | `0.06` |
| 边框透明度 | `0.15` | `0.3` |

## 仍需更新的组件

以下文件仍在使用静态 `DesignTokens.Color.semantic.*`，需要逐一更新：

### 高优先级（直接可见性影响）

1. **NavigationSidebarView.swift**
   - 文本颜色使用
   - 影响导航可见性

2. **SettingsView.swift**（主设置页面）
   - 文本、图标颜色
   - 用户直接交互

3. **GlassRow.swift** / **GlassDivider.swift** 等基础组件
   - 被广泛使用，影响全局

### 中优先级（插件视图）

4. **DiskManagerPlugin/Views/DiskManagerView.swift**
   - 使用了 30+ 处静态颜色

5. **RClickPlugin/Views/RClickSettingsView.swift**
   - 大量文本颜色使用

6. **ClipboardManagerPlugin/Views/ClipboardHistoryView.swift**
   - 文本颜色使用

### 低优先级（装饰性元素）

7. 其他插件视图中的颜色使用

## 更新步骤

### 单个组件更新流程

1. **添加环境变量**
   ```swift
   @Environment(\.colorScheme) private var colorScheme
   ```

2. **替换静态颜色调用**
   ```swift
   // 旧
   .foregroundColor(DesignTokens.Color.semantic.textPrimary)

   // 新
   .foregroundColor(DesignTokens.Color.adaptive.textPrimary(for: colorScheme))
   ```

3. **验证效果**
   - 在 Xcode 中切换浅色/深色预览
   - 运行应用，在系统设置中切换模式
   - 确保文本对比度满足 WCAG AA 标准（4.5:1）

## 测试清单

### 基础功能测试

- [ ] 应用启动后默认模式显示正确
- [ ] 系统设置中切换浅色/深色模式，应用立即响应
- [ ] 所有文本在两种模式下都可读
- [ ] 背景色与文本色对比度充足

### 组件测试

- [ ] Sidebar - 导航项文字可读
- [ ] Sidebar - 选中状态明显
- [ ] Sidebar - 设置按钮可读
- [ ] Settings 页面 - 所有文本可读
- [ ] 主题选择 - 预览正确显示

### 边缘情况测试

- [ ] 切换主题时模式正确保持
- [ ] 插件视图在不同模式下显示正常
- [ ] 光晕效果在浅色模式下不过度曝光
- [ ] 材质效果在浅色模式下不突兀

## 设计原则

### 品牌一致性

- **主题色保持不变** - 10 个季节主题的颜色在浅色/深色模式下保持一致
- **只调整基础色** - 背景色、文本色等基础元素才根据模式调整

### 视觉层次

- 浅色模式：浅色背景 + 深色文本（高对比度）
- 深色模式：深色背景 + 浅色文本（高对比度）
- 材质透明度调整：浅色模式使用更弱的半透明效果

### 无障碍性

- 所有文本对比度 ≥ 4.5:1（WCAG AA）
- 禁用状态文本保持可辨识
- 选中状态在两种模式下都清晰可见

## 工具和脚本

### 批量查找需要更新的文件

```bash
# 查找所有使用静态语义颜色的文件
grep -r "DesignTokens\.Color\.semantic\." --include="*.swift" -n
```

### 验证颜色对比度

使用在线工具：
- https://webaim.org/resources/contrastchecker/
- https://contrast-ratio.com/

## 后续优化建议

### 短期

1. 创建 View 扩展简化使用
   ```swift
   .adaptiveTextColor(.primary) // 自动使用环境中的 colorScheme
   ```

2. 添加测试模式切换的开发者选项

### 长期

1. 考虑使用 SwiftUI 的 `.preferredColorScheme()` 强制特定模式
2. 添加高对比度模式支持
3. 实现自动模式检测（基于壁纸亮度）

## 参考资料

- [Apple HIG - Color and Typography](https://developer.apple.com/design/human-interface-guidelines/color)
- [WCAG 2.1 Contrast Requirements](https://www.w3.org/WAI/WCAG21/Understanding/contrast-minimum)
- [SwiftUI Color Schemes](https://developer.apple.com/documentation/swiftui/view/colorscheme(_:))
