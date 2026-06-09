# LumiChatKit

Core chat engine and persistence layer for the Lumi app.

Current surface:

- `ChatService` — main chat engine with agent loop, tool execution, and LLM streaming
- `ChatConfiguration` — database configuration
- `ChatStore` — SwiftData persistence layer
- `ConversationStatusState` — per-conversation transient status messages
- `ChatPanelSection` — plugin section identifier
- `ChatEntities` — SwiftData models (`Conversation`, `ChatMessageEntity`, `ChatStateEntity`, etc.)
- `ToolLoopLimitCheck` — built-in turn check that terminates runaway tool loops
