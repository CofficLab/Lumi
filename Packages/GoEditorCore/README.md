# GoEditorCore

GoEditorCore provides the Go-specific editor domain logic used by Lumi.

## Features

- Detects Go modules and optional `go.work` workspaces.
- Resolves Go toolchain paths and process environment values.
- Builds standard `go build`, `go test`, `go fmt`, and `go mod tidy` command descriptors.
- Parses Go build output and `go test -json` events.
- Provides lightweight completion, inlay hint, code lens, format-on-save, and Delve launch helpers.

## Usage

```swift
import GoEditorCore

if let project = GoProjectDetector.findProject(from: "/path/to/app/main.go") {
    print(project.rootPath)
}

let command = GoTestCommand.allPackagesJSON
print(command.command, command.arguments)
```

## Testing

```bash
swift test
```
