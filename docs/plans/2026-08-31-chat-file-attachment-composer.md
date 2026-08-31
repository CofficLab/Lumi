# Chat File Attachment Composer Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make file selection and file drag-and-drop create independent pending attachments instead of inserting absolute paths into the conversation text input.

**Architecture:** Reuse the existing `MessageSendingProviding.pendingFileAttachments` queue and `UserFileAttachment` metadata format. Add a shared URL-to-attachment loader, route picker/drop events into the sender, render removable file chips alongside image previews, and allow messages containing only attachments to be sent.

**Tech Stack:** Swift 6, SwiftUI, AppKit `NSViewRepresentable`, Swift Package Manager, Swift Testing.

---

### Task 1: Add shared file attachment loading

**Files:**
- Modify: `Packages/ProviderMessage/Sources/ProviderMessage/UserAttachments.swift`
- Test: `Packages/ProviderMessage/Tests/ProviderMessageTests/ProviderMessageTests.swift`

Add a public loader that reads a selected URL, determines its MIME type, stores base64 bytes, and also stores UTF-8 text when available. Add tests for text and binary files using a temporary directory.

### Task 2: Route picker and drop events into the pending file attachment pool

**Files:**
- Modify: `Packages/PluginChatFileAttachment/Package.swift`
- Modify: `Packages/PluginChatFileAttachment/Sources/PluginChatFileAttachment/Views/ChatFileAttachmentButton.swift`
- Modify: `Packages/PluginChatFileAttachment/Sources/PluginChatFileAttachment/PluginChatFileAttachment.swift`
- Modify: `Packages/PluginConversationInput/Sources/PluginConversationInput/Editor/ComposerView.swift`

Resolve `MessageSendingProviding` from the kernel, load selected files off the main actor, and add them to `pendingFileAttachments`. Update comments and keep the input provider’s explicit path-insertion API for file-tree actions.

### Task 3: Render and remove pending file attachments

**Files:**
- Modify: `Packages/PluginConversationInput/Sources/PluginConversationInput/Views/AttachmentPreviewView.swift`

Show filename and file kind in a removable chip, next to existing image thumbnails, using the sender’s pending file attachment list.

### Task 4: Support attachment-only sends

**Files:**
- Modify: `Packages/PluginConversationInput/Sources/PluginConversationInput/Views/ConversationInputView.swift`
- Modify: `Packages/ProviderMessageSender/Sources/ProviderMessageSender/DefaultMessageSender.swift`
- Modify: `Packages/PluginMessageSender/Sources/PluginMessageSender/MessageSender.swift`
- Test: `Packages/ProviderMessageSender/Tests/ProviderMessageSenderTests/ProviderMessageSenderTests.swift`

Make the send button/Return path consider pending image or file attachments as sendable content, and make both sender implementations accept empty text when attachments exist. Add a regression test that verifies an attachment-only user message is persisted with empty content and file metadata.

### Task 5: Verify

Run the focused Swift package tests for ProviderMessage and ProviderMessageSender, then build/test PluginConversationInput and PluginChatFileAttachment. Review the diff for unrelated changes.
