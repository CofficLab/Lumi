# TerminalCoreKit

Terminal session core for Lumi.

`TerminalCoreKit` wraps terminal session state, SwiftTerm-based rendering, shell integration, theme adaptation, and tab management for app terminal surfaces.

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
- `LumiTerminalView`: SwiftUI-facing terminal view.
- `TerminalShellIntegration`: shell integration and prompt/status parsing.

## Testing

From this package directory:

```sh
swift test
```

Prefer unit tests for parsing and state transitions. UI and pseudo-terminal behavior may require focused integration tests.
