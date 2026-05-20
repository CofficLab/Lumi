# DockerKit

可复用的 Docker 领域模型与服务逻辑包。提供 Docker 相关类型定义与面向命令的服务行为，供宿主应用或插件复用。

## Package

- Product: `DockerKit`
- Platform: macOS 14+
- Swift tools: 6.0

## Source Layout

- `Models/DockerModels.swift`: Docker domain models.
- `Services/DockerService.swift`: Docker service operations.

## Testing

From this package directory:

```sh
swift test
```

Tests cover Docker models and service behavior. Prefer mocked command execution for new tests unless a test explicitly needs a local Docker daemon.

## Host integration

Keep Docker UI, user confirmations, and plugin registration in the host app. Put command parsing, Docker state models, and reusable service behavior in this package.
