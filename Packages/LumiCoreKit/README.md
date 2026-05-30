# LumiCoreKit

LumiCoreKit contains the core plugin and message contracts shared across Lumi packages and plugin implementations.

## Features

- Plugin protocols such as `SuperPlugin`, `SuperSendMiddleware`, provider registrants, renderers, and lifecycle hooks.
- Chat and stream entities including `ChatMessage`, `StreamChunk`, roles, event types, and queue status.
- Runtime contexts for tools, layout, project state, message sending, and turn completion.
- Ordered middleware pipelines for send-message workflows.
- Bridge helpers for LLM provider models and tool result content.

## Usage

```swift
import LumiCoreKit

let message = ChatMessage(
    role: .user,
    conversationId: UUID(),
    content: "Hello"
)

print(message.shouldSendToLLM)
```

## Testing

```bash
swift test
```
