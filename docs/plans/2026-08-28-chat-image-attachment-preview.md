# Chat Image Attachment Preview Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Restore the Lumi 5.16.0 experience in the current KernelCore architecture: dragging image files into the chat input adds pending image attachments and displays removable thumbnails above the input.

**Architecture:** Reuse the existing `MessageSendingProviding` pending-image API and `UserImageAttachment` model. Extend the current `PluginConversationInput` to convert dropped image URLs into attachments, and register a `bottomFixed` chat-section item immediately before the input for the preview UI. Keep non-image drops as path text and preserve the existing text-required send behavior.

**Tech Stack:** Swift 6, SwiftUI, AppKit `NSViewRepresentable`, `UniformTypeIdentifiers`, `ProviderChatSection`, `ProviderMessageSender`.

---

### Task 1: Connect image drops to the current sender

**Files:**
- Modify: `Packages/PluginConversationInput/Sources/PluginConversationInput/Editor/ComposerView.swift`
- Test: `Packages/PluginConversationInput/Tests/PluginConversationInputTests/ChatInputEditorViewTests.swift`

**Steps:**

1. Add image-file branching in the existing `onFileDrop` callback.
2. Load dropped image data off the main actor, derive its MIME type with `UTType`, create `UserImageAttachment`, and call `sender.addImageAttachment` on the main actor.
3. Retain path insertion for non-image files and focus the input after either operation.
4. Add focused tests for the pure image-extension rule if coverage is missing.

### Task 2: Add the removable preview row above the input

**Files:**
- Create: `Packages/PluginConversationInput/Sources/PluginConversationInput/Views/AttachmentPreviewView.swift`
- Modify: `Packages/PluginConversationInput/Sources/PluginConversationInput/ConversationInputPlugin.swift`

**Steps:**

1. Create a SwiftUI preview that observes sender `objectWillChange` through a local revision, matching the existing existential-provider observation pattern.
2. Render a horizontal row only when pending image attachments exist.
3. Decode each base64 payload to `NSImage`, render a 72×72 thumbnail, show a placeholder for decode failure, and provide an `xmark` removal action.
4. Register the view as a `bottomFixed` chat item ordered immediately before the input item, with no extra divider when empty.
5. Remove the preview item during plugin shutdown.

### Task 3: Verify behavior and integration

**Files:**
- No additional source files unless verification exposes an issue.

**Steps:**

1. Run the `PluginConversationInput` test target.
2. Run the relevant package/build validation for `PluginConversationInput` and `PluginMessageSender`.
3. Inspect the final diff and confirm no unrelated worktree changes were modified.
4. Report source-level behavior and any platform/runtime verification limitations.
