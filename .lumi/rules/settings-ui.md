# Settings UI (LumiUI)

All settings surfaces — built-in core tabs, plugin-contributed sidebar tabs, and editor settings rows — must use LumiUI semantic components for consistent chrome and theme tokens.

## Layout baseline (以「插件管理」页为基准)

设置窗口里所有入口的**间距**必须一致。基准是「插件管理」页（`PluginManagementView`），
下列数值是硬约定，新增或修改设置页时照抄，不得各写各的：

| 位置 | 数值 |
|------|------|
| 页面内容左右留白 | 24 |
| 页面内容顶部留白 | 24 |
| 页面内容底部留白 | 分栏页 16；滚动页 24 |
| 分栏页外层 VStack 间距 | 14 |
| 头部行 | `HStack(spacing: 10)` + `.appCaption` + 次要文字色 |
| 主从容器圆角 | 8（描边 1px `theme.divider`） |
| 主从容器高度 | **占满剩余空间**（`.frame(maxHeight: .infinity)`），常规窗口下约 520 |
| 列表栏宽度 | 300 |
| 列表栏头部控件内边距 | 12 |
| 列表内容 | `LazyVStack(spacing: 4)` + 内边距 8 |
| 详情栏内容内边距 | 22 |
| 单栏页分组间距 | 24（分组内 `AppSettingsSection` 间距 8、行间距 6） |

规则：

- 分栏页统一用 `AppSettingsContentScaffold(scrollsContent: false, maxContentWidth: nil)`
  并显式加 `.padding(.bottom, 16)`；不要用 `PluginSettingsScaffold(scrollsContent: false)`
  （它不给底部留白，页面会贴到窗口底边）。
- 列表栏宽度统一 300，不允许 280 / 320 / 340 各写各的。
- 圆角统一 8，不允许 10 / 12。
- **主从容器不要写死 `minHeight`**（例如 `.frame(minHeight: 520, maxHeight: .infinity)`）。
  设置窗口的内容区是「窗口高度 → 外层 ZStack → 详情页」的链式布局：详情页一旦
  比窗口高，外层容器会被撑大，窗口按**居中**方式裁切，于是页面**顶部和底部同时
  被切掉**（顶部卡片标题会整块消失）。正确写法是只写 `.frame(maxHeight: .infinity)`，
  让主从容器吃满剩余空间；窗口变矮时它会自然收缩，而不是把页面顶出可视区。
- 卡片风格统一 `.subtle`（`PluginSettingsScaffold` 会注入；直接用
  `AppSettingsContentScaffold` 的页面需自行注入
  `.environment(\.appSettingsCardStyleOverride, .subtle)`）。
- 禁止自建外框内边距（如 `.padding(18)`）绕过共享 scaffold。

`Packages/FactoryLumi/Tests/FactoryLumiTests/SettingsLayoutConformanceTests.swift`
是上述基准的守卫测试，改动设置页布局时必须让它保持绿色。

> 共享组件（`AppSettingsContentScaffold` / `PluginSettingsScaffold` / `AppCard` /
> `AppSettings*Row`）来自**外部包 LumiUI**，本仓库 90+ 个包依赖它。改它要走
> 「LumiUI 仓库发版 → 本仓库 bump 依赖」的流程，不要直接改
> `SourcePackages/checkouts/`（不入库，改动会丢）。设置页的间距问题优先在
> 各插件包内按上面的基准对齐。

## Page layout

Use this structure (see `PluginSettingsScaffold`):

```swift
PluginSettingsScaffold("Title", subtitle: "…") {
    AppCard {
        AppSettingsSection(title: "Section") {
            AppSettingsToggleRow("Option", isOn: $flag)
        }
    }
}
```

Core tabs without `PluginSettingsScaffold` should still follow: fixed header `AppCard` + `ScrollView` with `AppCard` sections.

## Row components

| Control | Component |
|---------|-----------|
| Toggle | `AppSettingsToggleRow` |
| Stepper | `AppSettingsStepperRow` |
| Menu picker | `AppSettingsPickerRow` |
| Segmented picker | `AppSettingsSegmentedPickerRow` |
| Read-only badge | `AppSettingsReadOnlyRow` |
| Secret / token field | `AppSettingsSecureFieldRow` |
| Custom content | `AppSettingsRow { … }` |

Do **not** use `AppToggleRow` on settings pages (use `AppSettingsToggleRow`).

## Card system（不用原生的）

设置页只有**一套**卡片体系：`AppCard` + `AppSettingsSection` + `AppSettings*Row`。

**禁止**使用原生 GroupBox 家族：
`AppSettingSection` / `AppSettingRow` / `AppSettingToggleRow` / `AppSettingPickerRow`
/ `AppSettingCheckmarkRow`（macOS 上渲染成系统 `GroupBox`，标题在卡片内，与自绘卡片
外观不一致）。它们只能出现在非设置场景（如工具栏右键菜单）。

标准写法：

```swift
AppCard {
    AppSettingsSection(title: "Section") {
        AppSettingsToggleRow("Option", isOn: $flag)
        AppSettingsRow { /* 自定义行内容 */ }
    }
}
```

