# Settings UI (LumiUI)

All settings surfaces — built-in core tabs, plugin-contributed sidebar tabs, and editor settings rows — must use LumiUI semantic components for consistent chrome and theme tokens.

## Layout baseline (以「插件管理」页为基准)

设置窗口里所有入口的**间距**必须一致。基准是「插件管理」页（`PluginManagementView`），
下列数值是硬约定，新增或修改设置页时照抄，不得各写各的：

| 位置 | 数值 |
|------|------|
| 页面内容左右留白 | 24（头部行）；主体分栏页贴边 |
| 页面内容顶部留白 | 24 |
| 页面内容底部留白 | 分栏页贴边；滚动页 24 |
| 分栏页外层 VStack 间距 | 0（贴边布局用分隔线代替间距） |
| 头部行 | `HStack(spacing: 10)` + `.appCaption` + 次要文字色 |
| 主从容器圆角 | 贴边页无外框；非贴边页 8（描边 1px `theme.divider`） |
| 主从容器高度 | **占满剩余空间**（`.frame(maxHeight: .infinity)`） |
| 列表栏宽度 | 300 |
| 列表栏头部控件内边距 | 12 |
| 列表内容 | `LazyVStack(spacing: 4)` + 内边距 8 |
| 详情栏内容内边距 | 22 |
| 单栏页分组间距 | 24（分组内 `AppSettingSection` 间距 12、行间距 0 + `Divider().padding(.vertical, 8)`） |

### 分栏页：贴边（edge-to-edge）

**分栏页统一采用贴边布局**：主体内容（列表栏 + 详情栏）直接贴到窗口左右与底边，
没有外框描边，左右下也没有留白。当前采用该布局的有「插件管理」「MCP 服务器」
「外观」三个入口。

写法要点：

- 用 `AppSettingsContentScaffold(scrollsContent: false, maxContentWidth: nil)`，
  外面套一层 `GeometryReader`；
- 整列 `.frame(width: proxy.size.width + 48)` 再 `.offset(x: -24)`，抵消共享
  scaffold 的左右 24 留白，使主从容器正好贴到窗口左右边缘；
- 头部行自行保留 24 的左右内边距，不要贴到窗口边缘；
- 头部行与主体之间用一条 `AppDivider()` 分隔（代替原来的 VStack 间距 14）；
- 主从容器不写圆角裁剪、不写 1px 描边（外框的左、右、下三条边都不存在）；
- 底部不再加 `.padding(.bottom, 16)`；
- 审计表里标记 `isEdgeToEdge: true`，豁免「圆角 8 / 1px 描边 / 底部留白 16」三项，
  其余基准（列表栏 300、详情栏内边距 22、不得写死 `minHeight`）照常生效。

规则：

- 列表栏宽度统一 300，不允许 280 / 320 / 340 各写各的。
- 非贴边页的圆角统一 8，不允许 10 / 12。
- **主从容器不要写死 `minHeight`**（例如 `.frame(minHeight: 520, maxHeight: .infinity)`）。
  设置窗口的内容区是「窗口高度 → 外层 ZStack → 详情页」的链式布局：详情页一旦
  比窗口高，外层容器会被撑大，窗口按**居中**方式裁切，于是页面**顶部和底部同时
  被切掉**（顶部卡片标题会整块消失）。正确写法是只写 `.frame(maxHeight: .infinity)`，
  让主从容器吃满剩余空间；窗口变矮时它会自然收缩，而不是把页面顶出可视区。
- 卡片用原生 `AppSettingSection`（见下文「Card system」）；若某个页面仍需渲染插件贡献的
  自绘卡片，`PluginSettingsScaffold` 会注入 `.subtle` 卡片风格，直接用
  `AppSettingsContentScaffold` 的页面需自行注入
  `.environment(\.appSettingsCardStyleOverride, .subtle)`。
- 禁止自建外框内边距（如 `.padding(18)`）绕过共享 scaffold。

`Packages/FactoryLumi/Tests/FactoryLumiTests/SettingsLayoutConformanceTests.swift`
是上述基准的守卫测试，改动设置页布局时必须让它保持绿色。

> 共享组件（`AppSettingsContentScaffold` / `PluginSettingsScaffold` /
> `AppSettingSection` / `AppSettingRow`）来自**外部包 LumiUI**，本仓库 90+ 个包依赖它。改它要走
> 「LumiUI 仓库发版 → 本仓库 bump 依赖」的流程，不要直接改
> `SourcePackages/checkouts/`（不入库，改动会丢）。设置页的间距问题优先在
> 各插件包内按上面的基准对齐。

## Page layout

Use this structure (see `PluginSettingsScaffold`):

