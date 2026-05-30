# OpenInKit

OpenInKit contains Lumi's helpers for opening files, folders, and URLs in external macOS applications.

## Features

- `OpenAppType` metadata for editors, browsers, Finder, Terminal, Preview, TextEdit, and GitHub Desktop.
- Bundle identifier lookup and installed-app checks through an injectable workspace abstraction.
- URL routing for browser, Finder selection, and explicit app opening.
- Real app icon resolution on macOS with SF Symbol fallbacks.
- Testable `WorkspaceOpening` protocol for avoiding real `NSWorkspace` side effects in unit tests.

## Usage

```swift
import OpenInKit

let project = URL(fileURLWithPath: "/path/to/project")
project.openIn(.xcode)

let url = URL(string: "https://example.com")!
url.open()
```

## Testing

```bash
swift test
```
