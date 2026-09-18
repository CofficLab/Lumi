import Foundation
import ProviderACP
import ProviderAgentLoop
import ProviderMessage

/// 回合执行窄协议。
///
/// 生产环境由 `AgentLoopProviding`（PluginAgentLoop）满足；
/// 测试注入轻量 mock，避免实现整个 agent loop 协议。
@MainActor
public protocol ACPTurnRunning: AnyObject {
    /// 注册回合生命周期观察者。
    func addAgentLoopObserver(
        _ callback: @escaping (AgentLoopEvent) -> Void
    ) -> any AgentLoopObserverHandle
    /// 启动一个回合。
    func runTurn(in conversationID: UUID) async throws -> AgentLoopOutcome
    /// 恢复被挂起的回合。
    func resumeTurn(in conversationID: UUID, request: AgentTurnResumeRequest) async throws -> AgentLoopOutcome
    /// 取消回合。
    func cancelTurn(in conversationID: UUID)
    /// 抑制/恢复该会话的自动回复（避免与内核自动回合竞争）。
    func setAutoReplySuppressed(_ suppressed: Bool, for conversationID: UUID)
}

/// 消息读写窄协议。
///
/// 生产环境由 `MessageManaging`（PluginConversationManager）满足。
@MainActor
public protocol ACPMessageReading: AnyObject {
    /// 插入一条消息（如用户提示）。
    func insertMessage(_ message: Message, to conversationID: UUID)
    /// 同步读取会话的全部消息快照。
    ///
    /// 必须为同步：ACP 回合收尾在事件路径上执行，异步存储（跨 actor /
    /// 持久化队列）会让 `finalize` 悬挂，导致 Client 收不到回合响应。
    func messagesSnapshot(in conversationID: UUID) -> [Message]
}

/// ACP 回合协调器：把 `session/prompt` 驱动的 Lumi agent 回合
/// 桥接为 ACP 的 `session/update` 通知流与最终 `session/prompt` 响应。
///
/// 事件映射（AgentLoopEvent → ACP）：
/// - `toolCallsReceived` → `session/update(tool_call)`，回合末补发 `tool_call_update`
/// - `suspended`（工具授权）→ `session/request_permission`（allow_once / reject_once），
///   允许后补发 `tool_call_update(in_progress)` 并恢复回合
/// - `suspended`（AskUser 交互）→ `session/request_permission`（yes_no/choice）
///   或降级为文本提示 + 结束回合（free_text / 非 JSON payload）
/// - `completed` / `failed` → 整段文本 `agent_message_chunk` + `end_turn`
/// - `cancelled` → `cancelled`
///
/// 所有出站 `request_permission` 都经 `ACPClientRequester` 发出并等待响应，
/// 因此响应到达、超时、会话取消三条路径都会收敛到同一个 continuation。
@MainActor
public final class ACPTurnCoordinator {
    /// 进行中的回合。
    private struct ActiveTurn {
        let sessionID: ACPSessionId
        let requestID: JSONValue
        let conversationID: UUID
        var finalized = false
        /// 是否已出现 LLM 进展（工具调用 / 终态事件）。
        /// started 不算进展：它只证明回合已启动，不能证明 LLM 会响应。
        var hasLLMProgress = false
    }

    /// 已上报、可能进入授权流程的工具调用元数据。
    private struct ToolCallMetadata {
        let sessionID: ACPSessionId
        let name: String
        let kind: ToolKind
        let title: String
        let rawInput: JSONValue?
    }

    /// 权限选项：optionId → 恢复回合时提交给内核的 answer。
    private struct PermissionOptions {
        let options: [ACPPermissionOption]
        let answersByOptionID: [String: String]
    }

