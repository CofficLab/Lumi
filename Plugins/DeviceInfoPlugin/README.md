# DeviceInfoPlugin

DeviceInfoPlugin 是 [Lumi](https://github.com/angel/Lumi) 的 macOS 设备监控插件，提供实时的 CPU、内存、磁盘和电池状态监控，并支持菜单栏图表、弹窗视图和设置面板。

## 功能特性

- 🖥️ **CPU 监控** — 实时 CPU 使用率，菜单栏波形图，历史曲线
- 💾 **内存监控** — 已用/总内存，菜单栏图表，历史详情
- 💿 **磁盘信息** — 磁盘总容量与已用空间
- 🔋 **电池状态** — 电量百分比与充电状态
- ⏱️ **系统运行时间** — 开机时长统计
- 📊 **菜单栏集成** — 紧凑的 CPU/内存波形图与弹出式详情面板
- ⚙️ **设置面板** — 完整的设备信息与系统监控视图
- 📋 **进程列表** — 顶部资源占用进程展示

## 项目结构

```
Sources/
├── DeviceInfoPlugin.swift          # 插件入口，集成到 Lumi 主应用
├── DeviceData.swift                # 数据模型与监控逻辑（CPU/内存/磁盘/电池）
├── ViewModels/
│   ├── CPUManagerViewModel.swift   # CPU 数据视图模型
│   ├── MemoryManagerViewModel.swift # 内存数据视图模型
│   └── SystemMonitorViewModel.swift # 系统监控视图模型
├── Views/
│   ├── DeviceInfoView.swift                # 主设置面板视图
│   ├── DeviceInfoMenuBarContentView.swift  # 菜单栏内容
│   ├── DeviceInfoMenuBarPopupView.swift    # 菜单栏弹出面板
│   ├── CPUHistoryGraphView.swift           # CPU 历史曲线
│   ├── CPUHistoryDetailView.swift          # CPU 历史详情
│   ├── CPUMenuBarChartRenderer.swift       # CPU 菜单栏图表渲染
│   ├── MemoryHistoryGraphView.swift        # 内存历史曲线
│   ├── MemoryHistoryDetailView.swift       # 内存历史详情
│   ├── MemoryMenuBarChartRenderer.swift    # 内存菜单栏图表渲染
│   ├── MemoryMenuBarPopupView.swift        # 内存弹出面板
│   ├── SystemMonitorView.swift             # 系统监控面板
│   ├── TopProcessesView.swift              # 顶部进程列表
│   └── WaveformView.swift                  # 波形图组件
└── Resources/
    └── DeviceInfo.xcstrings                # 本地化字符串
Tests/
└── PluginDeviceInfoTests.swift             # 单元测试
```

## 依赖项

| 依赖 | 说明 |
|------|------|
| `DeviceMonitorKit` | 设备底层监控服务 |
| `LumiCoreKit` | Lumi 核心功能库 |
| `LumiUI` | Lumi 共享 UI 组件 |
| `SuperLogKit` | 日志框架 |
| `IOKit` | macOS 系统框架（电源/硬件信息） |

## 平台要求

- **macOS 14.0+**
- **Swift 6.0+**

## 开发

```bash
# 构建
swift build

# 运行测试
swift test
```

## 许可证

本项目遵循其父项目 Lumi 的许可证。
