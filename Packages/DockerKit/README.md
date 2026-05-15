# DockerKit

Docker models and service logic for Lumi.

`DockerKit` contains reusable Docker domain types and command-facing service behavior. It is the core package for Docker-related app plugins and views.

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

The tests cover Docker models and service behavior. Prefer mocked command execution for new tests unless a test explicitly needs a local Docker daemon.

## App Integration

Keep Docker UI, user confirmations, and plugin registration in the app target. Put command parsing, Docker state models, and reusable service behavior in this package.
