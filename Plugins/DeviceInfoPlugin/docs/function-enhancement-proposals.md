# DeviceInfoPlugin 功能增强建议

> 基于对现有代码的全面分析（2025-07-09），结合 macOS 系统监控领域的主流工具（如 Stats、iStat Menus、hagimi-monitor 等）和 Apple 官方文档，整理出可添加的新功能建议。

---

## 一、插件现状概览

### ✅ 已实现功能

| 模块 | 功能 | 实现位置 |
|------|------|----------|
| **CPU** | 总使用率、每核使用率、User/System/Idle 占比、1/5/15分钟负载均值 | `CPUService.swift` |
| **内存** | 已用/总量、使用率 | `DeviceData.swift` + `MemoryService.swift` |
| **磁盘** | 根卷已用/总量 | `DeviceData.swift` |
| **外置存储** | 检测所有外置卷，显示名称/已用/可用/总量 | `StorageService.swift` |
| **GPU** | 使用率、渲染器/分块器利用率、显存、温度、型号识别、多GPU取最高 | `GPUService.swift` |
| **电池** | 电量、充电状态、循环次数、健康度、温度、电压、电流、系统功耗、适配器功率、供电类型 | `BatteryService.swift` |
| **进程** | Top 5 CPU 占用进程（名称、图标、CPU%、内存） | `ProcessService.swift` |
| **系统运行时间** | 开机时长统计 | `DeviceData.swift` |
| **菜单栏** | CPU/内存/GPU 波形图 + 弹出式详情面板 | 多个 `MenuBar*` 视图 |
| **历史曲线** | CPU/内存/GPU 历史趋势图 | 多个 `History*` 视图 |

---

## 二、待实现功能（TODO.md 中已规划但未完成）

### 🔴 优先级高

#### 1. 内存增强（压力等级 + Swap）

**问题**：当前内存监控只显示"已用/总量"，缺少系统内存压力的关键指标。

**建议新增**：
- **内存压力等级**：通过 `kern.memorystatus_vm_pressure_level` sysctl 读取
  - normal (0-1) → 🟢 正常
  - warning (2) → 🟡 偏高
  - critical (4) → 🔴 严重
- **Swap 使用量**：通过 `vm.swapusage` sysctl 读取 `xsw_usage` 结构体
  - 显示 Swap 已用/总量
  - 当 Swap 使用量 > 0 时提示用户内存不足
- **更精确的内存计算公式**：
  ```
  当前公式：active + wired + compressed
  改进公式：active + inactive + speculative + wired + compressed - purgeable - external
  ```

**API 参考**：
```swift
// 内存压力等级
var pressureLevel: Int32 = 0
var size = MemoryLayout<Int32>.size
sysctlbyname("kern.memorystatus_vm_pressure_level", &pressureLevel, &size, nil, 0)

// Swap 使用量
var swapUsage = xsw_usage()
size = MemoryLayout<xsw_usage>.size
sysctlbyname("vm.swapusage", &swapUsage, &size, nil, 0)
// swapUsage.xsu_used → 已用 Swap 字节数
```

#### 2. 网络监控（接口名称 + IP 地址 + 流量统计）

**问题**：目前完全没有网络监控功能，而这是系统监控工具的标准模块。

**建议新增**：
- **活动网络接口识别**：按流量最大的接口判定活动接口
- **接口友好名称映射**：
  - `en0` → Wi-Fi（或有线以太网）
  - `en*` → 以太网
  - `bridge*` → 桥接
  - `pdp_ip*` → 蜂窝网络
- **IP 地址**：读取 IPv4/IPv6 地址（过滤 `fe80:` 链路本地地址）
- **虚拟接口过滤**：忽略 `lo0`、`utun*`、`awdl*`
- **上传/下载速率**：通过 `getifaddrs()` 统计字节数变化
- **IP 地址在弹出面板中展示**

