# Conversation List Refresh Deduplication

## Goal

Keep conversation sorting and sidebar reloads from competing with the message send path. A new message should update the in-memory summary immediately, but the sidebar does not need to reload for every message or status transition.

## Implementation

- `markConversationActive` updates `lastMessageAt` and `updatedAt` synchronously in the in-memory cache.
- The broad `conversationsDidChange` notification from an active-message update is debounced for 200ms.
- Repeated active updates cancel the previous pending notification and share one trailing refresh.
- Explicit structural changes such as create, delete, or title updates still use immediate notifications and cancel any pending trailing notification.
- Persistence of `lastMessageAt` remains asynchronous.

## Acceptance

- Two active-message updates within the debounce window produce one sidebar refresh notification.
- The in-memory conversation summary is immediately updated.
- Structural conversation changes are not delayed.

## Verification

`ConversationListRefreshTests` verifies that repeated active updates are coalesced into one legacy sidebar notification.
