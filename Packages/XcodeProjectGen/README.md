# XcodeProjectGen

XcodeProjectGen generates Xcode projects from a declarative Swift model.

## Features

- `XcodeProjectSpec` and target models for apps, frameworks, libraries, tests, extensions, and tools.
- Build setting helpers for bundle identifiers, signing, deployment targets, Swift settings, and custom keys.
- Local, remote Swift Package, target, and system framework dependencies.
- File-system resolver for discovering Swift sources and resource files.
- `.xcodeproj` generation through XcodeProj with optional shared scheme generation.

## Usage

```swift
import XcodeProjectGen

let spec = XcodeProjectSpec(
    name: "MyApp",
    targets: [
        .app(
            name: "MyApp",
            platform: .iOS,
            deploymentTarget: "17.0",
            sources: ["Sources/MyApp"],
            settings: [.bundleIdentifier("com.example.MyApp")]
        )
    ]
)

let path = try XcodeProjectGenerator().generate(spec: spec, projectRoot: "/path/to/project")
print(path)
```

## Testing

```bash
swift test
```
