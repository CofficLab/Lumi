# Qwen Cache Hit Rate Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make the conversation cache-hit toolbar work reliably for Aliyun Qwen models using the Anthropic-compatible endpoint.

**Architecture:** Enable explicit prompt-cache boundaries only for providers that opt in, normalize Aliyun/OpenAI/Anthropic usage fields into the existing typed message token fields, and make the standalone toolbar react to all message changes. The toolbar will use the token-weighted cache-hit rate as its primary metric and retain per-request data for diagnostics.

**Tech Stack:** Swift 6, Swift Package Manager, SwiftUI, KitLLM, ProviderMessage, Testing.

---

### Task 1: Add provider opt-in for explicit Anthropic cache boundaries

**Files:**
- Modify: `Packages/KitLLM/Sources/KitLLM/Adapters/AnthropicCompatibleProviderConfiguration.swift`
- Modify: `Packages/KitLLM/Sources/KitLLM/Adapters/AnthropicCompatibleProviderAdapter.swift`
- Modify: `Packages/PluginLLMProviderAliyun/Sources/PluginLLMProviderAliyun/AliyunProvider.swift`
- Modify: `Packages/PluginLLMProviderAliyun/Sources/PluginLLMProviderAliyun/AliyunTokenPlanProvider.swift`
- Test: `Packages/KitLLM/Tests/KitLLMTests/KitLLMTests.swift`

**Steps:**
1. Add an opt-in boolean to the Anthropic configuration, defaulting to `false`.
2. For opted-in providers, add `cache_control.type = ephemeral` to the final reusable text content block in each request, without changing non-opted-in providers.
3. Enable the option for both Aliyun CodingPlan and TokenPlan providers.
4. Add a request-body test that verifies the marker is present only when enabled.

### Task 2: Normalize cache usage fields and preserve them through the response

**Files:**
- Modify: `Packages/KitLLM/Sources/KitLLM/Adapters/AnthropicCompatibleProviderAdapter.swift`
- Modify: `Packages/KitLLM/Sources/KitLLM/Base/VendorLLMProvider.swift`
- Modify: `Packages/KitLLM/Tests/KitLLMTests/KitLLMTests.swift`

**Steps:**
1. Parse `cache_read_input_tokens`, `cached_tokens`, and nested `prompt_tokens_details.cached_tokens` for Anthropic-compatible responses.
2. Preserve cache-read, cache-write, and total-input values in streaming and non-streaming `LLMResponse` values.
3. Add fixtures/tests for Aliyun-style Anthropic usage and OpenAI-compatible usage aliases.

### Task 3: Make the standalone toolbar accurate and reactive

**Files:**
- Modify: `Packages/PluginConversationCacheHitRate/Sources/PluginConversationCacheHitRate/Observers/CacheHitRateObserver.swift`
- Modify: `Packages/PluginConversationCacheHitRate/Sources/PluginConversationCacheHitRate/ConversationCacheHitRatePlugin.swift`
- Modify: `Packages/PluginConversationCacheHitRate/Sources/PluginConversationCacheHitRate/CacheHitRateToolbarView.swift`
- Modify: `Packages/PluginConversationCacheHitRate/Tests/PluginConversationCacheHitRateTests/PluginConversationCacheHitRateTests.swift`

**Steps:**
1. Observe `MessageChange` so delete, clear, and update operations refresh the statistic.
2. Make the toolbar headline use `totalCachedTokens / totalInputTokens`, matching the provider definition of token cache-hit rate.
3. Keep per-request average as a secondary diagnostic value.
4. Add tests for weighted aggregation and zero-hit samples.

### Task 4: Verify

**Steps:**
1. Run `swift test --package-path Packages/KitLLM`.
2. Run `swift test --package-path Packages/PluginLLMProviderAliyun`.
3. Run `swift test --package-path Packages/PluginConversationCacheHitRate`.
4. Review the diff and report the exact manual Qwen test: send a stable context exceeding 1024 tokens twice, then check the toolbar and the second response's cache-read usage.
