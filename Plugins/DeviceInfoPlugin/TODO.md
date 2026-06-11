# DeviceInfoPlugin 功能路线图

基于 [hagimi-monitor](https://github.com/Acerola-1/hagimi-monitor) 的功能对比分析，列出值得吸收的功能。

---

## 🔴 P0 — 核心缺失功能

### 1. GPU 监控

> 参考来源：`hagimi-monitor/HagimiMonitor/Samplers/GPUSampler.swift`

- [x] 通过 `IOAccelerator` IOKit 服务读取 `PerformanceStatistics` 字典
- [x] GPU 使用率（`Device Utilization %` 或 `GPU Activity(%)`）
- [x] 渲染器使用率（`Renderer Utilization %`）
- [x] 分块器使用率（`Tiler Utilization %`）
- [x] GPU 显存使用（`In use system memory` / `Alloc system memory`）
- [x] GPU 温度（`Temperature(C)`）
- [x] GPU 型号识别（`model` / `IOClass` registry 属性）
- [x] 多 GPU 场景：取使用率最高的 GPU 数据
- [x] GPU 历史趋势图
- [x] 创建 `GPUService.swift`（参照 `CPUService.swift` 的单例+发布者模式）

关键技术点：
```
IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &iterator)
→ IORegistryEntryCreateCFProperty(service, "PerformanceStatistics", ...)
→ 读取字典中的利用率、显存、温度等字段
```

### 2. 电池增强监控

> 参考来源：`hagimi-monitor/HagimiMonitor/Samplers/BatterySampler.swift`

- [x] 通过 `AppleSmartBattery` IOKit 服务读取 SMC 电池数据
- [x] 适配器功率（`AdapterDetails` → `Watts`）
- [x] 系统总功耗（`PowerTelemetryData` → `SystemPowerIn`，单位 mW → W）
- [x] 充电功率（`PowerTelemetryData` → `BatteryPower`，负值表示充电中）
- [x] 电池健康度（`MaxCapacity / DesignCapacity × 100`）
- [x] 电池循环次数（`CycleCount`）
- [x] 电池温度（`Temperature / 100`，原始值单位 0.01°C）
- [x] 供电状态细化（电池供电 / 外接电源 / 充电中）
- [x] 无电池设备（台式机）的外接电源显示
- [x] 功耗格式化工具（`wattString`、`wattStringAllowZero`）

关键技术点：
```
IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
→ 读取 Registry 属性：CycleCount, DesignCapacity, MaxCapacity, Voltage, Amperage, Temperature
→ PowerTelemetryData 字典：SystemPowerIn, BatteryPower
→ IOPSCopyExternalPowerAdapterDetails() → 适配器功率
```

---

## 🟡 P1 — 高性价比增强

### 3. 内存增强（压力等级 + Swap）

> 参考来源：`hagimi-monitor/HagimiMonitor/Samplers/MemorySampler.swift`

- [ ] 内存压力等级检测（`kern.memorystatus_vm_pressure_level` sysctl）
  - normal（值 0-1）→ "正常"
  - warning（值 2）→ "偏高"
  - critical（值 4）→ "严重"
- [ ] Swap 使用量（`vm.swapusage` sysctl → `xsw_usage.xsu_used`）
- [ ] 更精确的内存使用计算公式：
  - 当前：`active + wired + compressed`
  - 改进：`active + inactive + speculative + wired + compressed - purgeable - external`
- [ ] 内存压力等级在 UI 中可视化（正常/偏高/严重状态色）

关键技术点：
```swift
// 内存压力等级
sysctlbyname("kern.memorystatus_vm_pressure_level", &pressureLevel, &size, nil, 0)

// Swap 使用量
sysctlbyname("vm.swapusage", &usage, &size, nil, 0)  // xsw_usage 结构体
```

### 4. 外置存储卷检测

> 参考来源：`hagimi-monitor/HagimiMonitor/Samplers/StorageSampler.swift`

- [ ] 扫描所有挂载卷（`FileManager.default.mountedVolumeURLs`）
- [ ] 用 `volumeIsInternal == false` 过滤外置卷
- [ ] 显示每个外置卷的：名称、已用、可用、总量、使用百分比
- [ ] 最多显示 3 个外置卷（避免面板过高）
- [ ] 外置卷独立展示区域（带外置硬盘图标）

关键技术点：
```swift
FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: [
    .volumeTotalCapacityKey, .volumeAvailableCapacityKey,
    .volumeNameKey, .volumeIsInternalKey, .volumeIsEjectableKey
], options: [])
```

---

## 🟢 P2 — 锦上添花

### 5. 网络增强（接口名称 + IP 地址）

> 参考来源：`hagimi-monitor/HagimiMonitor/Samplers/NetworkSampler.swift`

- [ ] 活动网络接口识别（按流量最大的接口判定）
- [ ] 接口友好名称映射：en0→Wi-Fi、en*→以太网、bridge*→桥接、pdp_ip*→蜂窝
- [ ] IP 地址读取（IPv4/IPv6，过滤 `fe80:` 链路本地地址）
- [ ] 虚拟接口过滤（忽略 lo0、utun*、awdl*）
- [ ] 网络接口名和 IP 在弹出面板中展示

### 6. CPU 增强（系统运行时间）

> 参考来源：`hagimi-monitor/HagimiMonitor/Samplers/CPUSampler.swift`

- [ ] 系统启动时间（`KERN_BOOTTIME` sysctl → 计算运行时长）
- [ ] CPU 使用率细分：系统/用户/闲置占比（当前只有总使用率和每核使用率）
- [ ] 运行时长格式化（"3天 2小时"）

关键技术点：
```swift
var mib = [CTL_KERN, KERN_BOOTTIME]
sysctl(&mib, 2, &bootTime, &size, nil, 0)
// Date() - Date(timeIntervalSince1970: bootTime.tv_sec) → 运行时长
```

### 7. 差异化采样频率

> 参考来源：`hagimi-monitor/HagimiMonitor/MonitorModels.swift` → `MonitorRefreshSchedule`

- [ ] 不同模块使用不同采样间隔，降低 CPU 开销：
  - CPU: 1s
  - GPU: 2s
  - 内存: 3s
  - 网络: 1s
  - 存储: 10s
  - 电池: 5s
- [ ] 统一 Timer tick（1s），按各自间隔判断是否到期

### 8. 综合负载模型

> 参考来源：`hagimi-monitor/HagimiMonitor/MonitorModels.swift` → `ComputeLoadModel`

- [ ] 综合负载计算：`CPU × 0.4 + GPU × 0.4 + 内存压力分 × 0.2`
  - 内存压力分：normal=0, warning=70, critical=100
- [ ] 负载等级判定：<35 idle、<65 working、<85 busy、≥85 stressed
- [ ] 用于菜单栏图标状态展示参考

---

## 🔵 P3 — 独立功能（适合做成单独插件）

### 9. 显示器 DDC 控制

> 参考来源：`hagimi-monitor/HagimiMonitorDirectOnly/DisplayDDCBridge.swift` + `DisplayControlsSection.swift`

- [ ] 外接显示器亮度控制（DDC VCP 0x10 luminance）
- [ ] 外接显示器音量控制（DDC VCP 0x62 audioSpeakerVolume + 0x8D mute）
- [ ] 外接显示器对比度控制（DDC VCP 0x12 contrast）
- [ ] 内置显示器亮度（`DisplayServicesGetBrightness` / `DisplayServicesSetBrightness`）
- [ ] Apple Silicon DDC 服务匹配（`Arm64DDCMatcher`，基于 EDID UUID + IORegistry 路径匹配）
- [ ] I2C 通信封装（`IOAVServiceWriteI2C` / `IOAVServiceReadI2C`）
- [ ] 滑块 UI（亮度/音量/对比度 Slider）
- [ ] 防抖写入（150ms debounce，避免 DDC 过载）
- [ ] 不支持的控制项灰显处理

**建议**：此功能复杂度高、独立性强，适合作为 `DisplayControlPlugin` 单独插件开发。

---

## 📐 实现注意事项

### 架构适配

hagimi-monitor 使用 `MonitorSampler` 协议 + `MonitorModule` 统一数据模型，我们的插件使用独立的 Service 单例模式（`CPUService`、`MemoryService`、`SystemMonitorService`）。吸收功能时应：

1. **保持现有架构**：新增 `GPUService.swift` 而非引入 hagimi 的 `MonitorSampler` 协议
2. **复用现有模式**：单例 + `@Published` + Timer 驱动 + `Task.detached` 采样
3. **注意线程安全**：IOKit 调用放在 `Task.detached` 中，结果回主线程发布

### 共享代码下沉

以下工具函数可能被多个插件使用，考虑下沉到 `DeviceMonitorKit`（目前为空目录）或 `LumiCoreKit`：

- `bytesPerSecond(_:)` — 字节速率格式化
- `memoryBytes(_:)` — 内存大小格式化
- `wattString(_:)` — 功率格式化
- `doubleValue(_:)` / `intValue(_:)` — IOKit registry 值类型转换
- `registryStringValue(_:_)` / `registryDictionaryValue(_:_)` — IOKit 通用读取

### IOKit 权限

新增 IOKit 读取功能需确认 `App.entitlements` 中是否已包含 `com.apple.security.iokit-user-client-class` 相关权限。
