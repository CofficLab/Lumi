import AppKit
import ProviderAgentLoop
import ProviderConversation
import ProviderConversationInput
import ProviderLifecycleHooks
import ProviderMessage
import ProviderMessageSender
import SwiftUI
import Testing
@testable import PluginConversationInput

@MainActor
@Suite("ChatInputEditorView")
struct ChatInputEditorViewTests {
    @Test("active turn only shows the stop control")
    func activeTurnOnlyShowsStop() {
        let state = SendActionBarState(isSending: true, canSend: true)

        #expect(!state.showsSendButton)
        #expect(state.showsStopButton)
        #expect(state.canSend)
    }

    @Test("idle state only needs the send control")
    func idleStateOnlyShowsSend() {
        let state = SendActionBarState(isSending: false, canSend: false)

        #expect(state.showsSendButton)
        #expect(!state.showsStopButton)
    }

    @Test("common image files are recognized for chat attachment drops")
    func imageDropRuleRecognizesCommonImages() {
        #expect(ChatInputEditorRules.isChatImageFileURL(URL(fileURLWithPath: "/tmp/photo.PNG")))
        #expect(ChatInputEditorRules.isChatImageFileURL(URL(fileURLWithPath: "/tmp/photo.heic")))
        #expect(!ChatInputEditorRules.isChatImageFileURL(URL(fileURLWithPath: "/tmp/report.pdf")))
    }

    @Test("directories are recognized separately from files")
    func directoryDropRuleRecognizesDirectories() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("conversation-input-directory-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        let fileURL = directoryURL.appendingPathComponent("README.md")
        #expect(FileManager.default.createFile(atPath: fileURL.path, contents: Data()))

        #expect(ChatInputEditorRules.isDirectoryURL(directoryURL))
        #expect(!ChatInputEditorRules.isDirectoryURL(fileURL))
    }

    @Test("placeholder does not intercept editor clicks")
    func placeholderAllowsClickThrough() {
        let placeholderLabel = ChatInputPlaceholderLabel(labelWithString: "Placeholder")

        #expect(placeholderLabel.hitTest(.zero) == nil)
    }

    @Test("marked text stays inside the editor until IME commit")
    func markedTextIsNotPublishedUntilCommit() {
        var draft = ""
        var height: CGFloat = ChatInputEditorView.minHeight
        var focused = false
        var cursor = 0
        var dragging = false

        let view = ChatInputEditorView(
            text: Binding(get: { draft }, set: { draft = $0 }),
            height: Binding(get: { height }, set: { height = $0 }),
            onSubmit: {},
            isFocused: Binding(get: { focused }, set: { focused = $0 }),
            cursorPosition: Binding(get: { cursor }, set: { cursor = $0 }),
            isImageDragHovering: Binding(get: { dragging }, set: { dragging = $0 })
        )
        let coordinator = view.makeCoordinator()
        let textView = MarkedTextTestView()
        coordinator.attach(to: textView)
        let placeholderLabel = NSTextField(labelWithString: "Placeholder")
        placeholderLabel.tag = ChatInputEditorView.placeholderLabelTag
        textView.addSubview(placeholderLabel)
        textView.string = "ni"
        textView.isMarked = true

        coordinator.textDidChange(Notification(name: NSText.didChangeNotification, object: textView))

        #expect(draft.isEmpty)
        #expect(cursor == 0)
        #expect(placeholderLabel.isHidden)

        textView.string = "你"
        textView.isMarked = false
        coordinator.textDidChange(Notification(name: NSText.didChangeNotification, object: textView))

        #expect(draft == "你")
        #expect(cursor == 1)
    }

    @Test("native editor clears its composition guard when the candidate is committed")
    func editorClearsCompositionOnInsert() {
        let textView = EditorTextView(frame: .zero)
        let placeholderLabel = NSTextField(labelWithString: "Placeholder")
        textView.addSubview(placeholderLabel)
        textView.placeholderLabel = placeholderLabel

        #expect(!placeholderLabel.isHidden)

        textView.setMarkedText(
            "ni",
            selectedRange: NSRange(location: 2, length: 0),
            replacementRange: NSRange(location: 0, length: 0)
        )

        #expect(textView.isIMEComposing)
        #expect(placeholderLabel.isHidden)

        textView.insertText("你", replacementRange: textView.selectedRange())

        #expect(!textView.isIMEComposing)
    }

