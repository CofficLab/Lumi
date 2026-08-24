import AppKit
import Combine
import Foundation
import Testing
import KernelLumi
@testable import MessageListAppKitPlugin

/// Minimal MessageSending mock recording resume calls.
@MainActor
private final class MockMessageSender: MessageSending {
    // @Published auto-synthesizes the nonisolated objectWillChange.
    @Published var isSending = false
    @Published var pendingAttachments: [LumiImageAttachment] = []
    @Published var pendingFileAttachments: [LumiFileAttachment] = []
    var resumeCalls: [(conversationID: UUID, request: AgentTurnResumeRequest)] = []

    func sendMessage(_ content: String, conversationID: UUID?) async throws {}

    func sendMessage(
        _ content: String,
        imageAttachments: [LumiImageAttachment],
        conversationID: UUID?
    ) async throws {}

    func cancelCurrentRequest() {}

    func addAttachment(_ attachment: LumiImageAttachment) { pendingAttachments.append(attachment) }
    func removeAttachment(id: UUID) { pendingAttachments.removeAll { $0.id == id } }
    func clearAttachments() { pendingAttachments.removeAll() }

    func addFileAttachment(_ attachment: LumiFileAttachment) { pendingFileAttachments.append(attachment) }
    func removeFileAttachment(id: UUID) { pendingFileAttachments.removeAll { $0.id == id } }
    func clearFileAttachments() { pendingFileAttachments.removeAll() }

    func resumeTurn(
        in conversationID: UUID,
        request: AgentTurnResumeRequest
    ) async throws -> AgentTurnOutcome {
        resumeCalls.append((conversationID, request))
        return .completed
    }
}

/// Serialized: submission spawns MainActor tasks that must not interleave
/// with other suites' MainActor work.
@Suite(.serialized)
@MainActor
struct AppKitAskUserRendererTests {
    private let conversationID = UUID(uuidString: "3D9E7F2A-5B6C-4D8E-9F0A-1B2C3D4E5F6A")!

    private func makePayload(
        mode: String? = "choice",
        question: String = "是否允许插件访问网络？",
        options: [AppKitAskUserOption] = [.init(label: "允许"), .init(label: "拒绝")]
    ) -> AppKitAskUserPayload {
        AppKitAskUserPayload(
            toolCallId: "call_ask_user_1",
            question: question,
            options: options,
            mode: mode,
            conversationId: conversationID.uuidString,
            verbosity: "v2"
        )
    }

    private func payloadJSON(_ payload: AppKitAskUserPayload) -> String {
        let data = try! JSONEncoder().encode(payload)
        return String(data: data, encoding: .utf8)!
    }

    private func toolMessage(payload: AppKitAskUserPayload) -> LumiChatMessage {
        LumiChatMessage(
            conversationID: conversationID,
            role: .assistant,
            content: "",
            createdAt: Date(timeIntervalSinceReferenceDate: 0),
            toolCalls: [
                LumiToolCall(
                    id: "call_ask_user_1",
                    name: "ask_user",
                    arguments: "{}",
                    result: LumiToolResult(
                        content: payloadJSON(payload),
                        turnControl: .suspend(AgentTurnSuspension(
                            suspensionID: "susp_1",
                            conversationID: conversationID,
                            toolCallID: "call_ask_user_1",
                            kind: "ask_user",
                            payload: payloadJSON(payload)
                        ))
                    ),
                    displayDescription: "询问用户"
                )
            ]
        )
    }

    private func makeRenderer(sender: MockMessageSender) -> AppKitAskUserRenderer {
        AppKitAskUserRenderer(environment: .init(
            theme: AppKitMessageTheme.systemDefault(),
            mermaidCache: AppKitMermaidCache(),
            layoutCache: AppKitMessageLayoutCache(),
            messageSender: sender
        ))
    }

    // MARK: - Payload parsing

    @Test("解析标准 choice payload")
    func parsesChoicePayload() {
        let json = """
        {"toolCallId":"call_ask_user_1","question":"是否允许插件访问网络？","options":["允许","拒绝"],"mode":"choice","conversationId":"\(conversationID.uuidString)","verbosity":"v2"}
        """
        let payload = AppKitAskUserPayload.parse(from: json)
        #expect(payload != nil)
        #expect(payload?.question == "是否允许插件访问网络？")
        #expect(payload?.options.map(\.label) == ["允许", "拒绝"])
        #expect(payload?.effectiveMode == .choice)
    }

