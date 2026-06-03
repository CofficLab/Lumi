# ScreenshotPlugin

Screenshot plugin for Lumi. Provides a sidebar toolbar button for region capture, with the captured image broadcast as a notification for chat attachment consumption.

## Features

- **Region capture** - fullscreen overlay with resizable selection rectangle
- **Sidebar toolbar button** - screenshot button in AI chat sidebar
- **Keyboard shortcut** - `Cmd+Shift+S` to trigger screenshot
- **Attachment integration** - captured images broadcast via notification for ChatAttachmentPlugin to consume
- **Loading state** - progress indicator during capture preparation

## Requirements

- macOS 14.0+
- Swift 6.0+

## Dependencies

| Package | Description |
|---------|-------------|
| [LumiCoreKit](../../Packages/LumiCoreKit) | Core framework for Lumi plugins |
| [LumiUI](../../Packages/LumiUI) | UI components |
| [SuperLogKit](../../Packages/SuperLogKit) | Logging framework |

## Usage

### As a Lumi Plugin

This plugin integrates with the Lumi application. It provides:

- **Sidebar Toolbar Button** - screenshot button in AI chat sidebar
- **Screenshot Overlay** - fullscreen selection overlay for region capture

## Policy

`.alwaysOn` - core screenshot attachment plugin that is always registered and cannot be disabled by users.

### Project Structure

```
Sources/
+-- ScreenshotPlugin.swift            # Plugin entry point and toolbar button
+-- ScreenshotOverlay.swift           # Fullscreen capture overlay
Tests/
+-- PluginScreenshotTests.swift       # Unit tests
```

## License

Proprietary. All rights reserved.
