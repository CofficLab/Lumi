# LLMProviderKimiCodePlugin

Kimi Code LLM Provider Plugin for Lumi.

## Overview

This plugin provides Kimi Code API integration for Lumi, supporting both OpenAI-compatible and Anthropic-compatible endpoints.

## Features

- **Two Provider Implementations**:
  - `kimi-code-openai`: OpenAI-compatible endpoint
  - `kimi-code-anthropic`: Anthropic-compatible endpoint

- **Available Models**:
  - `k3` (default, supports low / high / max thinking intensity)
  - `kimi-for-coding`
  - `kimi-for-coding-highspeed`

## Configuration

Both providers share the same API Key storage key (`DevAssistant_ApiKey_KimiCode`), so users only need to configure the API Key once.

## API Endpoints

- OpenAI: `https://api.kimi.com/coding/v1/chat/completions`
- Anthropic: `https://api.kimi.com/coding/v1/messages`

## License

See the main Lumi project license.