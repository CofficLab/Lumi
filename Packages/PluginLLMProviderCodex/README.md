# CodexPlugin

LLM provider plugin for Lumi. Integrates **Codex CLI** — 通过 Codex CLI 使用 OpenAI 模型（ChatGPT 账号认证）.

> **重要规则：本插件包不能依赖其他插件包，也不能被其他插件包依赖。**
>
> 插件之间只通过 Provider 契约通信：共享能力放入 `Provider*` / `Kit*` 包，
> 由宿主（`Factory*`）统一装配；跨插件互相引用会破坏插件的独立装配与卸载。

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

