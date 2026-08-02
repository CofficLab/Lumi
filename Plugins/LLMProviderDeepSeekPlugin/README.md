# DeepSeekPlugin

LLM provider plugin for Lumi. Integrates **DeepSeek** — DeepSeek AI.

## Features

- **LLM Provider** — registers DeepSeek in the model selector
- **Model catalog** — provides available models for DeepSeek
- **Streaming support** — SSE streaming for real-time token output
- **Settings integration** — API key configuration via Lumi settings

## Requirements

- macOS 14.0+
- Swift 6.0+

## Dependencies

| Package | Description |
|---------|-------------|
| [LumiKernel](../../Packages/LumiKernel) | Core framework and provider protocol |
| [HttpKit](../../Packages/HttpKit) | HTTP and SSE transport |
| [KeychainKit](../../Packages/KeychainKit) | API key storage |
| [LocalizationKit](../../Packages/LocalizationKit) | Localization support |

DeepSeek request encoding, streaming parsing, tool-call handling, and cache
usage parsing are implemented locally in this plugin. It does not depend on
the generic `LLMKit` OpenAI-compatible layer.

## Usage

### As a Lumi Plugin

This plugin integrates with the Lumi application. It provides:

- **LLM Provider Registration** — available models appear in the model selector
- **Request Handling** — sends chat completion requests to DeepSeek
- **Configuration** — API key and endpoint settings

## License

Proprietary. All rights reserved.