- 一组一卡：`AppSettingsSection` 必须落在某个 `AppCard { … }` 作用域里；不要写
  「一个 AppCard 里塞多个带标题的分组」。
- 一行一个独立圆角行块：原来的「GroupBox 里多行 + 行间 Divider」改成「每行一个独立圆角行块」，
  行间不再需要 `Divider()`。
- 不要自造卡片外观：禁止用 `.background(.quaternary, in: RoundedRectangle(cornerRadius: 10))`
  这类手写圆角块冒充卡片，卡片的背景 / 描边 / 圆角一律交给 `AppCard`。
- 卡片风格统一 `.subtle`：`PluginSettingsScaffold` 已注入；直接用
  `AppSettingsContentScaffold` 的页面必须自己加
  `.environment(\.appSettingsCardStyleOverride, .subtle)`，否则渲染成 `.glass` 玻璃风，
  与其它设置页不一致。

`Packages/FactoryLumi/Tests/FactoryLumiTests/SettingsLayoutConformanceTests.swift`
是本节的守卫测试（会全仓扫描 `Packages/*/Sources`），改设置页卡片时必须让它保持绿色。

## Avoid

- `Form { }` / macOS `Section` in settings views
- `Color(hex:)` / `Color.adaptive` for text or backgrounds
- `.font(.system(size: …))` for settings copy (use `.appBody`, `.appCaption`, etc.)
- Bare `List` for settings rows (prefer `AppSettingsRow` in `AppCard`)

## Editor kernel

`EditorService` setting rows (`EditorToggleSettingRow`, etc.) delegate to LumiUI `AppSettings*` rows. New editor extension settings should return `AppSettingsToggleRow` (or siblings) in `EditorSettingsItemSuggestion.content`.

## Plugin-contributed settings tabs

Plugins can extend the **Settings window sidebar** with their own tabs by returning `settingsTabItems(kernel:)` from the `LumiPlugin` protocol. Hosted at:

`Packages/KernelLumi/Sources/KernelLumi/Contracts/LumiPlugin.swift`

Plugin-contributed tabs are **rendered flat after the four built-in tabs** (General / Appearance / Plugins / About) and registered through `kernel.settings?.registerSettingsTabItem(_:)`. The host view (`SettingsView`) re-renders on register/unregister via the kernel's observable forwarding.

### Template

```swift
import KernelLumi
import LumiUI
import SwiftUI

public func settingsTabItems(kernel: KernelLumi) -> [SettingsTabItem] {
    [
        SettingsTabItem(
            id: "com.mycompany.myplugin.main",
            title: LumiLocalization.string("My Plugin", bundle: .module),
            systemImage: "puzzlepiece.extension",
            content: {
                PluginSettingsScaffold(
                    LumiLocalization.string("My Plugin", bundle: .module),
                    subtitle: LumiLocalization.string(
                        "Configure integration options.", bundle: .module
                    )
                ) {
                    AppCard {
                        AppSettingsSection(
                            title: LumiLocalization.string("General", bundle: .module)
                        ) {
                            AppSettingsToggleRow(
                                LumiLocalization.string("Enable sync", bundle: .module),
                                isOn: $syncEnabled
                            )
                            AppSettingsPickerRow(
                                LumiLocalization.string("Theme", bundle: .module),
                                selection: $themeChoice,
                                options: [
                                    LumiLocalization.string("Light", bundle: .module),
                                    LumiLocalization.string("Dark", bundle: .module),
                                    LumiLocalization.string("Auto", bundle: .module),
                                ]
                            )
                        }
                    }
                }
            }
        )
    ]
}
```

### Rules

- **`id` must be globally unique** within `kernel.settings?.allSettingsTabItems`. Use a reverse-DNS namespace (e.g. `com.mycompany.myplugin.main`). Collisions are last-wins.
- **`title` is shown as-is** in the sidebar — wrap it with `LumiLocalization.string(_:bundle: .module)` so it respects the existing xcstrings catalog.
- **`systemImage` must be a SF Symbol name** (e.g. `"puzzlepiece.extension"`, `"wand.and.stars"`).
- The `content` closure runs on the MainActor; capture `@State` / bindings via the closure (the closure is invoked lazily inside the host view's tab body).
- `pluginAboutView(kernel:)` is still consumed separately inside the **Plugins** built-in tab as a per-plugin detail panel. Use it for "about / author info" rather than duplicating the main settings tab's content.
- `addSettingsView(kernel:) -> [AnyView]` is **not currently consumed by the host UI** — it is reserved for future expansion. New plugins should use `settingsTabItems` instead.

### Reusing `PluginSettingsScaffold`

`PluginSettingsScaffold` (LumiUI) is the recommended wrapper for any plugin-contributed settings tab. It pairs a sticky header card (title + subtitle) with a scrollable content area and keeps your content visually consistent with other plugin tabs.

Do **not** wrap your content in `Form { }` or macOS `Section` — see the "Avoid" list above.
