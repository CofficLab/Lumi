# WorkspaceFileKit

WorkspaceFileKit provides small, testable file-system utilities for Lumi workspace operations.

## Features

- Resolve plain paths, tilde paths, and file URLs into local file URLs.
- Read UTF-8 text files with truncation support.
- Read supported image files with MIME type detection.
- Report non-UTF-8 files without throwing when the file is not a supported image.
- Write text files while creating parent directories.
- Edit files by replacing unique or all matching strings.
- List directories with hidden-file filtering and recursive truncation.

## Usage

```swift
import WorkspaceFileKit

try WorkspaceFileWriter().write(path: "/tmp/example.txt", content: "hello")

let result = try WorkspaceFileReader().read(path: "/tmp/example.txt")
print(result)
```

## Testing

```bash
swift test
```