    private let agentLoop: any ACPTurnRunning
    private let messages: any ACPMessageReading
    private let sessions: ACPSessionManager
    private let requester: ACPClientRequester
    /// 流式增量桥（可空：未接入流式时回合结束整段发送）。
    private let streaming: ACPStreamingBridge?
    private let onSend: @MainActor (ACPMessage) -> Void
    /// 回合启动后等待首个 LLM 进展的超时（无进展则按失败收尾，避免悬挂）。
    private let turnStartTimeout: TimeInterval

    private var activeTurns: [ACPSessionId: ActiveTurn] = [:]
    /// 正在等待用户决定的权限请求（每会话至多一个）。
    private var permissionTasks: [ACPSessionId: Task<Void, Never>] = [:]
    /// 已上报工具调用元数据（key: toolCallId）。
    private var toolCallMetadata: [String: ToolCallMetadata] = [:]
    private var observerHandle: (any AgentLoopObserverHandle)?
    private var watchdogTasks: [ACPSessionId: Task<Void, Never>] = [:]

    public init(
        agentLoop: any ACPTurnRunning,
        messages: any ACPMessageReading,
        sessions: ACPSessionManager,
        requester: ACPClientRequester,
        streaming: ACPStreamingBridge? = nil,
        onSend: @escaping @MainActor (ACPMessage) -> Void,
        turnStartTimeout: TimeInterval? = nil
    ) {
        self.agentLoop = agentLoop
        self.messages = messages
        self.sessions = sessions
        self.requester = requester
        self.streaming = streaming
        self.onSend = onSend
        // 默认 45 秒；支持 LUMI_ACP_TURN_TIMEOUT 环境变量覆盖（秒）。
        if let turnStartTimeout {
            self.turnStartTimeout = turnStartTimeout
        } else if let raw = ProcessInfo.processInfo.environment["LUMI_ACP_TURN_TIMEOUT"],
                  let seconds = TimeInterval(raw) {
            self.turnStartTimeout = seconds
        } else {
            self.turnStartTimeout = 45
        }
        observerHandle = agentLoop.addAgentLoopObserver { [weak self] event in
            self?.handle(event)
        }
        // 流式增量：内核追加 token 时立即转发为 agent_message_chunk。
        streaming?.onDelta = { [weak self] conversationID, delta in
            guard let self,
                  let sessionID = self.activeSessionID(for: conversationID) else { return }
            self.sendUpdate(sessionID: sessionID, update: .agentMessageChunk(.text(delta)))
        }
    }

    // MARK: - 回合启动

    /// 启动一个 ACP 回合：插入用户消息 → 运行 agent 回合。
    ///
    /// - Parameters:
    ///   - sessionID: ACP 会话。
    ///   - requestID: `session/prompt` 的 JSON-RPC 请求 ID（最终响应回执）。
    ///   - prompt: 用户提示块（支持 text / resource / resourceLink；image/audio 忽略）。
    /// - Returns: 错误消息（同步校验失败时），否则 nil 表示回合已启动。
    public func startTurn(
        sessionID: ACPSessionId,
        requestID: JSONValue,
        prompt: [ContentBlock]
    ) -> String? {
        guard let record = sessions.record(for: sessionID) else {
            return "Unknown session: \(sessionID.rawValue)"
        }
        let text = Self.text(from: prompt)
        guard !text.isEmpty else {
            return "Prompt must contain text content"
        }
        guard activeTurns[sessionID] == nil else {
            return "Session already has an active turn: \(sessionID.rawValue)"
        }

        let userMessage = Message(
            conversationID: record.conversationID,
            role: .user,
            content: text
        )
        // 先抑制自动回复，再插入用户消息：内核 MessageObserver 会因
        // 消息插入自动启动回合，ACP 需要独占托管本回合。
        agentLoop.setAutoReplySuppressed(true, for: record.conversationID)
        messages.insertMessage(userMessage, to: record.conversationID)
        activeTurns[sessionID] = ActiveTurn(
            sessionID: sessionID,
            requestID: requestID,
            conversationID: record.conversationID
        )
        armWatchdog(sessionID: sessionID)

        Task { @MainActor [weak self] in
            await self?.runTurnTask(sessionID: sessionID, conversationID: record.conversationID)
        }
        return nil
    }

