# MiniMaxPlugin

LLM provider plugin for Lumi. Integrates **MiniMax Token Plan** (the unified subscription plan from MiniMax / MiniMax).

## Features

- **LLM Provider** — registers MiniMax Token Plan in the model selector
- **Anthropic-compatible API** — talks to `https://api.minimaxi.com/anthropic` via `AnthropicCompatibleLumiProvider`
- **Error renderers** — provider-specific UI for API Key missing, HTTP 401/403, and other request failures
- **Streaming support** — SSE streaming for real-time token output
- **Settings integration** — API key configuration via Lumi settings

## Models

The Token Plan bundle currently includes:

| Model | Tools | Vision | Notes |
|-------|-------|--------|-------|
| `MiniMax-M2.7` | ✅ | ✅ | Default model; flagship coding & agent model |
| `MiniMax-M2.7-highspeed` | ✅ | ✅ | Faster variant for the same quota |
| `MiniMax-M2.5` | ✅ | ❌ | Previous-generation model |
| `MiniMax-M2` | ✅ | ❌ | Older generation model |
| `MiniMax-Text-01` | ❌ | ❌ | Long-context text model (4M tokens) |

International users can switch the endpoint to `https://api.minimax.io/anthropic` via the `additionalHeaders` field — same Anthropic-compatible contract.

## Error render kinds

| renderKind | UI |
|---|---|
| `minimax-api-key-missing` | Inline API Key editor |
| `minimax-http-401` | API Key editor (auth failure) |
| `minimax-http-403` | HTTP 403 detail |
| `minimax-http-{code}` | Generic HTTP error |
| `minimax-request-failed` | Network / unknown failure |

## Requirements

- macOS 14.0+
- Swift 6.0+

## Dependencies

| Package | Description |
|---------|-------------|
| [LumiCoreKit](../../Packages/LumiCoreKit) | Core framework for Lumi plugins |
| [LumiLLMProviderSupport](../../Packages/LumiLLMProviderSupport) | Provider protocols + Anthropic-compatible adapter |
| [HttpKit](../../Packages/HttpKit) | HTTP / SSE client |
| [LumiUI](../../Packages/LumiUI) | Theme + UI primitives |

## License

Proprietary. All rights reserved.