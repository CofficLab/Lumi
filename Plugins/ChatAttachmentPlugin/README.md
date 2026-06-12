# ChatAttachmentPlugin

Chat attachment plugin for Lumi. Provides pending image attachment previews, image upload entry points, and right sidebar drag-and-drop handling for AI chat conversations.

## Features

- **Pending attachment previews** - shows image thumbnails that are queued for the current chat
- **Attachment removal** - lets users remove pending images before sending
- **Image upload button** - adds an `Upload Image` toolbar item in the AI chat sidebar
- **Sidebar drag and drop** - accepts image files dropped onto the right sidebar
- **File path fallback** - appends non-image dropped file paths to the chat draft
- **Screenshot integration hooks** - exposes runtime handlers for screenshot image data

## Requirements

- macOS 14.0+
- Swift 6.0+

## Dependencies

| Package | Description |
|---------|-------------|
| [AgentToolKit](../../Packages/AgentToolKit) | Chat attachment model types |
| [LumiCoreKit](../../Packages/LumiCoreKit) | Plugin protocol and chat view model integration |
| [LumiUI](../../Packages/LumiUI) | Shared Lumi UI components and theming |
| [SuperLogKit](../../Packages/SuperLogKit) | Logging framework |

## UI Contributions

| Method | Description |
|--------|-------------|
| `addSidebarSections` | Adds the pending attachment preview section for AI chat contexts |
| `wrapRightSidebarRoot` | Wraps the right sidebar with image/file drop handling |
| `addSidebarLeadingToolbarItems` | Adds the image upload toolbar item |
| `addSidebarToolbarItemView` | Renders the image upload toolbar button |

## Policy

`.alwaysOn` - core chat attachment UI plugin that is always registered and cannot be disabled by users.

## Project Structure

```text
Sources/
+-- ChatAttachmentPlugin.swift        # Plugin entry point and upload toolbar button
+-- ChatAttachmentRuntime.swift       # Runtime callbacks used by the host app
+-- ChatAttachmentDropRules.swift     # File URL parsing and image file detection
+-- Views/
    +-- AttachmentPreviewView.swift
    +-- ChatAttachmentDropRootView.swift
    +-- ChatAttachmentSectionView.swift
Tests/
+-- PluginChatAttachmentTests.swift
```

## Testing

```bash
swift test
```

## License

Proprietary. All rights reserved.
