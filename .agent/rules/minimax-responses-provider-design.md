# MiniMax Responses API Provider Design

## Overview
New LumiLLMProvider implementing MiniMax's OpenAI Responses API (`POST /v1/responses`).

## Key Design Decisions

### Model Capabilities
- `MiniMax-M3`: `thinkingAndReasoning: .levels` (supports minimal/low/medium/high effort)
- All other models: `thinkingAndReasoning: nil` (no reasoning control)

### Request Format
- `input`: `String` for simple text, `[InputItem]` for conversation history
- `reasoning.effort`: `minimal|low|medium|high|none` (M3 only; maps from `LumiReasoningEffort`)
- Tools: OpenAI-style `type: "function"` function definitions

### Response Parsing (Streaming SSE)
Events: `text_delta`, `reasoning_delta`, `function_call`, `done`

### Token Usage
From final response `usage` object: `input_tokens`, `output_tokens`

## Files to Create
1. `Sources/Providers/MiniMaxResponsesProvider.swift` — Main provider
2. `Sources/Providers/MiniMaxResponsesService.swift` — HTTP/network layer + SSE parser
3. `Sources/Providers/MiniMaxResponsesModels.swift` — Request/Response/Event models
4. `Sources/Providers/MiniMaxResponsesBuilder.swift` — Request serialization

## Files to Modify
1. `Sources/MiniMaxPlugin.swift` — Register `MiniMaxResponsesProvider` in `llmProviders()`
2. Provider files (`MiniMaxAnthropicProvider.swift`, `MiniMaxOpenAIProvider.swift`, `MiniMaxResponsesProvider.swift`) — Add `MiniMax-M3` with `.threeLevel` capability in `availableModels`

## Base URL
`https://api.minimaxi.com/v1/responses`
