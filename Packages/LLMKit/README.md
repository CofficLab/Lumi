# LLMKit

LLMKit contains the shared LLM service primitives used by Lumi.

## Features

- Validated `LLMConfig` values for provider, model, API key, temperature, and max tokens.
- `LLMProviderInfo` metadata for provider registries and model selection.
- `LLMAPIService` wrappers around `HttpKit` for JSON and streaming chat requests.
- `StreamingState` for accumulating streamed content, thinking text, tool calls, token usage, stop reasons, and time-to-first-token.
- User-facing `LLMServiceError` cases for validation and request failures.

## Usage

```swift
import LLMKit

let config = LLMConfig(
    apiKey: "sk-...",
    model: "gpt-4o",
    providerId: "openai",
    temperature: 0.7
)

try config.validate()
```

## Testing

```bash
swift test
```
