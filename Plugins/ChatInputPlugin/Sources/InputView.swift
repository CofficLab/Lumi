import AppKit
import ChatInputEditorKit
import LumiCoreKit
import LumiUI
import SwiftUI

public struct InputView: View {
    @EnvironmentObject private var conversationVM: WindowConversationVM
    @LumiUI.LumiTheme private var theme: any LumiUITheme
    @State private var isFocused = false
    @State private var editorHeight: CGFloat = ChatInputEditorView.minHeight
    @State private var cursorPosition = 0
    @State private var isImageDragHovering = false

    public init() {}

    public var body: some View {
        VStack(spacing: 8) {
            editorView
                .frame(height: editorHeight)
                .padding(8)
                .background(theme.textSecondary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    if isImageDragHovering {
                        imageDropHoverOverlay
                    }
                }

            CommandSuggestionView(input: conversationVM.draftText) { command in
                conversationVM.setDraftText(command + " ")
                isFocused = true
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(theme.surface)
        .onAppear {
            isFocused = true
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("addToChat"))) { notification in
            guard let value = Self.addToChatText(from: notification, targetWindowId: conversationVM.windowId) else { return }
            appendToDraft(value)
            isFocused = true
        }
    }

    private var editorView: some View {
        ChatInputEditorView(
            text: draftBinding,
            height: $editorHeight,
            font: NSFont.systemFont(ofSize: NSFont.systemFontSize),
            textColor: NSColor(theme.textPrimary),
            isVerbose: ChatInputPlugin.verbose,
            log: { message in
                ChatInputPlugin.logger.info("\(ChatInputPlugin.t)\(message)")
            },
            onSubmit: submit,
            onEnter: handleEnter,
            onFileDrop: { url in
                conversationVM.handleImageUpload(url: url)
            },
            isFocused: $isFocused,
            cursorPosition: $cursorPosition,
            isImageDragHovering: $isImageDragHovering
        )
        .animation(.easeInOut(duration: 0.15), value: editorHeight)
    }

    private var imageDropHoverOverlay: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [7, 5]))
                .foregroundStyle(.secondary.opacity(0.65))

            VStack(spacing: 8) {
                Image(systemName: "photo.badge.plus")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)

                Text(String(localized: "Release to add image to the chat", table: "ChatInputPlugin"))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }
        }
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    private var draftBinding: Binding<String> {
        Binding(
            get: { conversationVM.draftText },
            set: { conversationVM.setDraftText($0) }
        )
    }

    private func handleEnter() {
        if let suggestion = CommandSuggestionView.suggestions(for: conversationVM.draftText).first {
            conversationVM.setDraftText(suggestion.command + " ")
            isFocused = true
            return
        }

        submit()
    }

    private func submit() {
        let value = conversationVM.draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        editorHeight = ChatInputEditorView.minHeight
        cursorPosition = 0
        Task { await conversationVM.submitDraftText(value) }
    }

    private func appendToDraft(_ value: String) {
        if conversationVM.draftText.isEmpty {
            conversationVM.setDraftText(value)
        } else {
            conversationVM.setDraftText("\(conversationVM.draftText)\n\n\(value)")
        }
        cursorPosition = conversationVM.draftText.count
    }

    static func addToChatText(from notification: Notification, targetWindowId: UUID?) -> String? {
        guard let userInfo = notification.userInfo,
              let value = userInfo["text"] as? String,
              !value.isEmpty else {
            return nil
        }

        guard let senderWindowId = userInfo["windowId"] as? UUID else {
            return value
        }

        guard let targetWindowId, senderWindowId == targetWindowId else {
            return nil
        }

        return value
    }
}
