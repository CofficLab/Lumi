# AliyunPlugin

LLM provider plugin for Lumi. Integrates **阿里云** — Aliyun Qwen Models.

## Features

- **LLM Provider** — registers 阿里云 in the model selector
- **Model catalog** — provides available models for 阿里云
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
- **Request Handling** — sends chat completion requests to 阿里云
- **Configuration** — API key and endpoint settings

## License

Proprietary. All rights reserved.
