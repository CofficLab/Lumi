# ShellKit

Async shell command execution utilities for Lumi.

`ShellKit` wraps `Process` with async/await APIs, streaming output callbacks, timeout handling, cancellation behavior, and structured results.

## Package

- Product: `ShellKit`
- Platform: macOS 14+
- Swift tools: 5.9

## Basic Usage

```swift
import ShellKit

let result = try await ShellExecutor.execute("git status")
print(result.stdout)
```

With explicit options:

```swift
let result = try await ShellExecutor.execute(
    "npm install",
    options: ShellOptions(workingDirectory: "/path/to/project", timeout: 60)
)
```

For streaming output:

```swift
let result = try await ShellExecutor.executeStreaming(
    "swift test",
    onOutput: { print($0) },
    onError: { print($0) }
)
```

## Main Types

- `ShellExecutor`
- `ShellOptions`
- `ShellResult`
- `ShellError`

## Testing

From this package directory:

```sh
swift test
```

Prefer deterministic commands in tests, and avoid depending on user-specific shell configuration.