    @Test("dismantling the editor cancels deferred bindings")
    func dismantlingEditorCancelsDeferredBinding() async {
        var draft = ""
        var height: CGFloat = ChatInputEditorView.minHeight
        var focused = false
        var cursor = 0
        var dragging = false

        let view = ChatInputEditorView(
            text: Binding(get: { draft }, set: { draft = $0 }),
            height: Binding(get: { height }, set: { height = $0 }),
            onSubmit: {},
            isFocused: Binding(get: { focused }, set: { focused = $0 }),
            cursorPosition: Binding(get: { cursor }, set: { cursor = $0 }),
            isImageDragHovering: Binding(get: { dragging }, set: { dragging = $0 })
        )
        let coordinator = view.makeCoordinator()
        let textView = MarkedTextTestView()
        coordinator.attach(to: textView)

        #expect(coordinator.isActive)
        coordinator.scheduleHeightBindingUpdate(ChatInputEditorView.maxHeight)
        ChatInputEditorView.dismantleNSView(NSScrollView(), coordinator: coordinator)
        try? await Task.sleep(nanoseconds: 50_000_000)

        #expect(!coordinator.isActive)
        #expect(!coordinator.accepts(textView))
        #expect(height == ChatInputEditorView.minHeight)
    }

    @Test("Return publishes the current committed editor text before sending")
    func returnPublishesDraftBeforeSubmit() {
        var draft = ""
        var height: CGFloat = ChatInputEditorView.minHeight
        var focused = false
        var cursor = 1
        var dragging = false
        var submitCount = 0

        let view = ChatInputEditorView(
            text: Binding(get: { draft }, set: { draft = $0 }),
            height: Binding(get: { height }, set: { height = $0 }),
            onSubmit: { submitCount += 1 },
            isFocused: Binding(get: { focused }, set: { focused = $0 }),
            cursorPosition: Binding(get: { cursor }, set: { cursor = $0 }),
            isImageDragHovering: Binding(get: { dragging }, set: { dragging = $0 })
        )
        let coordinator = view.makeCoordinator()
        let textView = MarkedTextTestView()
        coordinator.attach(to: textView)
        textView.string = "你"
        textView.setSelectedRange(NSRange(location: 1, length: 0))

        _ = coordinator.textView(
            textView,
            doCommandBy: #selector(NSResponder.insertNewline(_:))
        )

        #expect(draft == "你")
        #expect(submitCount == 1)
    }

    @Test("switching conversations clears pre-commit attachments")
    func switchingConversationsClearsAttachments() throws {
        let conversations = DefaultConversationManager()
        let first = try conversations.createConversation(
            title: "A", projectPath: nil, providerID: nil, modelName: nil
        )
        let second = try conversations.createConversation(
            title: "B", projectPath: nil, providerID: nil, modelName: nil
        )
        conversations.selectConversation(id: first)

        let messages = DefaultMessageManager()
        let sender = DefaultMessageSender(
            conversations: conversations,
            messages: messages,
            agentLoop: InputTestAgentLoop()
        )
        let input = DefaultConversationInputProvider()
        let observer = ActionBarConversationObserver(
            conversations: conversations,
            input: input,
            sender: sender
        )

        input.text = "draft"
        sender.addImageAttachment(
            UserImageAttachment(mimeType: "image/png", base64Data: "AAAA")
        )
        sender.addFileAttachment(
            UserFileAttachment(fileName: "notes.txt", mimeType: "text/plain", textContent: "notes")
        )

        conversations.selectConversation(id: second)

        #expect(input.text.isEmpty)
        #expect(sender.pendingImageAttachments.isEmpty)
        #expect(sender.pendingFileAttachments.isEmpty)
        observer.cancel()
    }
}

private final class MarkedTextTestView: NSTextView {
    var isMarked = false

    override func hasMarkedText() -> Bool {
        isMarked
    }
}

@MainActor
private final class InputTestAgentLoop: AgentLoopProviding {
    func addAgentLoopObserver(
        _ callback: @escaping (AgentLoopEvent) -> Void
    ) -> any AgentLoopObserverHandle {
        InputTestAgentLoopObserverHandle()
    }

    func runTurn(in conversationID: UUID) async throws -> AgentLoopOutcome { .completed }

    func resumeTurn(
        in conversationID: UUID,
        request: AgentTurnResumeRequest
    ) async throws -> AgentLoopOutcome { .completed }

    func cancelTurn(in conversationID: UUID) {}
    func state(for conversationID: UUID) -> AgentLoopState { .idle }
    func suspension(for conversationID: UUID) -> AgentLoopSuspension? { nil }
    func isRunning(for conversationID: UUID) -> Bool { false }
    func currentTurnID(for conversationID: UUID) -> UUID? { nil }
    func setLifecycleHooks(_ hooks: (any LifecycleHooksProviding)?) {}
}

@MainActor
private final class InputTestAgentLoopObserverHandle: AgentLoopObserverHandle {
    func cancel() {}
}
