# AliyunPlugin

LLM provider plugin for Lumi. Integrates **阿里云 DashScope Coding Plan**.

## Features

- **LLM Provider** — registers Aliyun in the model selector
- **Error renderers** — provider-specific UI for API Key missing, HTTP 401/403, and other request failures (same pattern as ZhipuPlugin)

## Error render kinds

| renderKind | UI |
|---|---|
| `aliyun-api-key-missing` | Inline API Key editor |
| `aliyun-http-401` | API Key editor (auth failure) |
| `aliyun-http-403` | HTTP 403 detail |
| `aliyun-http-{code}` | Generic HTTP error |
| `aliyun-request-failed` | Network / unknown failure |
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
