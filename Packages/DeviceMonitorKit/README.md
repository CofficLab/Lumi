# DeviceMonitorKit

可复用的 macOS 系统监控服务与模型包。提供 CPU、内存、进程与聚合系统指标采集，以及供 UI 展示近期趋势的短时历史数据。

## Package

- Product: `DeviceMonitorKit`
- Platform: macOS 14+
- Swift tools: 6.0

## Main APIs

- `DeviceMonitorKit.cpu`
- `DeviceMonitorKit.memory`
- `DeviceMonitorKit.process`
- `DeviceMonitorKit.systemMonitor`
- `DeviceMonitorKit.cpuHistory`
- `DeviceMonitorKit.memoryHistory`

These access shared service instances on the main actor.

## Source Layout

- `Models/`: CPU, memory, and monitor data models.
- `Services/`: metric collection and history services.

## Testing

From this package directory:

```sh
swift test
```

Tests cover model behavior and service-level monitoring logic.
