# Message List Refresh Source Deduplication

## Goal

Prevent sender-state churn from causing V2/V3 to reload the historical message tail. A send operation can emit many status and queue changes, while the message history has not changed.

## Implementation

- `MessageChange` remains the direct path for inserting a new historical message.
- `messages.objectWillChange` remains the compatibility fallback for edits, deletes, and persistence-side changes.
- `conversationState` updates `activityMessage` without reloading historical rows.
- `streaming.objectWillChange` updates only the independent streaming row with its existing frame gate.
- Remove the `sender.objectWillChange -> refreshTail()` path from V2/V3.
- Remove the unused sender dependency from `MessageListServices` so the list cannot accidentally reintroduce this refresh coupling.

## Acceptance

- A sender status or pending-queue change does not invoke `refreshTail()`.
- A message insertion still appears immediately from its event payload.
- Message edits/deletes still use the compatibility refresh fallback.
- Streaming updates do not rebuild the historical message window per token.

## Verification

Run the `PluginMessageList` test suite and inspect the remaining refresh subscriptions in `ListV2ViewModel` and `ListV3ViewModel`.
