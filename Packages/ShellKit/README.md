# ShellKit

可复用的异步 Shell 命令执行工具包。封装 `Process`，提供 async/await API、流式输出回调、超时与取消，以及结构化结果。

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
