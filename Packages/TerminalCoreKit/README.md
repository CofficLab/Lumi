# TerminalCoreKit

可复用的终端会话核心包。封装基于 SwiftTerm 的终端渲染、Shell 集成、主题适配与多标签会话管理。

## Package

- Product: `TerminalCoreKit`
- Platform: macOS 14+
- Swift tools: 5.9
- Dependency: `SwiftTerm`

## Source Layout

- `Core/`: terminal view, shell integration, and theme adaptation.
- `ViewModels/`: terminal session and tabs view models.
- `Views/`: reusable terminal session container views.

## Main Concepts

- `TerminalSession`: owns one terminal process/session state.
- `TerminalTabsViewModel`: coordinates multiple terminal sessions.
- `LumiTerminalView`: SwiftUI/AppKit terminal view wrapper.
- `TerminalShellIntegration`: shell integration and prompt/status parsing.

## Testing

From this package directory:

```sh
swift test
```

Prefer unit tests for parsing and state transitions. UI and pseudo-terminal behavior may require focused integration tests.
