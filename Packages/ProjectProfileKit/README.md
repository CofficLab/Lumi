# ProjectProfileKit

ProjectProfileKit builds a lightweight technical profile for a local project directory.

## Features

- Detects likely primary language from common manifests and source files.
- Extracts dependencies from Swift Package, package.json, Podfile, Go, Rust, Python, and related project files.
- Detects frameworks such as SwiftUI, React, Vue, Vite, Electron, and other common stacks.
- Infers high-level project type such as web, mobile, CLI, SDK, app, or unknown.
- Reads README content for a short description and keywords.

## Usage

```swift
import ProjectProfileKit

let profiler = ProjectProfiler()
if let profile = profiler.profile(projectPath: "/path/to/project") {
    print(profile.shortTitle)
    print(profile.projectType.rawValue)
}
```

## Testing

```bash
swift test
```
