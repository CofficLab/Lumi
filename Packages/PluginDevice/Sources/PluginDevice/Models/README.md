# Models

纯数据模型层：只包含 `struct` / `enum` 数据定义，不含业务逻辑与服务。

| 文件 | 职责 |
| --- | --- |
| `BatteryModels.swift` | 电池电源状态、充电状态、读数与历史数据点 |
| `CPUModels.swift` | CPU 时间范围与历史数据点 |
| `GPUModels.swift` | GPU 时间范围、读数与历史数据点 |
| `MemoryModels.swift` | 内存时间范围与历史数据点 |
| `MonitorModels.swift` | 系统监控聚合模型（系统指标、资源占用、网络、磁盘、进程） |
| `StorageModels.swift` | 磁盘卷信息模型 |
| `DeviceData.swift` | 设备信息聚合数据源（`@MainActor ObservableObject`，含定时刷新） |