    @Test("解析结构化 options（label+description）")
    func parsesStructuredOptions() {
        let json = """
        {"toolCallId":"t1","question":"选方案","options":[{"label":"A","description":"方案A"},{"label":"B"}],"mode":"choice","conversationId":"\(conversationID.uuidString)","verbosity":"v2"}
        """
        let payload = AppKitAskUserPayload.parse(from: json)
        #expect(payload?.options.first?.label == "A")
        #expect(payload?.options.first?.description == "方案A")
        #expect(payload?.options.last?.description == nil)
    }

    @Test("legacy payload 无 mode 时按 options 推断")
    func infersModeFromOptions() {
        let yesNo = makePayload(mode: nil, options: [.init(label: "是"), .init(label: "否")])
        #expect(yesNo.effectiveMode == .yesNo)

        let multi = makePayload(mode: nil, options: [.init(label: "A"), .init(label: "B"), .init(label: "C")])
        #expect(multi.effectiveMode == .choice)

        let empty = makePayload(mode: nil, options: [])
        #expect(empty.effectiveMode == .freeText)
    }

    @Test("无法解析的内容返回 nil")
    func unparsableContentReturnsNil() {
        #expect(AppKitAskUserPayload.parse(from: nil) == nil)
        #expect(AppKitAskUserPayload.parse(from: "not json") == nil)
    }

    // MARK: - Renderer configuration

    @Test("choice 模式渲染每个选项一个按钮")
    func choiceRendersButtons() {
        let sender = MockMessageSender()
        let renderer = makeRenderer(sender: sender)
        let view = renderer.makeView()
        let row = AppKitMessageRow(kind: .tool, message: toolMessage(payload: makePayload(mode: "choice")))
        renderer.configure(view: view, row: row)

        let buttons = view.subviews.compactMap { $0 as? NSStackView }
            .first?.arrangedSubviews.compactMap { $0 as? NSButton } ?? []
        #expect(buttons.count == 2)
        #expect(buttons.map(\.title) == ["允许", "拒绝"])
    }

    @Test("yes_no 模式渲染是/否")
    func yesNoRenders() {
        let sender = MockMessageSender()
        let renderer = makeRenderer(sender: sender)
        let view = renderer.makeView()
        let row = AppKitMessageRow(
            kind: .tool,
            message: toolMessage(payload: makePayload(mode: "yes_no", options: [.init(label: "是"), .init(label: "否")]))
        )
        renderer.configure(view: view, row: row)
        let buttons = view.subviews.compactMap { $0 as? NSStackView }
            .first?.arrangedSubviews.compactMap { $0 as? NSButton } ?? []
        #expect(buttons.map(\.title) == ["是", "否"])
    }

    @Test("free_text 模式渲染输入框与提交按钮")
    func freeTextRenders() {
        let sender = MockMessageSender()
        let renderer = makeRenderer(sender: sender)
        let view = renderer.makeView()
        let row = AppKitMessageRow(
            kind: .tool,
            message: toolMessage(payload: makePayload(mode: "free_text", options: []))
        )
        renderer.configure(view: view, row: row)

        let textField = view.subviews.compactMap { $0 as? NSTextField }.first { !$0.isEditable == false && $0.isHidden == false }
        let submit = view.subviews.compactMap { $0 as? NSButton }.first { !$0.isHidden }
        #expect(textField != nil)
        #expect(submit != nil)
    }

    // MARK: - Submission

    @Test("点击选项触发 resumeTurn 并禁用控件")
    func optionSubmitResumesOnce() async throws {
        let sender = MockMessageSender()
        let renderer = makeRenderer(sender: sender)
        let view = renderer.makeView()
        let row = AppKitMessageRow(kind: .tool, message: toolMessage(payload: makePayload(mode: "choice")))
        renderer.configure(view: view, row: row)

        let buttons = view.subviews.compactMap { $0 as? NSStackView }
            .first?.arrangedSubviews.compactMap { $0 as? NSButton } ?? []
        #expect(buttons.count == 2)

        buttons[0].performClick(nil)
        try? await Task.sleep(nanoseconds: 30_000_000)

        #expect(sender.resumeCalls.count == 1)
        #expect(sender.resumeCalls.first?.request.suspensionID == "call_ask_user_1")
        #expect(sender.resumeCalls.first?.request.answer == "允许")
        #expect(buttons[0].isEnabled == false)
        #expect(buttons[1].isEnabled == false)

        // 重复点击不重复提交。
        buttons[1].performClick(nil)
        try? await Task.sleep(nanoseconds: 30_000_000)
        #expect(sender.resumeCalls.count == 1)
    }