    // MARK: - 首响应超时兜底

    /// 回合启动后若在 `turnStartTimeout` 内没有任何 LLM 进展
    /// （工具调用 / 终态事件），按失败收尾，避免 Client 悬挂。
    private func armWatchdog(sessionID: ACPSessionId) {
        watchdogTasks[sessionID]?.cancel()
        watchdogTasks[sessionID] = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(self?.turnStartTimeout ?? 45))
            guard let self else { return }
            guard let turn = self.activeTurns[sessionID], !turn.finalized else { return }
            guard !turn.hasLLMProgress else { return }
            await self.finalize(
                conversationID: turn.conversationID,
                cancelled: false,
                errorText: "Agent did not produce a response (no LLM progress within \(Int(self.turnStartTimeout))s). Check that a model is configured."
            )
        }
    }

    /// 取消会话进行中的回合（`session/cancel` 通知）。
    ///
    /// ACP 要求：收到取消后，该会话所有挂起的 `session/request_permission`
    /// 立即以 `cancelled` 收尾，避免 Client 悬挂。
    public func cancel(sessionID: ACPSessionId) {
        guard let record = sessions.record(for: sessionID) else { return }
        cancelPendingPermissions(sessionID: sessionID)
        agentLoop.cancelTurn(in: record.conversationID)
    }

    // MARK: - 事件处理

    private func handle(_ event: AgentLoopEvent) {
        switch event {
        case .started:
            break
        case .toolCallsReceived(let conversationID, _, _, let toolCalls):
            markLLMProgress(conversationID: conversationID)
            reportToolCalls(conversationID: conversationID, toolCalls: toolCalls)
        case .llmResponseReceived(let conversationID, _, _):
            markLLMProgress(conversationID: conversationID)
        case .suspended(_, _, let suspension):
            markLLMProgress(conversationID: suspension.conversationID)
            handleSuspension(suspension)
        case .completed(let conversationID, _):
            markLLMProgress(conversationID: conversationID)
            Task { @MainActor [weak self] in
                await self?.finalize(conversationID: conversationID, cancelled: false, errorText: nil)
            }
        case .failed(let conversationID, _, let reason):
            markLLMProgress(conversationID: conversationID)
            Task { @MainActor [weak self] in
                await self?.finalize(conversationID: conversationID, cancelled: false, errorText: reason)
            }
        case .cancelled(let conversationID, _):
            markLLMProgress(conversationID: conversationID)
            Task { @MainActor [weak self] in
                await self?.finalize(conversationID: conversationID, cancelled: true, errorText: nil)
            }
        }
    }

    /// 记录 LLM 进展：任何工具调用 / 终态事件到达后，watchdog 不再触发。
    private func markLLMProgress(conversationID: UUID) {
        guard let sessionID = activeSessionID(for: conversationID) else { return }
        activeTurns[sessionID]?.hasLLMProgress = true
        watchdogTasks[sessionID]?.cancel()
        watchdogTasks[sessionID] = nil
    }

    private func runTurnTask(sessionID: ACPSessionId, conversationID: UUID) async {
        do {
            let outcome = try await agentLoop.runTurn(in: conversationID)
            // 事件路径已 finalize 的回合会因 finalized 标志跳过。
            switch outcome {
            case .completed:
                await finalize(conversationID: conversationID, cancelled: false, errorText: nil)
            case .failed(let reason):
                if reason.contains("already running") {
                    // 内核自动回复（MessageObserver）已接管该回合：
                    // 由事件路径收尾，这里不重复 finalize。
                    break
                }
                await finalize(conversationID: conversationID, cancelled: false, errorText: reason)
            case .cancelled:
                await finalize(conversationID: conversationID, cancelled: true, errorText: nil)
            case .suspended:
                // 回合挂起等待用户决定（resume 后继续），不结束。
                break
            }
        } catch {
            // runTurn 异常（如恢复失败）：按取消结束，避免客户端悬挂。
            await finalize(conversationID: conversationID, cancelled: true, errorText: nil)
        }
    }

    // MARK: - 工具调用通知

    private func reportToolCalls(conversationID: UUID, toolCalls: [MessageToolCall]) {
        guard let sessionID = activeSessionID(for: conversationID) else { return }
        for call in toolCalls {
            let kind = Self.toolKind(for: call.name)
            let title = call.displayDescription ?? call.name
            let rawInput = Self.json(from: call.arguments)
            // 登记元数据：授权弹窗需要真实 toolCallId / 标题 / 类别 / 原始入参。
            toolCallMetadata[call.id] = ToolCallMetadata(
                sessionID: sessionID,
                name: call.name,
                kind: kind,
                title: title,
                rawInput: rawInput
            )
            sendUpdate(sessionID: sessionID, update: .toolCall(ToolCallUpdate(
                toolCallId: call.id,
                title: title,
                kind: kind,
                status: .pending,
                rawInput: rawInput
            )))
        }
    }

    // MARK: - 挂起处理

    private func handleSuspension(_ suspension: AgentLoopSuspension) {
        guard let sessionID = sessions.sessionID(for: suspension.conversationID),
              activeTurns[sessionID] != nil else { return }

        let payload = Self.jsonObject(from: suspension.payload)

        // 工具授权挂起：内核以 payload.kind == "permission" 标记（见 ToolManager+Run）。
        if payload?["kind"] as? String == "permission" {
            presentToolPermission(suspension, payload: payload, sessionID: sessionID)
            return
        }

        // 其余为 AskUser 交互（需要 payload.mode 判别）。
        guard let mode = payload?["mode"] as? String else {
            // 非 AskUser 载荷：把 payload 作为问题文本推送，并结束回合。
            sendAgentText(suspension.payload, sessionID: sessionID)
            agentLoop.cancelTurn(in: suspension.conversationID)
            return
        }

        let question = (payload?["question"] as? String) ?? suspension.payload
        switch mode {
        case "choice":
            let labels = Self.choiceOptions(from: payload?["options"])
            guard !labels.isEmpty else {
                sendAgentText(ACPLocalization.inputRequired(question), sessionID: sessionID)
                agentLoop.cancelTurn(in: suspension.conversationID)
                return
            }
            // AskUser 的 answer 必须是选项标签本身（内核按标签匹配）；optionId
            // 也用标签，因为标签可能含空格/任意语言，不适合作为稳定标识。
            let options = PermissionOptions(
                options: labels.map { ACPPermissionOption(optionId: $0, name: $0, kind: .allowOnce) },
                answersByOptionID: Dictionary(uniqueKeysWithValues: labels.map { ($0, $0) })
            )
            awaitPermission(
                suspension: suspension,
                sessionID: sessionID,
                toolCallUpdate: ToolCallUpdate(
                    toolCallId: suspension.toolCallID ?? "ask-\(suspension.suspensionID)",
                    title: question,
                    status: .pending
                ),
                options: options
            )
        case "free_text":
            // ACP 无自由文本输入通道：降级为文本问题 + 结束回合，用户下轮回答。
            sendAgentText(ACPLocalization.inputRequired(question), sessionID: sessionID)
            agentLoop.cancelTurn(in: suspension.conversationID)
        default: // yes_no
            // 展示文案走本地化，但 answer 固定传内核可识别的允许/拒绝词，
            // 否则非中文环境下用户点"允许"会被内核当成拒绝执行。
            let options = PermissionOptions(
                options: [
                    ACPPermissionOption(optionId: "yes", name: ACPLocalization.yes, kind: .allowOnce),
                    ACPPermissionOption(optionId: "no", name: ACPLocalization.no, kind: .rejectOnce),
                ],
                answersByOptionID: ["yes": "approved", "no": "denied"]
            )
            awaitPermission(
                suspension: suspension,
                sessionID: sessionID,
                toolCallUpdate: ToolCallUpdate(
                    toolCallId: suspension.toolCallID ?? "ask-\(suspension.suspensionID)",
                    title: question,
                    status: .pending
                ),
                options: options
            )
        }
    }

    /// 工具授权挂起：以真实 `toolCallId` 发起 `session/request_permission`。
    private func presentToolPermission(
        _ suspension: AgentLoopSuspension,
        payload: [String: Any]?,
        sessionID: ACPSessionId
    ) {
        // 用真实 toolCallId（内核授权挂起的 suspension.toolCallID 即模型原始调用 ID），
        // 与先前上报的 `tool_call` 通知保持一致；payload 里的 "approval:<id>" 不可用。
        let toolCallID = suspension.toolCallID ?? ""
        let metadata = toolCallMetadata[toolCallID]
        let question = (payload?["question"] as? String) ?? ACPLocalization.allowThisOperation

        let options = PermissionOptions(
            options: [
                ACPPermissionOption(optionId: "allow_once", name: ACPLocalization.allow, kind: .allowOnce),
                ACPPermissionOption(optionId: "reject_once", name: ACPLocalization.reject, kind: .rejectOnce),
            ],
            // 展示文案随系统语言变化，但 answer 必须是内核能识别的允许词，
            // 否则非中文环境下"允许"会被 resolveUserResponse 判为拒绝。
            answersByOptionID: ["allow_once": "approved", "reject_once": "denied"]
        )
        awaitPermission(
            suspension: suspension,
            sessionID: sessionID,
            toolCallUpdate: ToolCallUpdate(
                toolCallId: toolCallID,
                title: metadata?.title ?? question,
                kind: metadata?.kind,
                status: .pending,
                rawInput: metadata?.rawInput
            ),
            options: options
        )
    }

    /// 发起权限请求并异步处理用户决定（allow / reject / cancel / 超时）。
    private func awaitPermission(
        suspension: AgentLoopSuspension,
        sessionID: ACPSessionId,
        toolCallUpdate: ToolCallUpdate,
        options: PermissionOptions
    ) {
        guard permissionTasks[sessionID] == nil else {
            // 同一会话已有一个待决定权限：拒绝并发挂起，避免响应错配。
            agentLoop.cancelTurn(in: suspension.conversationID)
            return
        }

        let params = ACPRequestPermissionParams(
            sessionId: sessionID,
            toolCall: toolCallUpdate,
            options: options.options
        )

        permissionTasks[sessionID] = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.permissionTasks[sessionID] = nil }

            let outcome: ACPRequestPermissionResult
            do {
                outcome = try await self.requester.requestPermission(params)
            } catch {
                // 客户端无响应（超时）或连接中断：终止回合，避免悬挂。
                self.agentLoop.cancelTurn(in: suspension.conversationID)
                return
            }

            switch outcome.outcome {
            case .cancelled:
                self.agentLoop.cancelTurn(in: suspension.conversationID)
            case .selected(let optionId):
                guard let answer = options.answersByOptionID[optionId] else {
                    self.agentLoop.cancelTurn(in: suspension.conversationID)
                    return
                }
                // 授权通过：先按 ACP 规范把工具置为 in_progress，再恢复回合。
                if optionId.hasPrefix("allow") {
                    self.sendUpdate(
                        sessionID: sessionID,
                        update: .toolCallUpdate(ToolCallUpdate(
                            toolCallId: toolCallUpdate.toolCallId,
                            status: .inProgress
                        ))
                    )
                }
                _ = try? await self.agentLoop.resumeTurn(
                    in: suspension.conversationID,
                    request: AgentTurnResumeRequest(
                        suspensionID: suspension.suspensionID,
                        answer: answer
                    )
                )
            }
        }
    }

    /// 作废会话的挂起权限请求（回合收尾 / 取消时调用）。
    private func cancelPendingPermissions(sessionID: ACPSessionId) {
        permissionTasks[sessionID]?.cancel()
        permissionTasks[sessionID] = nil
        requester.cancelRequests(for: sessionID)
    }

    // MARK: - 回合收尾

    private func finalize(conversationID: UUID, cancelled: Bool, errorText: String?) async {
        guard let (sessionID, turn) = activeTurns.first(where: { $0.value.conversationID == conversationID }),
              !turn.finalized else {
            return
        }
        activeTurns[sessionID]?.finalized = true

        // ACP 要求：回合结束前不得残留挂起的权限请求；未完成的工具调用
        // 一律以 cancelled 收尾，Client 才能正确收敛 UI 状态。
        cancelPendingPermissions(sessionID: sessionID)
        publishCancelledToolCalls(sessionID: sessionID)

        // stopReason 必须如实反映回合结局：把失败混成 end_turn 会让客户端
        // 把错误当成功（方案 §5 约定 failed → refusal）。因此先判定是否失败。
        let failed = !cancelled && errorText != nil
        if let errorText {
            sendAgentText(errorText, sessionID: sessionID)
        }
        if !failed {
            await publishFinalContent(conversationID: conversationID, sessionID: sessionID)
        }
        streaming?.reset(conversationID: conversationID)

        let stopReason: StopReason
        if cancelled {
            stopReason = .cancelled
        } else if failed {
            stopReason = .refusal
        } else {
            stopReason = .endTurn
        }
        do {
            onSend(try ACPMessage.makeResponse(
                id: turn.requestID,
                result: ACPPromptResult(stopReason: stopReason)
            ))
        } catch {
            onSend(.error(id: turn.requestID, error: .internalError))
        }

        activeTurns.removeValue(forKey: sessionID)
        watchdogTasks[sessionID]?.cancel()
        watchdogTasks[sessionID] = nil
        // 回合结束：恢复自动回复（该会话回到内核默认行为）。
        agentLoop.setAutoReplySuppressed(false, for: conversationID)
    }

    /// 回合结束时，把本会话尚未出结果的工具调用标记为 cancelled。
    private func publishCancelledToolCalls(sessionID: ACPSessionId) {
        let snapshot = messages.messagesSnapshot(in: sessions.conversationID(for: sessionID) ?? UUID())
        let completedIDs = Set(
            snapshot.flatMap { $0.toolCalls ?? [] }
                .filter { $0.result != nil }
                .map(\.id)
        )
        let pendingIDs = toolCallMetadata
            .filter { $0.value.sessionID == sessionID && !completedIDs.contains($0.key) }
            .map(\.key)
        for toolCallID in pendingIDs {
            sendUpdate(sessionID: sessionID, update: .toolCallUpdate(ToolCallUpdate(
                toolCallId: toolCallID,
                status: .cancelled
            )))
        }
        toolCallMetadata = toolCallMetadata.filter { $0.value.sessionID != sessionID }
    }

    /// 回合正常结束后：补发工具完成状态 + 最终 assistant 文本。
    private func publishFinalContent(conversationID: UUID, sessionID: ACPSessionId) async {
        let snapshot = messages.messagesSnapshot(in: conversationID)
        let assistantMessages = snapshot.reversed().filter { $0.role == .assistant }

        // 1. 补发尚未报告的 tool_call_update（completed/failed）。
        for message in assistantMessages {
            for call in message.toolCalls ?? [] {
                guard let result = call.result else { continue }
                sendUpdate(
                    sessionID: sessionID,
                    update: .toolCallUpdate(ToolCallUpdate(
                        toolCallId: call.id,
                        status: result.isError ? .failed : .completed,
                        content: [.content(.text(result.content))]
                    ))
                )
            }
        }

        // 2. 最终 assistant 文本（第一个非空内容）。
        // 已经流式发出过增量的回合不再整段重发，否则客户端会看到重复文本。
        if streaming?.didStream(conversationID: conversationID) != true,
           let finalText = assistantMessages.first(where: { !$0.content.isEmpty })?.content {
            sendAgentText(finalText, sessionID: sessionID)
        }
    }

    // MARK: - 发送辅助

    private func sendUpdate(sessionID: ACPSessionId, update: SessionUpdate) {
        do {
            onSend(try ACPMessage.makeNotification(
                method: ACPMethod.sessionUpdate,
                params: ACPSessionUpdateParams(sessionId: sessionID, update: update)
            ))
        } catch {
            fputs("ACP update encode failed: \(error)\n", stderr)
        }
    }

    private func sendAgentText(_ text: String, sessionID: ACPSessionId) {
        sendUpdate(sessionID: sessionID, update: .agentMessageChunk(.text(text)))
    }

    /// 从活动回合定位 conversationID 对应的 ACP 会话。
    private func activeSessionID(for conversationID: UUID) -> ACPSessionId? {
        activeTurns.first(where: { $0.value.conversationID == conversationID })?.key
    }

    // MARK: - 纯函数

    /// 提取提示中的文本内容（text / resource / resourceLink）。
    static func text(from blocks: [ContentBlock]) -> String {
        blocks.compactMap { block -> String? in
            switch block {
            case .text(let text, _):
                return text
            case .resource(let resource, _):
                return resource.text ?? resource.uri
            case .resourceLink(let uri, _, _, _, _, _, _):
                return uri
            case .image, .audio:
                return nil
            }
        }
        .filter { !$0.isEmpty }
        .joined(separator: "\n\n")
    }

    /// 根据工具名推断 ACP ToolKind。
    static func toolKind(for name: String) -> ToolKind {
        let n = name.lowercased()
        if n.contains("read") || n.contains("open") || n.contains("view") { return .read }
        if n.contains("write") || n.contains("edit") || n.contains("replace") { return .edit }
        if n.contains("delete") || n.contains("remove") || n.contains("trash") { return .delete }
        if n.contains("move") || n.contains("rename") || n.contains("copy") { return .move }
        if n.contains("search") || n.contains("find") || n.contains("query") { return .search }
        if n.contains("bash") || n.contains("terminal") || n.contains("shell") || n.contains("run") || n.contains("execute") { return .execute }
        if n.contains("fetch") || n.contains("http") || n.contains("web") { return .fetch }
        if n.contains("think") || n.contains("plan") { return .think }
        return .other
    }

    /// 把 JSON 字符串解析为 JSONValue（失败返回 nil）。
    static func json(from string: String) -> JSONValue? {
        try? JSONDecoder().decode(JSONValue.self, from: Data(string.utf8))
    }

    /// 把 JSON 字符串解析为字典（失败或非对象返回 nil）。
    static func jsonObject(from string: String) -> [String: Any]? {
        guard let data = string.data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    /// 解析 AskUser choice 选项（对象 {label,description?,badge?} 或裸字符串）。
    static func choiceOptions(from raw: Any?) -> [String] {
        guard let array = raw as? [Any] else { return [] }
        return array.compactMap { element -> String? in
            if let string = element as? String, !string.isEmpty { return string }
            if let dict = element as? [String: Any] {
                let label = (dict["label"] as? String)
                    ?? (dict["description"] as? String)
                    ?? (dict["value"] as? String)
                    ?? (dict["text"] as? String)
                return label.flatMap { $0.isEmpty ? nil : $0 }
            }
            return nil
        }
    }
}

/// `session/update` 通知参数（sessionId + update 载荷）。
public struct ACPSessionUpdateParams: Sendable, Equatable, Codable {
    public var sessionId: ACPSessionId
    public var update: SessionUpdate

    public init(sessionId: ACPSessionId, update: SessionUpdate) {
        self.sessionId = sessionId
        self.update = update
    }
}
