# CodexPlugin

LLM provider plugin for Lumi. Integrates **Codex CLI** — 通过 Codex CLI 使用 OpenAI 模型（ChatGPT 账号认证）.

## Features

- **LLM Provider** — registers Codex CLI in the model selector
- **Model catalog** — provides available models for Codex CLI
- **Streaming support** — SSE streaming for real-time token output
- **Settings integration** — API key configuration via Lumi settings

## Requirements

- macOS 14.0+
- Swift 6.0+

## Dependencies

| Package | Description |
|---------|-------------|
| [LumiCoreKit](../../Packages/LumiCoreKit) | Core framework for Lumi plugins |
| [LLMKit](../../Packages/LLMKit) | LLM service abstractions |
| [LLMProviderKit](../../Packages/LLMProviderKit) | LLM provider protocol definitions |
| [SuperLogKit](../../Packages/SuperLogKit) | Logging framework |

## Usage

### As a Lumi Plugin

This plugin integrates with the Lumi application. It provides:

- **LLM Provider Registration** — available models appear in the model selector
- **Request Handling** — sends chat completion requests to Codex CLI
- **Configuration** — API key and endpoint settings

## License

Proprietary. All rights reserved.
