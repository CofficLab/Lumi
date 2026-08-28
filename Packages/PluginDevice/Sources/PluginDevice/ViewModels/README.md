# ViewModels

视图模型层：为视图提供可观察状态，持有服务引用并驱动订阅/刷新逻辑。
命名约定：`*ManagerViewModel.swift` 或 `*ContentViewModel.swift`。

| 文件 | 职责 |
| --- | --- |
| `CPUManagerViewModel.swift` | CPU 详情页数据状态 |
| `GPUManagerViewModel.swift` | GPU 详情页数据状态 |
| `MemoryManagerViewModel.swift` | 内存详情页数据状态 |
| `BatteryManagerViewModel.swift` | 电池详情页数据状态 |
| `SystemMonitorViewModel.swift` | 系统监控聚合页数据状态 |
| `DeviceInfoMenuBarContentViewModel.swift` | 菜单栏 CPU/内存柱状图的共享 ViewModel（含快照与指标模型） |
