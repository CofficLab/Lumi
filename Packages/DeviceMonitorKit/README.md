# DeviceMonitorKit

System monitoring services and models for Lumi.

`DeviceMonitorKit` provides reusable macOS monitoring logic for CPU, memory, process, and aggregate system metrics. It also includes short history services used by UI surfaces that need recent metric trends.

## Package

- Product: `DeviceMonitorKit`
- Platform: macOS 14+
- Swift tools: 6.0
- Dependency: `MagicKit`

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

The tests cover model behavior and service-level monitoring logic.