**API 参考**：
```swift
// 获取所有网络接口
var ifaddr: UnsafeMutablePointer<ifaddrs>?
getifaddrs(&ifaddr)

// 遍历接口，过滤虚拟接口
// 读取 ifa_data 中的 if_data 结构体获取流量统计
// if_data.ifi_ibytes → 接收字节数
// if_data.ifi_obytes → 发送字节数

// IP 地址读取
import Network
NWPathMonitor 或 SCNetworkInterface 框架
```

### 🟡 优先级中

#### 3. 差异化采样频率

**问题**：当前各模块使用固定间隔（CPU 1s, GPU 2s, 电池 5s 等），但由独立 Timer 驱动，可优化为统一 Tick。

**建议**：
- 统一 1s Timer tick，按各自间隔判断是否到期
- 降低总 CPU 开销

#### 4. 综合负载模型

**建议**：
- 计算公式：`CPU × 0.4 + GPU × 0.4 + 内存压力分 × 0.2`
  - 内存压力分：normal=0, warning=70, critical=100
- 负载等级：<35 idle、<65 working、<85 busy、≥85 stressed
- 用于菜单栏图标状态展示

---

## 三、全新功能建议（当前未规划）

### 🟡 高性价比增强

#### 5. 传感器温度监控（Thermal Sensors）

**说明**：macOS 通过 SMC (System Management Controller) 或 IOKit 可以读取多种温度传感器数据。

**建议新增**：
- **CPU 温度**：通过 SMC 读取 `TC0D`/`TC0E`/`TC0P` key
- **GPU 温度**：已在 GPU 监控中通过 `IOAccelerator` 的 `Temperature(C)` 获取 ✅
- **内存温度**：部分机型支持
- **主板温度**：`TM0P`/`Th` 等 key
- **SSD 温度**：通过 `IOAHCIBlockStorageDevice` 或 NVMe SMART 读取
- **风扇转速**：通过 SMC 读取 `F0Ac` (actual) 和 `F0Mn`/`F0Mx` (min/max)
- **风扇转速百分比**：可视化风扇负载

**API 参考**：
```swift
// 通过 IOKit 读取 SMC 温度传感器
IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
// 读取 SMC key: TC0D, TC0E, TM0P, Th0H 等

// 或通过 sysctl 读取部分温度
sysctlbyname("hw.sensors.cpu0.temperature", ...)

// 风扇转速
sysctlbyname("hw.fan0.actual_speed", ...)
```

