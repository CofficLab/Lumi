# Services

服务层：系统数据采集与历史记录服务，多为 `ObservableObject` + 单例（`shared`），
被 ViewModel / 视图订阅。命名约定：`*Service.swift`。

| 文件 | 职责 |
| --- | --- |
| `CPUService.swift` | CPU 占用、每核占用、负载均值实时采集 |
| `CPUHistoryService.swift` | CPU 历史记录持久化与查询 |
| `MemoryService.swift` | 内存占用实时采集 |
| `MemoryHistoryService.swift` | 内存历史记录持久化（存储目录由插件入口配置） |
| `LumiMemoryService.swift` | Lumi 专用内存历史（旧版语义兼容） |
| `GPUService.swift` | GPU 占用实时采集 |
| `GPUHistoryService.swift` | GPU 历史记录持久化与查询 |
| `BatteryService.swift` | 电池电量与充电状态实时采集 |
| `BatteryHistoryService.swift` | 电池历史记录持久化与查询 |
| `StorageService.swift` | 磁盘容量与卷信息采集 |
| `ProcessService.swift` | 系统进程列表与 CPU/内存占用排序 |
| `SystemMonitorService.swift` | 系统监控聚合服务（组合各硬件指标） |
