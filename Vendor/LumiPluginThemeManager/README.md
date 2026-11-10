# LumiPluginThemeManager

ThemeManager 插件：负责创建并注册 `ThemeProviding`，把用户选中的主题持久化到插件数据目录。主题包（[LumiPluginThemePack](https://github.com/CofficLab/LumiPluginThemePack)）只负责向这里注册主题。

## 功能

- 创建 `DefaultThemeProviding` 并以 host provider 注册（Kernel 可 stop 后重新 start）
- 主题选择持久化到 `pluginDataDirectory(for: id)`
- 兼容注入的旧 `ThemeProviding`，保留其主题与选中状态
- 三种历史目录布局的数据迁移（各自独立守卫）：
  - 版本目录之间：`db_*_vN/ThemeManager` → `db_*_vM/<pluginID>`
  - 同版本根内：`db_*_v6/ThemeManager`（Lumi 6.0.0 早期布局）
  - 非版本化：`<Application Support>/<bundleID>/ThemeManager`（早期 Kuzee 布局）

## 依赖

- [LumiKernel](https://github.com/CofficLab/LumiKernel) — `KernelCore`
- [LumiProviders](https://github.com/CofficLab/LumiProviders) — `ProviderStorage` / `ProviderTheme`
- [LumiLogging](https://github.com/CofficLab/LumiLogging) — `LumiLoggingKit`
- [LumiLocalization](https://github.com/CofficLab/LumiLocalization) — `LumiLocalizationKit`

## 使用

```swift
import PluginThemeManager

// 默认 id（Lumi）
kernel.boot(ThemeManagerPlugin())

// 宿主自定义 id（持久化目录随之切换）
kernel.boot(ThemeManagerPlugin(id: "com.coffic.kuzee.plugin.theme-manager"))
```

## 测试

```bash
swift test
```
