# NetworkManagerPlugin

Real-time monitoring of network speed, traffic, and connection status for Lumi.

## Features

- **Real-time network speed monitoring** — upload and download speeds displayed in the menu bar
- **Traffic history** — historical data visualization for network usage
- **Connection status** — monitor network connectivity in real time
- **Menu bar integration** — lightweight status view and expanded popup view
- **Dashboard view** — comprehensive network monitoring dashboard

## Requirements

- macOS 14.0+
- Swift 6.0+

## Dependencies

| Package | Description |
|---------|-------------|
| [HttpKit](../../Packages/HttpKit) | HTTP utilities |
| [LumiCoreKit](../../Packages/LumiCoreKit) | Core framework for Lumi plugins |
| [LumiUI](../../Packages/LumiUI) | UI components |
| [ShellKit](../../Packages/ShellKit) | Shell command utilities |
| [SuperLogKit](../../Packages/SuperLogKit) | Logging framework |

## Usage

### As a Lumi Plugin

This plugin integrates with the Lumi application. It provides:

- **Menu Bar Content View** — compact network speed display
- **Menu Bar Popup View** — detailed network information
- **Dashboard View** — full network monitoring panel

### Enable/Disable

The plugin starts monitoring when enabled and stops when disabled:

```swift
NetworkManagerPlugin.shared.onEnable()   // Start monitoring
NetworkManagerPlugin.shared.onDisable()  // Stop monitoring
```

## Project Structure

```
Sources/
├── NetworkManagerPlugin.swift      # Plugin entry point
├── Controllers/                     # View controllers
├── Extensions/                      # Swift extensions
├── Models/                          # Data models
├── ProcessNetworkMonitor/           # Process-level network monitoring
├── Resources/                       # Assets and localization
├── Services/                        # Network services
├── ViewModels/                      # View models
└── Views/                           # SwiftUI views
Tests/
└── NetworkManagerPluginTests/       # Unit tests
```

## License

Proprietary. All rights reserved.
