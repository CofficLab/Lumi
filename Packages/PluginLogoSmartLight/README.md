# PluginLogoSmartLight

Lumi 的智能灯光主题 Logo 插件：贡献动画灯泡图标，用于应用 Logo / 关于页
（`general` / `about` 场景）与菜单栏单色图标（`statusBar` 场景）。

## 全局架构

Lumi 采用内核 + 插件 + Provider 扩展架构，完整说明见
[docs](../../docs)（若存在）。PluginLogoSmartLight 通过 `SuperPlugin` 协议向内核注册贡献：

```text
LumiApp
   ↓
KernelCore (内核，管理插件生命周期)
   ↓
PluginLogoSmartLight ← 本 Package（SuperPlugin 实现）
   ↓
ProviderLogo 层 (LogoProviding / LogoItem / LogoScene)
```

精简内核（SuperPlugin）没有声明式 `logoItems` 贡献点，因此本插件在
`onBoot(kernel:)` 中解析 `LogoProviding`，用追加语义注册自己的 `LogoItem`；
消费方（如菜单栏图标）按 `order` 优先级取用。

## 本 Package 的位置

| 属性 | 值 |
|------|-----|
| **类型** | 应用插件（SwiftPM 包） |
| **职责** | 提供智能灯光主题 Logo（动画 / 单色两种渲染） |
| **宿主内核** | `KernelCore`（`SuperPlugin` 生命周期） |
| **上游依赖** | `KernelCore`、`KitLocalization`、`ProviderLogo` |
| **平台** | macOS 14+ |

## 目录结构

```text
PluginLogoSmartLight/
├── Resources/                           # 包根资源（与 Sources 平级）
│   └── Localizable.xcstrings            # 本地化字符串目录
├── Sources/
│   └── PluginLogoSmartLight/
│       ├── LogoSmartLightPlugin.swift   # 插件入口：SuperPlugin 注册 LogoItem
│       ├── Views/                       # SwiftUI 视图
│       │   ├── SmartLightLogoView.swift        # 场景分发入口视图
│       │   ├── SmartLightAnimatedLogoView.swift # 动画灯泡（general / about）
│       │   └── MenuBar/                 # 菜单栏单色 Logo
│       │       └── SmartLightMonochromeLogoView.swift
│       └── Support/                     # 本地化辅助
└── Tests/
```

各目录职责详见目录内 `README.md`。

## 插件贡献点

`LogoSmartLightPlugin`（`com.lumi.plugin.logo-smart-light`，`order = 200`）在 `onBoot` 中
向 `LogoProviding` 注册 `LogoItem`，按 `LogoScene` 分发：

| 场景 | 视图 | 说明 |
|------|------|------|
| `general` / `about` | `SmartLightAnimatedLogoView` | 动画灯泡 Logo（含呼吸光晕与闪电图标） |
| `statusBar` | `SmartLightMonochromeLogoView` | 菜单栏单色灯泡 Logo |
| `statusBarHighlighted` | `SmartLightMonochromeLogoView`（`isHighlighted`） | 菜单栏高亮灯泡 Logo（橙色闪电） |

## 构建与测试

```bash
# 构建
swift build

# 测试
swift test
```
