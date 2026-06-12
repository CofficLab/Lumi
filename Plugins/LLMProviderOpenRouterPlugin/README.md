# OpenRouterPlugin

LLM provider plugin for Lumi. Integrates **OpenRouter** — Multi-Provider LLM Router.

## Features

- **LLM Provider** — registers OpenRouter in the model selector
- **Model catalog** — provides available models for OpenRouter
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
- **Request Handling** — sends chat completion requests to OpenRouter
- **Configuration** — API key and endpoint settings

## License

Proprietary. All rights reserved.