```swift
PluginSettingsScaffold("Title", subtitle: "…") {
    AppSettingSection(title: "Section", titleAlignment: .leading) {
        VStack(spacing: 0) {
            AppSettingRow(title: "Option", description: "…", icon: "…") {
                AppSettingToggleRow("Option", isOn: $flag)
            }
        }
    }
}
```

Core tabs without `PluginSettingsScaffold` should still follow: fixed header + `ScrollView` with `AppSettingSection` groups.

## Row components

| Control | Component |
|---------|-----------|
| Toggle | `AppSettingToggleRow` |
| Read-only value | `AppSettingValueRow` |
| Drill-down entry | `AppSettingDisclosureRow` |
| Action row | `AppSettingActionRow` |
| Custom content | `AppSettingRow(title:description:icon:) { … }` |

原生家族**没有** Stepper / Picker / SegmentedPicker / SecureField / ReadOnly 版本——
这些控件放进 `AppSettingRow(title:description:icon:) { … }` 的 content 里。

Do **not** use `AppToggleRow` on settings pages (use `AppSettingToggleRow`).

## Card system（原生 GroupBox）

设置页的卡片**统一用原生 GroupBox 家族**：`AppSettingSection` + `AppSettingRow` +
行间 `Divider()`。macOS 上 `AppSettingSection` 渲染成系统 `GroupBox`，**分组标题在卡片内部**。

标准写法：

```swift
AppSettingSection(title: "新手引导", titleAlignment: .leading) {
    VStack(spacing: 0) {
        AppSettingRow(
            title: "重新查看新手引导",
            description: "重放首次启动引导流程。",
            icon: "graduationcap"
        ) {
            AppButton("开始", systemImage: "arrow.right", style: .secondary, size: .small) {
                viewModel.replayOnboarding()
            }
        }

        Divider()
            .padding(.vertical, 8)

        AppSettingRow(
            title: "说明书",
            description: "各功能的使用指南。",
            icon: "book"
        ) {
            AppButton("打开", systemImage: "book.pages", style: .secondary, size: .small) {
                isPresentingManuals = true
            }
        }
    }
}
```

- **禁止**自绘新卡片家族：`AppCard` / `AppSettingsSection` / `AppSettingsRow` /
  `AppSettingsToggleRow` / `AppSettingsStepperRow` / `AppSettingsPickerRow` /
  `AppSettingsSegmentedPickerRow` / `AppSettingsReadOnlyRow` / `AppSettingsSecureFieldRow`。
  这套是玻璃拟态卡片（标题在卡外、每行一个独立圆角行块），2026-10-25 起不再用于设置页。
- 同一分组内的相邻行之间加 `Divider().padding(.vertical, 8)`。
- 一个分组一张卡：不要把多个 `AppSettingSection` 塞进同一个外壳。
- 不要手写 `GroupBox { }`，分组一律走 `AppSettingSection`。
- 例外：**编辑器内核**（`EditorService` 的 `EditorToggleSettingRow` 等）继续用 `AppSettings*`
  行组件，那是编辑器扩展的约定，不属于设置窗口。
- 图表 / 指标面板（活动热力图、性能跑分、设备信息）可以用自绘圆角块承载图表，
  但其中的**设置分组**仍走原生 `AppSettingSection`。

`Packages/FactoryLumi/Tests/FactoryLumiTests/SettingsLayoutConformanceTests.swift`
是本节的守卫测试（会扫描设置入口详情页与插件面板设置页），改设置页卡片时必须让它保持绿色。

## Avoid

- `Form { }` / macOS `Section` in settings views
- `Color(hex:)` / `Color.adaptive` for text or backgrounds
- `.font(.system(size: …))` for settings copy (use `.appBody`, `.appCaption`, etc.)
- Bare `List` for settings rows (prefer `AppSettingRow` inside `AppSettingSection`)

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
                    AppSettingSection(
                        title: LumiLocalization.string("General", bundle: .module),
                        titleAlignment: .leading
                    ) {
                        VStack(spacing: 0) {
                            AppSettingToggleRow(
                                LumiLocalization.string("Enable sync", bundle: .module),
                                isOn: $syncEnabled
                            )

                            Divider()
                                .padding(.vertical, 8)

                            AppSettingRow(
                                title: LumiLocalization.string("Theme", bundle: .module)
                            ) {
                                Picker("", selection: $themeChoice) {
                                    Text(LumiLocalization.string("Light", bundle: .module)).tag("light")
                                    Text(LumiLocalization.string("Dark", bundle: .module)).tag("dark")
                                    Text(LumiLocalization.string("Auto", bundle: .module)).tag("auto")
                                }
                                .labelsHidden()
                            }
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
