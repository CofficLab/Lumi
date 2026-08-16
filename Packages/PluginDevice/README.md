# PluginDevice

Lumi 的设备信息插件，提供系统资源监控（CPU / 内存 / GPU / 电池 / 存储）与历史趋势，
支持主内容视图、菜单栏图表、设置页与文档页等贡献点。

## 全局架构

Lumi 采用内核 + 插件 + Provider 扩展架构，完整说明见
[docs](../../docs)（若存在）。PluginDevice 通过 `SuperPlugin` 协议向内核注册贡献：

```text
LumiApp
   ↓
KernelCore (内核，管理插件生命周期)
   ↓
PluginDevice ← 本 Package（SuperPlugin 实现）
   ↓
Provider* 层 (ActivityBar / ContentView / MenuBar / RailView / SettingView / DocsView / Storage)
```

## 本 Package 的位置

| 属性 | 值 |
|------|-----|
| **类型** | 应用插件（SwiftPM 包） |
| **职责** | 采集并展示设备指标：CPU、内存、GPU、电池、存储、进程、系统监控 |
| **宿主内核** | `KernelCore`（`SuperPlugin` 生命周期） |
| **上游依赖** | `KernelCore`、`LocalizationKit`、`LumiUI`、`ProviderActivityBar`、`ProviderContentView`、`ProviderDocsView`、`ProviderMenuBar`、`ProviderRailView`、`ProviderSettingView`、`ProviderStorage`、`SuperLogKit` |
| **平台** | macOS 14+ |

## 目录结构

```text
PluginDevice/
├── Resources/                      # 包根资源（与 Sources 平级）
│   └── Localizable.xcstrings       # 本地化字符串目录
├── Sources/
│   └── PluginDevice/
│       ├── DevicePlugin.swift      # 插件入口：SuperPlugin 注册各贡献点
│       ├── Models/                 # 数据模型（struct/enum）
│       ├── Services/               # 系统采集与历史记录服务
│       ├── ViewModels/             # 视图状态管理（*ManagerViewModel）
│       ├── Views/                  # SwiftUI 视图
│       │   └── MenuBar/            # 菜单栏内容与弹窗视图
│       └── Support/                # 图表渲染器、状态色、本地化辅助
└── Tests/
```

各目录职责详见目录内 `README.md`。

## 插件贡献点

`DevicePlugin`（`com.coffic.lumi.plugin.device-info`）在 `onBoot` 中注册：

| 贡献 | ID | 说明 |
|------|-----|------|
| 设置入口 | `*.memory-settings` | 内存监控设置页 |
| ActivityBar 入口 | `*.entry` | 激活后展示设备信息主视图 |
| 主内容 | — | `DeviceInfoView` |
| 关于 / 说明书 | — | `DeviceInfoAboutView` / `DeviceInfoManualView` |
| 菜单栏内容 | `*.metrics` | CPU 每核柱状图 + 内存单柱 |
| 菜单栏弹窗 | `*.cpu` / `*.memory` | CPU、内存弹窗 |

## 构建与测试

```bash
# 构建
swift build

# 测试
swift test
```