**参考项目**：[osx-cpu-temp](https://github.com/lavoiesl/osx-cpu-temp)、[Stats 项目的 Sensors 模块](https://github.com/exelban/stats)

#### 6. 显示器信息（Display Info）

**说明**：显示器的分辨率、刷新率、HDR 状态等信息。

**建议新增**：
- **显示器型号/名称**：通过 `CGDisplay` API
- **分辨率**：当前分辨率及原生分辨率
- **刷新率**：当前刷新率
- **HDR 状态**：是否启用 HDR
- **亮度**：内置显示器亮度（已通过 DDC 控制插件实现外接显示器 ✅）
- **多显示器信息**：列出所有连接的显示器
- **色彩空间**：Display P3 / sRGB 等

**API 参考**：
```swift
import CoreGraphics

// 获取所有显示器
let displayIDs = CGGetActiveDisplayList(...)

// 获取显示器信息
CGDisplayBitsPerPixel, CGDisplayPixelsWide, CGDisplayPixelsHigh
CGDisplayRefreshRate(displayID)
CGDisplayCopyDisplayMode(displayID)

// HDR 状态（macOS 10.15+）
CGDisplayCopyColorSpace(displayID)
```

#### 7. 蓝牙设备信息

**说明**：已连接的蓝牙设备状态。

**建议新增**：
- **已连接蓝牙设备列表**：名称、类型、电量
- **蓝牙连接状态**：是否开启
- **电池设备电量**：AirPods、Magic Keyboard/Trackpad/Mouse 电量
- **蓝牙版本**：系统蓝牙版本信息

**API 参考**：
```swift
import IOBluetooth

// 获取已配对设备
IOBluetoothDevice.pairedDevices()

// 获取电池设备电量（通过 IOKit 读取 HID 设备电池）
IORegistryEntryCreateCFProperty(..., "BatteryPercent")
```

#### 8. Wi-Fi 详细信息

**说明**：当前 Wi-Fi 连接的详细信息。

**建议新增**：
- **SSID**：当前连接的 Wi-Fi 名称
- **信号强度 (RSSI)**：dBm 值
- **噪声**：环境噪声 dBm
- **信道**：当前信道号
- **安全类型**：WPA2/WPA3/WEP
- **BSSID**：接入点 MAC 地址
- **传输速率**：当前连接速率 (Mbps)
- **频段**：2.4GHz / 5GHz / 6GHz

**API 参考**：
```swift
// 使用 CoreWLAN 框架
import CoreWLAN

let client = CWInterface.interface()
client.ssid()           // SSID 名称
client.rssiValue()      // 信号强度 dBm
client.noiseMeasurement() // 噪声 dBm
client.wlanChannel()    // 信道信息
client.security()       // 安全类型
client.transmitRate()   // 传输速率
```

#### 9. 音频设备信息

**说明**：当前输入/输出音频设备信息。

**建议新增**：
- **当前输出设备**：名称、音量
- **当前输入设备**：名称、音量
- **系统音量**：当前音量百分比
- **静音状态**
- **输出设备列表**：所有可用输出设备
- **输入设备列表**：所有可用输入设备

**API 参考**：
```swift
import CoreAudio

// 获取默认输出设备
AudioObjectGetPropertyData(kAudioObjectSystemObject, ...)
// kAudioHardwarePropertyDefaultOutputDevice

// 获取设备音量
kAudioDevicePropertyVolumeScalar

// 或使用 simpler API
import MediaPlayer
MPVolumeView (但仅限 iOS，macOS 需要 CoreAudio)
```

#### 10. 应用使用时长（可选，需要 Accessibility 权限）

**说明**：统计各应用的使用时长，类似 Screen Time。

**建议新增**：
- **今日活跃应用时长**
- **应用前台/后台时间**
- **应用启动次数**

**注意**：此功能需要额外的系统权限，可能不适合作为 DeviceInfoPlugin 的核心功能。可考虑作为独立插件。

---

### 🟢 锦上添花

#### 11. 磁盘 I/O 监控

**说明**：磁盘读写速度监控。

**建议新增**：
- **读取速率** (MB/s)
- **写入速率** (MB/s)
- **IOPS**（每秒 IO 操作数）
- **磁盘活动指示灯**（菜单栏小图标）

**API 参考**：
```swift
// 通过 IOKit 读取磁盘 IO 统计
IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOBlockStorageDriver"))
// 读取 IOPropertyStatistics 中的 Reads/Writes 计数

// 或通过 sysctl
sysctlbyname("vm.vmstats", ...)  // 部分磁盘统计信息
```

#### 12. 通知中心信息

**说明**：当前通知中心状态和免打扰模式。

**建议新增**：
- **免打扰状态**（Focus 模式）
- **当前 Focus 模式名称**

**API 参考**：
```swift
// macOS 12+
import UserNotifications
UNUserNotificationCenter.current().getNotificationSettings { settings in
    // settings.authorizationStatus
}

// Focus 模式（macOS 12+）
// 通过 NSAppleScript 或私有 API 读取
```

#### 13. 系统更新状态

**说明**：检查 macOS 是否有可用更新。

**建议新增**：
- **当前 macOS 版本**：已实现 ✅ (`osVersion`)
- **可用更新**：是否有新系统版本可用
- **更新类型**：安全更新 / 功能更新

**API 参考**：
```swift
// 通过 SoftwareUpdate framework 或命令行
// /usr/sbin/softwareupdate --list
// 或使用 NSUserDefaults 读取系统更新状态
```

#### 14. 电源管理信息（Energy Saver）

**说明**：系统电源管理相关设置。

**建议新增**：
- **当前电源计划**：高性能 / 省电 / 自动
- **自动休眠设置**
- **显示器休眠时间**
- **硬盘休眠状态**
- **Power Nap 状态**（Intel Mac）
- **唤醒原因统计**

**API 参考**：
```swift
// 通过 IOPM (I/O Power Management)
IOPMCopyAssertionsByProcess()
IOPMCopyAssertionsStatus()

// 通过 pmset 命令读取
// pmset -g 或 pmset -g custom
```

---

## 四、功能优先级总结

| 优先级 | 功能 | 理由 |
|--------|------|------|
| 🔴 P0 | 内存增强（压力 + Swap） | 核心监控缺失，对用户体验影响大 |
| 🔴 P0 | 网络监控（接口 + IP + 流量） | 系统监控工具标配，技术成熟 |
| 🟡 P1 | 传感器温度（CPU/主板/SSD + 风扇） | 高价值信息，用户关注度高 |
| 🟡 P1 | Wi-Fi 详细信息 | 与网络监控互补，CoreWLAN API 成熟 |
| 🟡 P1 | 显示器信息 | 多显示器用户需要，API 简单 |
| 🟡 P1 | 蓝牙设备信息 | 低实现成本，实用性强 |
| 🟢 P2 | 磁盘 I/O 监控 | 锦上添花，需较多 IOKit 工作 |
| 🟢 P2 | 音频设备信息 | 信息展示价值，实现简单 |
| 🟢 P2 | 综合负载模型 | 提供概览视角 |
| 🟢 P2 | 差异化采样频率 | 性能优化 |
| 🔵 P3 | 通知中心/免打扰 | 价值有限 |
| 🔵 P3 | 系统更新状态 | 系统自带通知已覆盖 |
| 🔵 P3 | 电源管理信息 | 较少用户关注 |
| ❌ 不考虑 | 应用使用时长 | 需要额外权限，功能边界外 |

---

## 五、技术参考资源

| 资源 | 链接 |
|------|------|
| Apple IOKit 文档 | https://developer.apple.com/documentation/iokit |
| Apple System Configuration | https://developer.apple.com/documentation/systemconfiguration |
| CoreWLAN 框架 | https://developer.apple.com/documentation/corewlan |
| CoreGraphics 显示器 API | https://developer.apple.com/documentation/coregraphics/display_services |
| CoreAudio 框架 | https://developer.apple.com/documentation/coreaudio |
| Stats 项目（开源参考） | https://github.com/exelban/stats |
| hagimi-monitor（架构参考） | https://github.com/Acerola-1/hagimi-monitor |
| osx-cpu-temp（SMC 读取） | https://github.com/lavoiesl/osx-cpu-temp |

---

## 六、实现注意事项

### 架构适配
1. **保持现有架构**：新增 Service 单例（如 `NetworkService.swift`、`ThermalService.swift`），遵循现有模式
2. **复用现有模式**：单例 + `@Published` + Timer 驱动 + `Task.detached` 采样
3. **注意线程安全**：IOKit/SystemConfiguration 调用放在 `Task.detached` 中，结果回主线程发布

### 权限注意事项
- 新增 IOKit 读取功能需确认 `App.entitlements` 中是否已包含 `com.apple.security.iokit-user-client-class` 相关权限
- CoreWLAN 需要 Wi-Fi 硬件支持，在 Mac Studio/Mac Pro 等无 Wi-Fi 设备上 gracefully fallback
- 部分 SMC key 读取可能需要特殊权限

### 共享代码下沉
以下工具函数考虑下沉到 `DeviceMonitorKit` 或 `LumiCoreKit`：
- `bytesPerSecond(_:)` — 字节速率格式化
- `memoryBytes(_:)` — 内存大小格式化
- `wattString(_:)` — 功率格式化
- `doubleValue(_:)` / `intValue(_:)` — IOKit registry 值类型转换
- `registryStringValue(_:_)` / `registryDictionaryValue(_:_)` — IOKit 通用读取