    @Test("复用后 prepareForReuse 重置响应状态")
    func reuseResetsState() {
        let sender = MockMessageSender()
        let renderer = makeRenderer(sender: sender)
        let view = renderer.makeView()
        let row = AppKitMessageRow(kind: .tool, message: toolMessage(payload: makePayload(mode: "choice")))
        renderer.configure(view: view, row: row)

        let buttons = view.subviews.compactMap { $0 as? NSStackView }
            .first?.arrangedSubviews.compactMap { $0 as? NSButton } ?? []
        buttons[0].performClick(nil)

        renderer.prepareForReuse(view: view)
        renderer.configure(view: view, row: row)
        let reusedButtons = view.subviews.compactMap { $0 as? NSStackView }
            .first?.arrangedSubviews.compactMap { $0 as? NSButton } ?? []
        #expect(reusedButtons.allSatisfy { $0.isEnabled })
    }

    @Test("无法解析 payload 时显示错误文本")
    func unparsableShowsFallback() {
        let sender = MockMessageSender()
        let renderer = makeRenderer(sender: sender)
        let view = renderer.makeView()
        let row = AppKitMessageRow(
            kind: .tool,
            message: toolMessage(payload: makePayload()).withReplacedResultContent("not json")
        )
        renderer.configure(view: view, row: row)

        let labels = view.subviews.compactMap { $0 as? NSTextField }
        #expect(labels.contains { $0.stringValue == "无法解析问题内容" })
    }

    // MARK: - Registry routing

    @Test("注册表将挂起的 ask_user 路由到交互渲染器")
    func registryRoutesAskUser() {
        let pending = toolMessage(payload: makePayload(mode: "choice"))
        let pendingRow = AppKitMessageRow(kind: .tool, message: pending)
        #expect(AppKitMessageRendererRegistry.isPendingAskUser(pending) == true)

        // 非挂起（无 result）→ 不路由。
        let running = LumiChatMessage(
            conversationID: conversationID, role: .assistant, content: "",
            createdAt: Date(timeIntervalSinceReferenceDate: 0),
            toolCalls: [LumiToolCall(id: "c1", name: "search_code", arguments: "{}")]
        )
        #expect(AppKitMessageRendererRegistry.isPendingAskUser(running) == false)

        // 其它工具 → 通用工具渲染器。
        let registry = AppKitMessageRendererRegistry(environment: .init(
            theme: AppKitMessageTheme.systemDefault(),
            mermaidCache: AppKitMermaidCache(),
            layoutCache: AppKitMessageLayoutCache()
        ))
        #expect(registry.renderer(for: pendingRow) is AppKitAskUserRenderer)
        #expect(registry.renderer(for: AppKitMessageRow(kind: .tool, message: running)) is AppKitToolRenderer)
        #expect(registry.renderer(for: AppKitMessageRow(
            kind: .toolStepGroup,
            message: LumiChatMessage(conversationID: conversationID, role: .assistant, content: "", createdAt: .now)
        )) is AppKitToolGroupRenderer)
    }
}

private extension LumiChatMessage {
    /// Test helper: swap the first tool call's result content.
    func withReplacedResultContent(_ content: String) -> LumiChatMessage {
        guard let calls = toolCalls, let first = calls.first, let result = first.result else { return self }
        var message = self
        message.toolCalls = [LumiToolCall(
            id: first.id, name: first.name, arguments: first.arguments,
            result: LumiToolResult(
                content: content,
                duration: result.duration,
                isError: result.isError,
                imageAttachments: result.imageAttachments,
                turnControl: result.turnControl
            ),
            displayDescription: first.displayDescription
        )]
        return message
    }
}
