import AppKit
import SuperLogKit
import EditorChatInputKit
import LumiCoreKit
import LumiUI
import SwiftUI

public struct InputView: View, SuperLog {
    @EnvironmentObject private var conversationVM: WindowConversationVM
    @LumiUI.LumiTheme private var theme: any LumiUITheme
    @EnvironmentObject private var lumiCore: LumiCore
    @State private var isFocused = false
    @State private var editorHeight: CGFloat = ChatInputEditorView.minHeight
    @State private var cursorPosition = 0
    @State private var isImageDragHovering = false

    private var isProjectSelected: Bool {
        lumiCore.projectState?.currentProject != nil
    }

    private var currentProjectName: String {
        lumiCore.projectState?.currentProject?.name ?? ""
    }

    private var currentProjectPath: String {
        lumiCore.projectState?.currentProject?.path ?? ""
    }

    public init() {}

    public var body: some View {
        VStack(spacing: 8) {
            editorView
                .frame(height: editorHeight)
                .padding(8)
                .background(theme.textSecondary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    if conversationVM.canAttachToCurrentConversation, isImageDragHovering {
                        imageDropHoverOverlay
                    }
                }

            CommandSuggestionView(
                suggestions: conversationVM.commandSuggestions(for: conversationVM.draftText),
                isVisible: conversationVM.isCommandSuggestionVisible,
                version: conversationVM.commandSuggestionsVersion
            ) { suggestion in
                conversationVM.setDraftText(suggestion.command + " ")
                conversationVM.setCommandSuggestionsVisible(false)
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
            if let fileURL = Self.addToChatFileURL(from: notification, targetWindowId: conversationVM.windowId) {
                handleFileDrop(fileURL)
                isFocused = true
                return
            }
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
            onArrowUp: handleArrowUp,
            onArrowDown: handleArrowDown,
            onEnter: handleEnter,
            onFileDrop: { url in
                handleFileDrop(url)
            },
            isFocused: $isFocused,
            cursorPosition: $cursorPosition,
            isImageDragHovering: $isImageDragHovering
        )
        .animation(.easeInOut(duration: 0.15), value: editorHeight)
        .onChange(of: conversationVM.draftText) { _, newValue in
            conversationVM.updateCommandSuggestions(for: newValue)
        }
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

                Text(LumiPluginLocalization.string("Release to add image to the chat", bundle: .module))
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

    private func handleArrowUp() {
        guard conversationVM.isCommandSuggestionVisible else { return }
        conversationVM.selectPreviousCommandSuggestion()
    }

    private func handleArrowDown() {
        guard conversationVM.isCommandSuggestionVisible else { return }
        conversationVM.selectNextCommandSuggestion()
    }

    private func handleEnter() {
        if conversationVM.isCommandSuggestionVisible,
           let suggestion = conversationVM.currentCommandSuggestion() {
            conversationVM.setDraftText(suggestion.command + " ")
            conversationVM.setCommandSuggestionsVisible(false)
            isFocused = true
            return
        }

        submit()
    }

    private func submit() {
        let text = conversationVM.draftText
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || !conversationVM.pendingAttachments.isEmpty else { return }

        conversationVM.setDraftText("")
        editorHeight = ChatInputEditorView.minHeight
        cursorPosition = 0
        conversationVM.setCommandSuggestionsVisible(false)

        Task { @MainActor in
            await ensureConversationSelected()
            conversationVM.enqueueText(text)
        }
    }

    private func ensureConversationSelected() async {
        guard conversationVM.selectedConversationId == nil else { return }

        await conversationVM.createNewConversation(
            projectName: isProjectSelected ? currentProjectName : nil,
            projectPath: isProjectSelected ? currentProjectPath : nil
        )
    }

    private func handleFileDrop(_ url: URL) {
        let fileURL = url.standardizedFileURL
        if ChatInputEditorRules.isChatImageFileURL(fileURL) {
            conversationVM.handleImageUpload(url: fileURL)
        } else {
            conversationVM.appendDraftText(fileURL.path)
        }
    }

    private func appendToDraft(_ value: String) {
        conversationVM.appendDraftText(value)
        cursorPosition = conversationVM.draftText.count
    }

    static func addToChatFileURL(from notification: Notification, targetWindowId: UUID?) -> URL? {
        guard let userInfo = notification.userInfo,
              let path = userInfo["fileURL"] as? String,
              !path.isEmpty else {
            return nil
        }

        guard let senderWindowId = userInfo["windowId"] as? UUID else {
            return URL(fileURLWithPath: path)
        }

        guard let targetWindowId, senderWindowId == targetWindowId else {
            return nil
        }

        return URL(fileURLWithPath: path)
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
