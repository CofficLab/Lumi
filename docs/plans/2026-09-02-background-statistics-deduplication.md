# Background Statistics Deduplication

## Goal

Keep title and statistics features from competing with message sending. These features are secondary UI consumers and should not repeatedly materialize a full conversation or run synchronous database work on MainActor.

## Implementation

- Add asynchronous daily message/token aggregation APIs to `MessageManaging`.
- Run production daily aggregation in a utility-priority detached task and merge pending messages for read-your-writes behavior.
- Restrict SwiftData daily aggregation to the fields needed for each metric.
- Debounce Activity Heatmap reloads after message insertion by 250ms and cancel stale reloads.
- Let title generation consume the inserted user message payload, with a bounded first-user-message check for correctness.
- Debounce cache hit-rate, context-size, and speed refreshes by 150ms; a new message or selection change cancels the previous refresh.

## Acceptance

- No Activity Heatmap refresh calls synchronous daily database queries on MainActor.
- Title generation no longer materializes the whole conversation to find its first user message.
- Bursts of message inserts produce one trailing refresh per statistics consumer.
- Switching conversations cancels stale statistic results.

## Verification

The affected ProviderMessage, PluginMessageManager, PluginActivityHeatmap, PluginConversationTitle, PluginConversationCacheHitRate, PluginConversationContextSize, and PluginConversationSpeed test suites pass.
