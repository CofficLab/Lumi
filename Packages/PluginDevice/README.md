# PluginDevice

Lumi 的设备信息插件，提供系统资源监控（CPU / 内存 / GPU / 电池 / 存储）与历史趋势，
支持主内容视图、菜单栏图表、设置页与文档页等贡献点。

> **重要规则：本插件包不能依赖其他插件包，也不能被其他插件包依赖。**
>
> 插件之间只通过 Provider 契约通信：共享能力放入 `Provider*` / `Kit*` 包，
> 由宿主（`Factory*`）统一装配；跨插件互相引用会破坏插件的独立装配与卸载。

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
| **上游依赖** | `KernelCore`、`LumiLocalizationKit`、`LumiUI`、`ProviderActivityBar`、`ProviderContentView`、`ProviderDocsView`、`ProviderMenuBar`、`ProviderRailView`、`ProviderSettingView`、`ProviderStorage`、`LumiLoggingKit` |
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
| Agent 工具 | `device_status` | 在对话中查询设备状态，并插入一张状态卡片 |
| 消息渲染器 | `com.coffic.lumi.plugin.device-info.card` | 把 `renderKind = device-status` 的消息画成设备状态卡片 |

## 对话中的设备状态卡片

用户可以直接在对话里问「我这机器现在内存还剩多少」，LLM 会调用 `device_status`
工具。工具采集一份快照，按 `scope` 裁剪，插入一条带
`renderKind = "device-status"` 的时间线消息，由本插件注册的渲染器画成卡片。

`scope` 取值：

| scope | 卡片内容 |
|-------|---------|
| `overview`（默认） | CPU / 内存 / GPU / 电池 / 磁盘 一屏总览 |
| `cpu` | 总占用 + 每核分布 + 负载均值 + user/system/idle 拆分 |
| `memory` | 已用 / 总量 / 内存压力等级 |
| `storage` | 系统盘与外接卷容量 |
| `thermal` | 各传感器读数与峰值 |
| `processes` | 进程排行（CPU 与内存榜合并去重） |

卡片消息是**纯界面产物**，不会回流到 LLM 上下文——`MessageTimelineEvent`
把它识别为时间线事件并从历史中过滤掉。工具同时把关键数值以文本形式返回给
模型，供模型在回复里引用。

## 构建与测试

```bash
# 构建
swift build

# 测试
swift test
```

