# MCPKit

MCPKit provides Model Context Protocol client integration for Lumi.

## Features

- `MCPServerConfig` models for stdio and SSE server definitions.
- `MCPService` for connecting configured servers and publishing discovered tools.
- Stdio subprocess transport for local MCP servers.
- SSE transport for remote MCP servers.
- Tool name adaptation for Lumi tool routing.

## Usage

```swift
import MCPKit

let config = MCPServerConfig(
    name: "filesystem",
    command: "npx",
    args: ["-y", "@modelcontextprotocol/server-filesystem"],
    env: [:]
)

let service = MCPService(configs: [config])
await service.connectAll()
```

## Testing

```bash
swift test
```
