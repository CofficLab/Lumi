# MemoryKit

MemoryKit contains Lumi's file-backed memory storage and local retrieval logic.

## Features

- Memory models for user, feedback, project, and reference memories.
- Global and project-scoped memory storage.
- Markdown file CRUD with `MEMORY.md` index maintenance.
- Local keyword retrieval with type weighting, recency decay, and hit density scoring.
- Staleness warnings for older memory entries.

## Usage

```swift
import MemoryKit

let root = URL(fileURLWithPath: "/tmp/lumi-memory")
let storage = MemoryStorageService(rootURL: root)

let item = try await storage.createMemory(
    id: "user-role",
    type: .user,
    name: "User Role",
    description: "Backend developer",
    content: "Prefers concise implementation notes.",
    scope: .global
)

print(item.formattedSummary())
```

## Testing

```bash
swift test
```
